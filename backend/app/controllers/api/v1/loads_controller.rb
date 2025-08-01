class Api::V1::LoadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_load, only: [:show, :update, :destroy, :book, :complete, :cancel]
  before_action :authorize_shipper!, only: [:create, :update, :destroy]
  before_action :authorize_load_access!, only: [:show, :update, :destroy, :book, :complete, :cancel]

  # GET /api/v1/loads
  def index
    @loads = Load.includes(:shipper, :active_match, :assigned_carrier)
    
    # Apply user-specific filters
    case current_user.user_type
    when 'shipper'
      @loads = @loads.joins(:shipper).where(shippers: { user_id: current_user.id })
    when 'carrier', 'driver'
      # Show available loads for carriers/drivers
      @loads = @loads.available unless params[:show_all] == 'true'
    when 'admin'
      # Admins can see all loads
    else
      @loads = @loads.none
    end
    
    # Apply filters
    @loads = apply_filters(@loads)
    
    # Pagination
    @loads = @loads.page(params[:page]).per(params[:per_page] || 25)
    
    render json: {
      loads: @loads.map { |load| load_response(load) },
      meta: pagination_meta(@loads)
    }
  end

  # GET /api/v1/loads/:id
  def show
    render json: {
      load: detailed_load_response(@load)
    }
  end

  # POST /api/v1/loads
  def create
    # Use service to handle load creation
    service = LoadCreationService.new(current_user, load_params)
    result = service.create
    
    if result[:success]
      render json: {
        message: result[:message],
        load: detailed_load_response(result[:load])
      }, status: :created
    else
      render json: {
        error: 'Load creation failed',
        details: result[:errors]
      }, status: :unprocessable_entity
    end
  end

  # PUT/PATCH /api/v1/loads/:id
  def update
    if @load.update(load_params)
      render json: {
        message: 'Load updated successfully',
        load: detailed_load_response(@load)
      }
    else
      render json: {
        error: 'Load update failed',
        details: @load.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/loads/:id
  def destroy
    if @load.destroy
      render json: {
        message: 'Load deleted successfully'
      }
    else
      render json: {
        error: 'Load deletion failed',
        details: @load.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/loads/:id/book
  def book
    authorize_carrier_or_driver!
    
    carrier = get_user_carrier
    return render json: { error: 'Carrier profile required' }, status: :bad_request unless carrier
    
    # Find or create match
    match = @load.matches.find_by(carrier: carrier) || 
            @load.matches.build(carrier: carrier, status: 'pending')
    
    if match.persisted? || match.save
      if match.may_accept_offer?
        match.accept_offer!
        render json: {
          message: 'Load booked successfully',
          load: detailed_load_response(@load.reload),
          match: match_response(match)
        }
      else
        render json: {
          error: 'Cannot book this load',
          details: ["Load is in #{match.status} state"]
        }, status: :unprocessable_entity
      end
    else
      render json: {
        error: 'Booking failed',
        details: match.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/loads/:id/complete
  def complete
    authorize_load_owner_or_assigned_carrier!
    
    if @load.may_deliver?
      @load.deliver!
      render json: {
        message: 'Load marked as completed',
        load: detailed_load_response(@load)
      }
    else
      render json: {
        error: 'Cannot complete load',
        details: ["Load is in #{@load.status} state"]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/loads/:id/cancel
  def cancel
    authorize_load_owner!
    
    if @load.may_cancel?
      @load.cancel!
      render json: {
        message: 'Load cancelled successfully',
        load: detailed_load_response(@load)
      }
    else
      render json: {
        error: 'Cannot cancel load',
        details: ["Load is in #{@load.status} state"]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/loads/search
  def search
    authorize_carrier_or_driver!
    
    carrier = get_user_carrier
    return render json: { error: 'Carrier profile required' }, status: :bad_request unless carrier
    
    # Use service to handle load search
    search_filters = search_params
    service = LoadSearchService.new(carrier, search_filters)
    result = service.search
    
    if result[:success]
      render json: {
        loads: result[:loads].map do |item|
          response = load_response(item[:load])
          response[:match_score] = item[:score]
          response[:distance_to_pickup] = item[:distance_to_pickup]
          response[:revenue_estimate] = item[:revenue_estimate]
          response
        end,
        meta: result[:pagination],
        search_info: result[:search_criteria]
      }
    else
      render json: {
        error: 'Search failed',
        details: result[:errors]
      }, status: :internal_server_error
    end
  end

  private

  def set_load
    @load = Load.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Load not found' }, status: :not_found
  end

  def authorize_shipper!
    return if current_user.shipper?
    
    render json: { error: 'Shipper access required' }, status: :forbidden
  end

  def authorize_carrier_or_driver!
    return if current_user.carrier? || current_user.driver?
    
    render json: { error: 'Carrier or driver access required' }, status: :forbidden
  end

  def authorize_load_access!
    case current_user.user_type
    when 'admin'
      return # Admins can access all loads
    when 'shipper'
      return if @load.shipper.user == current_user
    when 'carrier'
      return if @load.assigned_carrier&.user == current_user || @load.available_for_matching?
    when 'driver'
      carrier = current_user.driver_profile&.carrier
      return if carrier && (@load.assigned_carrier == carrier || @load.available_for_matching?)
    end
    
    render json: { error: 'Access denied' }, status: :forbidden
  end

  def authorize_load_owner!
    return if current_user.admin? || @load.shipper.user == current_user
    
    render json: { error: 'Only load owner can perform this action' }, status: :forbidden
  end

  def authorize_load_owner_or_assigned_carrier!
    return if current_user.admin?
    return if @load.shipper.user == current_user
    
    if current_user.carrier?
      return if @load.assigned_carrier&.user == current_user
    elsif current_user.driver?
      carrier = current_user.driver_profile&.carrier
      return if carrier && @load.assigned_carrier == carrier
    end
    
    render json: { error: 'Access denied' }, status: :forbidden
  end

  def get_user_carrier
    case current_user.user_type
    when 'carrier'
      current_user.carrier_profile
    when 'driver'
      current_user.driver_profile&.carrier
    else
      nil
    end
  end

  def load_params
    params.require(:load).permit(
      :commodity, :description, :weight, :dimensions, :special_instructions,
      :pickup_address_line1, :pickup_address_line2, :pickup_city, :pickup_state,
      :pickup_postal_code, :pickup_country, :pickup_date, :pickup_time_window_start,
      :pickup_time_window_end, :pickup_contact_name, :pickup_contact_phone,
      :delivery_address_line1, :delivery_address_line2, :delivery_city, :delivery_state,
      :delivery_postal_code, :delivery_country, :delivery_date, :delivery_time_window_start,
      :delivery_time_window_end, :delivery_contact_name, :delivery_contact_phone,
      :equipment_type, :rate, :rate_type, :fuel_surcharge, :accessorial_charges,
      :currency, :payment_terms, :requires_tracking, :requires_signature,
      :is_hazmat, :is_expedited, :is_team_driver, :temperature_controlled,
      :temperature_min, :temperature_max, :expires_at
    )
  end

  def search_params
    params.permit(
      :equipment_type, :origin_state, :destination_state, :pickup_date_from,
      :pickup_date_to, :min_rate, :max_rate, :max_distance, :max_weight,
      :expedited, :hazmat, :temperature_controlled, :search, :page, :per_page
    ).to_h
  end

  def apply_filters(loads)
    loads = loads.where(equipment_type: params[:equipment_type]) if params[:equipment_type].present?
    loads = loads.by_origin_state(params[:origin_state]) if params[:origin_state].present?
    loads = loads.by_destination_state(params[:destination_state]) if params[:destination_state].present?
    loads = loads.where('pickup_date >= ?', Date.parse(params[:pickup_date_from])) if params[:pickup_date_from].present?
    loads = loads.where('pickup_date <= ?', Date.parse(params[:pickup_date_to])) if params[:pickup_date_to].present?
    loads = loads.where('rate >= ?', params[:min_rate]) if params[:min_rate].present?
    loads = loads.where('rate <= ?', params[:max_rate]) if params[:max_rate].present?
    loads = loads.expedited if params[:expedited] == 'true'
    loads = loads.hazmat if params[:hazmat] == 'true'
    loads = loads.temperature_controlled if params[:temperature_controlled] == 'true'
    
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      loads = loads.where(
        'commodity ILIKE ? OR description ILIKE ? OR pickup_city ILIKE ? OR delivery_city ILIKE ?',
        search_term, search_term, search_term, search_term
      )
    end
    
    loads
  end

  def apply_search_filters(loads, carrier)
    # Equipment compatibility
    equipment_types = carrier.equipment_list
    loads = loads.where(equipment_type: equipment_types) if equipment_types.any?
    
    # Service area
    service_areas = carrier.service_area_list
    loads = loads.where(pickup_state: service_areas) if service_areas.any?
    
    # Distance filter
    if params[:max_distance].present? && carrier.current_location.present?
      # This would require a more complex query in production
      # For now, we'll filter in Ruby after loading
    end
    
    # Weight capacity (would need vehicle information)
    loads = loads.where('weight <= ?', params[:max_weight]) if params[:max_weight].present?
    
    # Exclude hazmat if carrier is not certified
    loads = loads.where(is_hazmat: false) unless carrier.user.driver_profile&.is_hazmat_certified?
    
    loads
  end

  def load_response(load)
    {
      id: load.id,
      reference_number: load.reference_number,
      status: load.status,
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
      rate_per_mile: load.rate_per_mile,
      special_requirements: load.special_requirements,
      time_to_pickup: load.time_to_pickup,
      days_in_transit: load.days_in_transit,
      posted_at: load.posted_at,
      expires_at: load.expires_at
    }
  end

  def detailed_load_response(load)
    response = load_response(load)
    
    response.merge!(
      description: load.description,
      dimensions: load.dimensions,
      special_instructions: load.special_instructions,
      pickup_full_address: load.pickup_full_address,
      pickup_time_window: load.pickup_time_window,
      pickup_contact_name: load.pickup_contact_name,
      pickup_contact_phone: load.pickup_contact_phone,
      delivery_full_address: load.delivery_full_address,
      delivery_time_window: load.delivery_time_window,
      delivery_contact_name: load.delivery_contact_name,
      delivery_contact_phone: load.delivery_contact_phone,
      temperature_range: load.temperature_range,
      shipper: {
        id: load.shipper.id,
        company_name: load.shipper.company_name,
        average_rating: load.shipper.average_rating
      }
    )
    
    if load.assigned_carrier.present?
      response[:assigned_carrier] = {
        id: load.assigned_carrier.id,
        company_name: load.assigned_carrier.company_name,
        mc_number: load.assigned_carrier.mc_number,
        safety_rating: load.assigned_carrier.safety_rating,
        average_rating: load.assigned_carrier.average_rating
      }
    end
    
    response
  end

  def match_response(match)
    {
      id: match.id,
      status: match.status,
      match_score: match.match_score,
      rate_offered: match.rate_offered,
      rate_accepted: match.rate_accepted,
      estimated_pickup_time: match.estimated_pickup_time,
      estimated_delivery_time: match.estimated_delivery_time,
      distance_to_pickup: match.distance_to_pickup
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