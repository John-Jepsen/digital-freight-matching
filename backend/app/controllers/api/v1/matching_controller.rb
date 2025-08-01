class Api::V1::MatchingController < ApplicationController
  before_action :authenticate_user!

  # POST /api/v1/matching/find_carriers_for_load
  def find_carriers_for_load
    authorize_shipper_or_admin!
    
    load = Load.find(params[:load_id])
    
    # Verify shipper owns the load
    unless current_user.admin? || load.shipper.user == current_user
      return render json: { error: 'Access denied' }, status: :forbidden
    end
    
    # Use service to find eligible carriers
    service = MatchingAlgorithmService.new(load, matching_options)
    result = service.find_eligible_carriers
    
    if result[:success]
      render json: {
        load: load_summary(load),
        potential_matches: result[:carriers].map { |data| carrier_match_response(data) },
        matching_criteria: result[:search_criteria],
        total_found: result[:total_found]
      }
    else
      render json: {
        error: 'Carrier search failed',
        details: result[:errors]
      }, status: :internal_server_error
    end
    
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Load not found' }, status: :not_found
  end

  # POST /api/v1/matching/find_loads_for_carrier
  def find_loads_for_carrier
    authorize_carrier_or_driver!
    
    carrier = get_user_carrier
    return render json: { error: 'Carrier profile required' }, status: :bad_request unless carrier
    
    # Use LoadSearchService for consistency
    search_filters = { page: params[:page], per_page: params[:per_page] }
    service = LoadSearchService.new(carrier, search_filters)
    result = service.search
    
    if result[:success]
      render json: {
        carrier: carrier_summary(carrier),
        available_loads: result[:loads].map { |data| load_match_response(data) },
        matching_criteria: result[:carrier_info],
        meta: result[:pagination]
      }
    else
      render json: {
        error: 'Load search failed',
        details: result[:errors]
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/matching/recommendations
  def recommendations
    case current_user.user_type
    when 'shipper'
      shipper_recommendations
    when 'carrier', 'driver'
      carrier_recommendations
    else
      render json: { error: 'Recommendations not available for this user type' }, status: :forbidden
    end
  end

  # POST /api/v1/matching/create_match
  def create_match
    authorize_shipper_or_admin!
    
    load = Load.find(params[:load_id])
    carrier = Carrier.find(params[:carrier_id])
    
    # Verify permissions
    unless current_user.admin? || load.shipper.user == current_user
      return render json: { error: 'Access denied' }, status: :forbidden
    end
    
    # Check compatibility
    unless load.can_be_matched_with?(carrier)
      return render json: {
        error: 'Carrier cannot handle this load',
        details: ['Equipment type, service area, or requirements not compatible']
      }, status: :unprocessable_entity
    end
    
    # Create match
    match = load.matches.build(
      carrier: carrier,
      status: 'offered',
      rate_offered: params[:rate_offered] || load.total_rate,
      notes: params[:notes]
    )
    
    if match.save
      match.make_offer! if match.may_make_offer?
      
      render json: {
        message: 'Match created successfully',
        match: detailed_match_response(match)
      }, status: :created
    else
      render json: {
        error: 'Failed to create match',
        details: match.errors.full_messages
      }, status: :unprocessable_entity
    end
    
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  private

  def authorize_shipper_or_admin!
    return if current_user.admin? || current_user.shipper?
    
    render json: { error: 'Shipper or admin access required' }, status: :forbidden
  end

  def authorize_carrier_or_driver!
    return if current_user.carrier? || current_user.driver?
    
    render json: { error: 'Carrier or driver access required' }, status: :forbidden
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

  def matching_options
    {
      max_distance_to_pickup: params[:max_distance]&.to_i,
      min_safety_rating: params[:min_safety_rating],
      verified_only: params[:verified_only] == 'true',
      limit: params[:limit]&.to_i || 10
    }
  end

  def shipper_recommendations
    shipper = current_user.shipper_profile
    return render json: { error: 'Shipper profile required' }, status: :bad_request unless shipper
    
    # Get recent active loads
    recent_loads = shipper.loads.where('created_at >= ?', 30.days.ago).limit(5)
    
    # Find top performing carriers
    top_carriers = Carrier.joins(:matches)
                          .where(matches: { load_id: shipper.loads.ids })
                          .where('matches.status = ?', 'accepted')
                          .group('carriers.id')
                          .order('COUNT(matches.id) DESC')
                          .limit(10)
    
    render json: {
      recent_loads: recent_loads.map { |load| load_summary(load) },
      recommended_carriers: top_carriers.map { |carrier| carrier_summary(carrier) },
      performance_insights: {
        total_loads_posted: shipper.loads.count,
        successful_matches: shipper.loads.joins(:active_match).count,
        average_time_to_match: calculate_average_time_to_match(shipper),
        preferred_equipment_types: get_preferred_equipment_types(shipper)
      }
    }
  end

  def carrier_recommendations
    carrier = get_user_carrier
    return render json: { error: 'Carrier profile required' }, status: :bad_request unless carrier
    
    # Find recommended loads based on history and preferences
    recommended_loads = Load.available
                           .where(equipment_type: carrier.equipment_list)
                           .where(pickup_state: carrier.service_area_list)
                           .limit(10)
    
    # Get performance insights
    performance_data = {
      total_loads_completed: carrier.total_completed_loads,
      on_time_percentage: carrier.on_time_percentage,
      average_rating: carrier.average_rating,
      preferred_lanes: carrier.preferred_lane_list,
      earnings_last_30_days: calculate_recent_earnings(carrier)
    }
    
    render json: {
      recommended_loads: recommended_loads.map { |load| load_summary(load) },
      performance_insights: performance_data,
      market_trends: {
        average_rate_per_mile: calculate_market_rate_per_mile(carrier.service_area_list),
        load_volume_trend: calculate_load_volume_trend(carrier.service_area_list),
        hot_lanes: identify_hot_lanes(carrier.service_area_list)
      }
    }
  end

  def calculate_estimated_cost(load, carrier)
    distance = load.distance_miles || 0
    deadhead = carrier.distance_from(load.pickup_coordinates) || 0
    total_miles = distance + deadhead
    
    # Basic cost calculation
    fuel_cost = total_miles * 0.65  # Estimated fuel cost per mile
    driver_cost = total_miles * 0.50  # Driver cost per mile
    maintenance_cost = total_miles * 0.15  # Maintenance cost per mile
    
    fuel_cost + driver_cost + maintenance_cost
  end

  def calculate_compatibility_factors(load, carrier)
    factors = {}
    
    # Equipment match
    factors[:equipment_match] = carrier.equipment_list.include?(load.equipment_type)
    
    # Service area match
    factors[:pickup_area_match] = carrier.service_area_list.include?(load.pickup_state)
    factors[:delivery_area_match] = carrier.service_area_list.include?(load.delivery_state)
    
    # Special requirements
    factors[:hazmat_compatible] = !load.is_hazmat? || carrier.user.driver_profile&.is_hazmat_certified?
    factors[:team_compatible] = !load.is_team_driver? || carrier.user.driver_profile&.is_team_driver?
    factors[:temperature_compatible] = !load.temperature_controlled? || carrier.vehicles.temperature_controlled.any?
    
    # Capacity match
    if load.weight.present?
      max_capacity = carrier.vehicles.maximum(:capacity_weight) || 0
      factors[:weight_compatible] = load.weight <= max_capacity
    end
    
    factors
  end

  def estimate_revenue(load, carrier)
    gross_revenue = load.total_rate
    estimated_cost = calculate_estimated_cost(load, carrier)
    net_revenue = gross_revenue - estimated_cost
    
    {
      gross_revenue: gross_revenue,
      estimated_cost: estimated_cost,
      net_revenue: net_revenue,
      profit_margin: gross_revenue > 0 ? (net_revenue / gross_revenue * 100).round(2) : 0
    }
  end

  def calculate_profit_factors(load, carrier)
    distance = load.distance_miles || 0
    rate_per_mile = distance > 0 ? load.total_rate / distance : 0
    
    {
      rate_per_mile: rate_per_mile,
      deadhead_miles: carrier.distance_from(load.pickup_coordinates) || 0,
      estimated_fuel_cost: (distance * 0.65).round(2),
      market_rate_comparison: compare_to_market_rate(load, carrier)
    }
  end

  def compare_to_market_rate(load, carrier)
    # This would integrate with market data APIs
    # For now, return a simple comparison
    market_rate_per_mile = 2.50  # Example market rate
    load_rate_per_mile = load.distance_miles.present? && load.distance_miles > 0 ? 
                        load.total_rate / load.distance_miles : 0
    
    if load_rate_per_mile > market_rate_per_mile * 1.1
      'above_market'
    elsif load_rate_per_mile < market_rate_per_mile * 0.9
      'below_market'
    else
      'market_rate'
    end
  end

  def calculate_average_time_to_match(shipper)
    matched_loads = shipper.loads.joins(:active_match)
    return 0 if matched_loads.empty?
    
    total_time = matched_loads.sum do |load|
      match = load.active_match
      next 0 unless match.accepted_at.present? && load.posted_at.present?
      
      (match.accepted_at - load.posted_at) / 1.hour
    end
    
    (total_time / matched_loads.count).round(2)
  end

  def get_preferred_equipment_types(shipper)
    shipper.loads
           .group(:equipment_type)
           .order('count_id DESC')
           .limit(3)
           .count('id')
           .keys
  end

  def calculate_recent_earnings(carrier)
    thirty_days_ago = 30.days.ago
    carrier.matches
           .joins(:load)
           .where('matches.accepted_at >= ?', thirty_days_ago)
           .where(status: 'accepted')
           .sum(:rate_accepted) || 0
  end

  def calculate_market_rate_per_mile(service_areas)
    # This would integrate with market data
    # For now, return a simple average
    2.45
  end

  def calculate_load_volume_trend(service_areas)
    # This would analyze historical data
    # For now, return a simple trend
    'increasing'
  end

  def identify_hot_lanes(service_areas)
    # This would analyze popular routes
    # For now, return example hot lanes
    [
      { origin: 'GA', destination: 'FL', average_rate: 2.65 },
      { origin: 'AL', destination: 'TN', average_rate: 2.55 }
    ]
  end

  def carrier_match_response(data)
    carrier = data[:carrier]
    {
      carrier: carrier_summary(carrier),
      match_score: data[:match_score],
      distance_to_pickup: data[:distance_to_pickup],
      estimated_cost: data[:estimated_cost],
      compatibility_factors: data[:compatibility_factors]
    }
  end

  def load_match_response(data)
    if data.is_a?(Hash) && data[:load]
      # Data from service
      load = data[:load]
      {
        load: load_summary(load),
        match_score: data[:score],
        distance_to_pickup: data[:distance_to_pickup],
        estimated_revenue: data[:revenue_estimate],
        profit_factors: data[:profit_factors]
      }
    else
      # Legacy data structure
      load = data[:load]
      {
        load: load_summary(load),
        match_score: data[:match_score],
        distance_to_pickup: data[:distance_to_pickup],
        estimated_revenue: data[:estimated_revenue],
        profit_factors: data[:profit_factors]
      }
    end
  end

  def detailed_match_response(match)
    {
      id: match.id,
      status: match.status,
      match_score: match.match_score,
      rate_offered: match.rate_offered,
      rate_accepted: match.rate_accepted,
      estimated_pickup_time: match.estimated_pickup_time,
      estimated_delivery_time: match.estimated_delivery_time,
      distance_to_pickup: match.distance_to_pickup,
      notes: match.notes,
      created_at: match.created_at,
      load: load_summary(match.load),
      carrier: carrier_summary(match.carrier)
    }
  end

  def load_summary(load)
    {
      id: load.id,
      reference_number: load.reference_number,
      commodity: load.commodity,
      weight: load.weight,
      pickup_location: "#{load.pickup_city}, #{load.pickup_state}",
      delivery_location: "#{load.delivery_city}, #{load.delivery_state}",
      pickup_date: load.pickup_date,
      delivery_date: load.delivery_date,
      equipment_type: load.equipment_type,
      rate: load.rate,
      total_rate: load.total_rate,
      distance_miles: load.distance_miles
    }
  end

  def carrier_summary(carrier)
    {
      id: carrier.id,
      company_name: carrier.company_name,
      mc_number: carrier.mc_number,
      location: "#{carrier.city}, #{carrier.state}",
      fleet_size: carrier.fleet_size,
      safety_rating: carrier.safety_rating,
      average_rating: carrier.average_rating,
      equipment_types: carrier.equipment_list,
      service_areas: carrier.service_area_list
    }
  end
end