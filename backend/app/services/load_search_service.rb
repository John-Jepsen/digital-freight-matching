class LoadSearchService
  attr_reader :carrier, :filters, :errors

  def initialize(carrier, filters = {})
    @carrier = carrier
    @filters = filters
    @errors = []
  end

  def search
    begin
      # Start with available loads
      loads_scope = Load.available
      
      # Apply carrier capability filters
      loads_scope = apply_carrier_filters(loads_scope)
      
      # Apply user-provided filters
      loads_scope = apply_search_filters(loads_scope)
      
      # Calculate match scores and sort
      loads_with_scores = calculate_match_scores(loads_scope)
      
      # Apply pagination
      paginated_results = paginate_results(loads_with_scores)
      
      success_response(paginated_results)
    rescue StandardError => e
      Rails.logger.error "Load search failed: #{e.message}"
      @errors = ["Search failed: #{e.message}"]
      error_response
    end
  end

  private

  def apply_carrier_filters(loads_scope)
    return loads_scope unless @carrier

    # Equipment compatibility
    equipment_types = @carrier.equipment_list
    loads_scope = loads_scope.where(equipment_type: equipment_types) if equipment_types.any?
    
    # Service area
    service_areas = @carrier.service_area_list
    loads_scope = loads_scope.where(pickup_state: service_areas) if service_areas.any?
    
    # Exclude hazmat if carrier is not certified
    unless @carrier.user.driver_profile&.is_hazmat_certified?
      loads_scope = loads_scope.where(is_hazmat: false)
    end
    
    # Weight capacity filter (if vehicle info available)
    if @carrier.vehicles.any?
      max_capacity = @carrier.vehicles.maximum(:capacity_weight)
      loads_scope = loads_scope.where('weight <= ?', max_capacity) if max_capacity
    end
    
    loads_scope
  end

  def apply_search_filters(loads_scope)
    # Equipment type filter
    if @filters[:equipment_type].present?
      loads_scope = loads_scope.where(equipment_type: @filters[:equipment_type])
    end
    
    # Origin/destination filters
    if @filters[:origin_state].present?
      loads_scope = loads_scope.where(pickup_state: @filters[:origin_state])
    end
    
    if @filters[:destination_state].present?
      loads_scope = loads_scope.where(delivery_state: @filters[:destination_state])
    end
    
    # Date range filters
    if @filters[:pickup_date_from].present?
      loads_scope = loads_scope.where('pickup_date >= ?', Date.parse(@filters[:pickup_date_from]))
    end
    
    if @filters[:pickup_date_to].present?
      loads_scope = loads_scope.where('pickup_date <= ?', Date.parse(@filters[:pickup_date_to]))
    end
    
    # Rate filters
    if @filters[:min_rate].present?
      loads_scope = loads_scope.where('total_rate >= ?', @filters[:min_rate])
    end
    
    if @filters[:max_rate].present?
      loads_scope = loads_scope.where('total_rate <= ?', @filters[:max_rate])
    end
    
    # Distance filter
    if @filters[:max_distance].present? && @carrier&.current_location.present?
      loads_scope = filter_by_distance(loads_scope, @filters[:max_distance].to_i)
    end
    
    # Special requirements
    loads_scope = loads_scope.where(is_expedited: true) if @filters[:expedited] == 'true'
    loads_scope = loads_scope.where(temperature_controlled: true) if @filters[:temperature_controlled] == 'true'
    
    # Text search
    if @filters[:search].present?
      search_term = "%#{@filters[:search]}%"
      loads_scope = loads_scope.where(
        'commodity ILIKE ? OR description ILIKE ? OR pickup_city ILIKE ? OR delivery_city ILIKE ?',
        search_term, search_term, search_term, search_term
      )
    end
    
    loads_scope
  end

  def filter_by_distance(loads_scope, max_distance)
    return loads_scope unless @carrier.current_location.present?
    
    # This is a simplified distance filter
    # In production, you'd want to use PostGIS for efficient spatial queries
    loads_scope.select do |load|
      next false unless load.pickup_coordinates.present?
      
      distance = Geocoder::Calculations.distance_between(
        @carrier.current_location,
        load.pickup_coordinates
      )
      distance <= max_distance
    end
  end

  def calculate_match_scores(loads_scope)
    loads_with_scores = loads_scope.map do |load|
      # Skip loads that can't be matched
      next unless load.can_be_matched_with?(@carrier)
      
      score = load.matching_score_for(@carrier)
      distance_to_pickup = @carrier.distance_from(load.pickup_coordinates) if @carrier.current_location.present?
      
      {
        load: load,
        score: score,
        distance_to_pickup: distance_to_pickup,
        can_match: true,
        revenue_estimate: estimate_revenue(load),
        profit_factors: calculate_profit_factors(load)
      }
    end.compact
    
    # Sort by match score (highest first)
    loads_with_scores.sort_by { |item| -item[:score] }
  end

  def estimate_revenue(load)
    return nil unless @carrier

    distance = load.distance_miles
    return load.total_rate unless distance.present? && distance > 0

    deadhead_miles = @carrier.distance_from(load.pickup_coordinates) || 0
    total_miles = distance + deadhead_miles
    
    # Estimate costs
    fuel_cost = total_miles * 0.65
    maintenance_cost = total_miles * 0.15
    estimated_costs = fuel_cost + maintenance_cost
    
    net_revenue = load.total_rate - estimated_costs
    
    {
      gross_revenue: load.total_rate,
      estimated_costs: estimated_costs,
      net_revenue: net_revenue,
      profit_margin: load.total_rate > 0 ? (net_revenue / load.total_rate * 100).round(2) : 0,
      deadhead_miles: deadhead_miles
    }
  end

  def calculate_profit_factors(load)
    distance = load.distance_miles || 0
    rate_per_mile = distance > 0 ? load.total_rate / distance : 0
    
    {
      rate_per_mile: rate_per_mile.round(2),
      distance_miles: distance,
      market_rate_comparison: compare_to_market_rate(load),
      load_factors: analyze_load_factors(load)
    }
  end

  def compare_to_market_rate(load)
    # This would integrate with market rate data
    market_rate_per_mile = 2.50  # Example baseline
    load_rate_per_mile = load.distance_miles.present? && load.distance_miles > 0 ? 
                        load.total_rate / load.distance_miles : 0
    
    percentage_difference = market_rate_per_mile > 0 ? 
                           ((load_rate_per_mile - market_rate_per_mile) / market_rate_per_mile * 100).round(2) : 0
    
    {
      market_rate_per_mile: market_rate_per_mile,
      load_rate_per_mile: load_rate_per_mile.round(2),
      percentage_difference: percentage_difference,
      rating: case percentage_difference
              when 10..Float::INFINITY then 'above_market'
              when -10..10 then 'market_rate'
              else 'below_market'
              end
    }
  end

  def analyze_load_factors(load)
    factors = []
    factors << 'expedited' if load.is_expedited?
    factors << 'hazmat' if load.is_hazmat?
    factors << 'temperature_controlled' if load.temperature_controlled?
    factors << 'team_driver_required' if load.is_team_driver?
    factors << 'high_value' if load.cargo_details.any?(&:is_high_value?)
    factors << 'weekend_pickup' if load.pickup_date.saturday? || load.pickup_date.sunday?
    
    factors
  end

  def paginate_results(loads_with_scores)
    page = (@filters[:page] || 1).to_i
    per_page = (@filters[:per_page] || 25).to_i
    
    total_count = loads_with_scores.count
    offset = (page - 1) * per_page
    
    paginated_loads = loads_with_scores[offset, per_page] || []
    
    {
      loads: paginated_loads,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil,
        has_next_page: page * per_page < total_count,
        has_previous_page: page > 1
      }
    }
  end

  def success_response(results)
    {
      success: true,
      **results,
      search_criteria: @filters,
      carrier_info: carrier_search_info
    }
  end

  def error_response
    {
      success: false,
      errors: @errors,
      loads: [],
      pagination: default_pagination
    }
  end

  def carrier_search_info
    return {} unless @carrier
    
    {
      carrier_id: @carrier.id,
      equipment_types: @carrier.equipment_list,
      service_areas: @carrier.service_area_list,
      current_location: @carrier.current_location
    }
  end

  def default_pagination
    {
      current_page: 1,
      per_page: 25,
      total_count: 0,
      total_pages: 0,
      has_next_page: false,
      has_previous_page: false
    }
  end
end