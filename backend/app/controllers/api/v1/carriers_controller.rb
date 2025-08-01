class Api::V1::CarriersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_carrier, only: [:show, :update, :destroy, :available_loads, :accept_load, :update_location]
  before_action :authorize_carrier_access!, only: [:show, :update, :destroy, :available_loads, :accept_load, :update_location]

  # GET /api/v1/carriers
  def index
    authorize_admin_or_shipper!
    
    @carriers = Carrier.includes(:user, :vehicles, :drivers)
                      .active
                      .verified
    
    # Apply filters
    @carriers = apply_filters(@carriers)
    
    # Pagination
    @carriers = @carriers.page(params[:page]).per(params[:per_page] || 25)
    
    render json: {
      carriers: @carriers.map { |carrier| carrier_response(carrier) },
      meta: pagination_meta(@carriers)
    }
  end

  # GET /api/v1/carriers/:id
  def show
    render json: {
      carrier: detailed_carrier_response(@carrier)
    }
  end

  # PUT/PATCH /api/v1/carriers/:id
  def update
    if @carrier.update(carrier_params)
      render json: {
        message: 'Carrier updated successfully',
        carrier: detailed_carrier_response(@carrier)
      }
    else
      render json: {
        error: 'Carrier update failed',
        details: @carrier.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/carriers/:id
  def destroy
    authorize_admin!
    
    if @carrier.destroy
      render json: {
        message: 'Carrier deleted successfully'
      }
    else
      render json: {
        error: 'Carrier deletion failed',
        details: @carrier.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/carriers/:id/available_loads
  def available_loads
    # Get loads that this carrier can handle
    @loads = Load.available
    
    # Filter by carrier capabilities
    @loads = @loads.where(equipment_type: @carrier.equipment_list) if @carrier.equipment_list.any?
    @loads = @loads.where(pickup_state: @carrier.service_area_list) if @carrier.service_area_list.any?
    
    # Exclude hazmat if carrier is not certified
    @loads = @loads.where(is_hazmat: false) unless @carrier.user.driver_profile&.is_hazmat_certified?
    
    # Apply additional filters
    @loads = apply_load_filters(@loads)
    
    # Calculate match scores and sort by relevance
    loads_with_scores = @loads.map do |load|
      {
        load: load,
        score: load.matching_score_for(@carrier),
        can_match: load.can_be_matched_with?(@carrier),
        distance: @carrier.distance_from(load.pickup_coordinates)
      }
    end
    
    # Filter and sort
    loads_with_scores = loads_with_scores
                       .select { |item| item[:can_match] }
                       .sort_by { |item| -item[:score] }
    
    # Paginate
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 25).to_i
    total_count = loads_with_scores.count
    offset = (page - 1) * per_page
    
    paginated_loads = loads_with_scores[offset, per_page] || []
    
    render json: {
      loads: paginated_loads.map do |item|
        response = load_response(item[:load])
        response[:match_score] = item[:score]
        response[:distance_to_pickup] = item[:distance]
        response
      end,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # POST /api/v1/carriers/:id/accept_load
  def accept_load
    load = Load.find(params[:load_id])
    
    # Check if carrier can handle this load
    unless load.can_be_matched_with?(@carrier)
      return render json: {
        error: 'Carrier cannot handle this load',
        details: ['Equipment type, service area, or other requirements not met']
      }, status: :unprocessable_entity
    end
    
    # Find or create match
    match = load.matches.find_by(carrier: @carrier)
    
    if match.nil?
      match = load.matches.build(
        carrier: @carrier,
        status: 'pending',
        rate_offered: params[:rate_offered] || load.total_rate
      )
      
      unless match.save
        return render json: {
          error: 'Failed to create match',
          details: match.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
    
    # Accept the load
    if match.may_accept_offer?
      match.rate_offered = params[:rate_offered] if params[:rate_offered].present?
      match.accept_offer!
      
      render json: {
        message: 'Load accepted successfully',
        match: match_response(match),
        load: load_response(load.reload)
      }
    else
      render json: {
        error: 'Cannot accept this load',
        details: ["Match is in #{match.status} state"]
      }, status: :unprocessable_entity
    end
    
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Load not found' }, status: :not_found
  end

  # POST /api/v1/carriers/:id/update_location
  def update_location
    authorize_carrier_or_driver!
    
    latitude = params[:latitude]&.to_f
    longitude = params[:longitude]&.to_f
    
    if latitude.blank? || longitude.blank?
      return render json: {
        error: 'Latitude and longitude are required'
      }, status: :bad_request
    end
    
    # Update carrier location
    @carrier.update!(
      latitude: latitude,
      longitude: longitude
    )
    
    # Update vehicle location if assigned
    if current_user.driver? && current_user.driver_profile.vehicle.present?
      current_user.driver_profile.vehicle.update_location(latitude, longitude)
    end
    
    render json: {
      message: 'Location updated successfully',
      location: {
        latitude: latitude,
        longitude: longitude,
        updated_at: Time.current
      }
    }
  end

  # GET /api/v1/carriers/search
  def search
    authorize_shipper!
    
    @carriers = Carrier.active.verified
    
    # Apply search filters
    @carriers = apply_search_filters(@carriers)
    
    # Pagination
    @carriers = @carriers.page(params[:page]).per(params[:per_page] || 25)
    
    render json: {
      carriers: @carriers.map { |carrier| carrier_response(carrier) },
      meta: pagination_meta(@carriers)
    }
  end

  private

  def set_carrier
    @carrier = if params[:id] == 'me' && current_user.carrier?
                 current_user.carrier_profile
               else
                 Carrier.find(params[:id])
               end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Carrier not found' }, status: :not_found
  end

  def authorize_carrier_access!
    case current_user.user_type
    when 'admin'
      return # Admins can access all carriers
    when 'carrier'
      return if @carrier.user == current_user
    when 'driver'
      return if current_user.driver_profile&.carrier == @carrier
    when 'shipper'
      return # Shippers can view carrier profiles for matching
    end
    
    render json: { error: 'Access denied' }, status: :forbidden
  end

  def authorize_admin!
    return if current_user.admin?
    
    render json: { error: 'Admin access required' }, status: :forbidden
  end

  def authorize_admin_or_shipper!
    return if current_user.admin? || current_user.shipper?
    
    render json: { error: 'Admin or shipper access required' }, status: :forbidden
  end

  def authorize_carrier_or_driver!
    return if current_user.carrier? || current_user.driver?
    
    render json: { error: 'Carrier or driver access required' }, status: :forbidden
  end

  def authorize_shipper!
    return if current_user.shipper?
    
    render json: { error: 'Shipper access required' }, status: :forbidden
  end

  def carrier_params
    params.require(:carrier).permit(
      :company_name, :company_description, :phone, :website,
      :address_line1, :address_line2, :city, :state, :postal_code,
      :fleet_size, :insurance_amount, :insurance_expiry,
      :operating_authority, equipment_types: [], service_areas: []
    )
  end

  def apply_filters(carriers)
    carriers = carriers.where('company_name ILIKE ?', "%#{params[:company_name]}%") if params[:company_name].present?
    carriers = carriers.where(safety_rating: params[:safety_rating]) if params[:safety_rating].present?
    carriers = carriers.by_fleet_size(params[:min_fleet_size], params[:max_fleet_size]) if params[:min_fleet_size].present?
    carriers = carriers.where('service_areas::text ILIKE ?', "%#{params[:service_area]}%") if params[:service_area].present?
    carriers = carriers.where('equipment_types::text ILIKE ?', "%#{params[:equipment_type]}%") if params[:equipment_type].present?
    
    carriers
  end

  def apply_load_filters(loads)
    loads = loads.where(equipment_type: params[:equipment_type]) if params[:equipment_type].present?
    loads = loads.where('pickup_date >= ?', Date.parse(params[:pickup_date_from])) if params[:pickup_date_from].present?
    loads = loads.where('pickup_date <= ?', Date.parse(params[:pickup_date_to])) if params[:pickup_date_to].present?
    loads = loads.where('rate >= ?', params[:min_rate]) if params[:min_rate].present?
    loads = loads.where('rate <= ?', params[:max_rate]) if params[:max_rate].present?
    loads = loads.by_origin_state(params[:origin_state]) if params[:origin_state].present?
    loads = loads.by_destination_state(params[:destination_state]) if params[:destination_state].present?
    
    loads
  end

  def apply_search_filters(carriers)
    carriers = carriers.where('equipment_types::text ILIKE ?', "%#{params[:equipment_type]}%") if params[:equipment_type].present?
    carriers = carriers.where('service_areas::text ILIKE ?', "%#{params[:service_area]}%") if params[:service_area].present?
    carriers = carriers.where(safety_rating: params[:safety_rating]) if params[:safety_rating].present?
    carriers = carriers.where('fleet_size >= ?', params[:min_fleet_size]) if params[:min_fleet_size].present?
    
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      carriers = carriers.where('company_name ILIKE ? OR mc_number ILIKE ?', search_term, search_term)
    end
    
    carriers
  end

  def carrier_response(carrier)
    {
      id: carrier.id,
      company_name: carrier.company_name,
      mc_number: carrier.mc_number,
      dot_number: carrier.dot_number,
      scac_code: carrier.scac_code,
      city: carrier.city,
      state: carrier.state,
      fleet_size: carrier.fleet_size,
      equipment_types: carrier.equipment_list,
      service_areas: carrier.service_area_list,
      safety_rating: carrier.safety_rating,
      safety_score: carrier.safety_score,
      is_verified: carrier.is_verified,
      is_active: carrier.is_active,
      average_rating: carrier.average_rating,
      total_completed_loads: carrier.total_completed_loads,
      on_time_percentage: carrier.on_time_percentage,
      insurance_valid: carrier.insurance_valid?
    }
  end

  def detailed_carrier_response(carrier)
    response = carrier_response(carrier)
    
    response.merge!(
      company_description: carrier.company_description,
      phone: carrier.phone,
      website: carrier.website,
      full_address: carrier.full_address,
      insurance_amount: carrier.insurance_amount,
      insurance_expiry: carrier.insurance_expiry,
      operating_authority: carrier.operating_authority,
      current_location: carrier.current_location,
      vehicles_count: carrier.vehicles.active.count,
      drivers_count: carrier.drivers.active.count,
      available_capacity: carrier.available_capacity
    )
    
    if current_user.admin? || carrier.user == current_user
      response[:vehicles] = carrier.vehicles.active.map { |vehicle| vehicle_summary(vehicle) }
      response[:drivers] = carrier.drivers.active.map { |driver| driver_summary(driver) }
    end
    
    response
  end

  def vehicle_summary(vehicle)
    {
      id: vehicle.id,
      vehicle_number: vehicle.vehicle_number,
      make: vehicle.make,
      model: vehicle.model,
      year: vehicle.year,
      equipment_type: vehicle.equipment_type,
      status: vehicle.status,
      current_location: vehicle.current_location,
      assigned_driver: vehicle.driver&.full_name
    }
  end

  def driver_summary(driver)
    {
      id: driver.id,
      driver_number: driver.driver_number,
      full_name: driver.full_name,
      status: driver.status,
      cdl_class: driver.cdl_class,
      is_hazmat_certified: driver.is_hazmat_certified,
      assigned_vehicle: driver.vehicle&.vehicle_number
    }
  end

  def load_response(load)
    {
      id: load.id,
      reference_number: load.reference_number,
      commodity: load.commodity,
      weight: load.weight,
      pickup_city: load.pickup_city,
      pickup_state: load.pickup_state,
      pickup_date: load.pickup_date,
      delivery_city: load.delivery_city,
      delivery_state: load.delivery_state,
      delivery_date: load.delivery_date,
      equipment_type: load.equipment_type,
      rate: load.rate,
      total_rate: load.total_rate,
      distance_miles: load.distance_miles,
      special_requirements: load.special_requirements
    }
  end

  def match_response(match)
    {
      id: match.id,
      status: match.status,
      match_score: match.match_score,
      rate_offered: match.rate_offered,
      rate_accepted: match.rate_accepted,
      estimated_pickup_time: match.estimated_pickup_time,
      estimated_delivery_time: match.estimated_delivery_time
    }
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end