class MatchingAlgorithmService
  attr_reader :load, :options, :errors

  def initialize(load, options = {})
    @load = load
    @options = options
    @errors = []
    @performance_monitor = DatabasePerformanceMonitorService.instance
  end

  def find_eligible_carriers
    DatabasePerformanceMonitorService.monitor_performance('carrier_matching') do
      begin
        # Performance monitoring
        start_time = Time.current
        
        # Get all active carriers with preloaded associations 
        carriers_scope = Carrier.active.verified.includes(
          :user,
          vehicles: [:driver],
          drivers: [],
          matches: [:load]
        )
        
        # Apply basic compatibility filters
        carriers_scope = apply_compatibility_filters(carriers_scope)
        
        # Apply optional filters from options
        carriers_scope = apply_option_filters(carriers_scope)
        
        # Monitor the final query execution
        carriers_result = DatabasePerformanceMonitorService.monitor_query('carrier_matching_final', carriers_scope)
        
        # Calculate match scores and sort
        carriers_with_scores = calculate_carrier_scores(carriers_result)
        
        # Apply limits
        limit = @options[:limit] || 10
        top_carriers = carriers_with_scores.first(limit)
        
        # Log execution time
        execution_time = (Time.current - start_time) * 1000
        @performance_monitor.log_query('carrier_matching_total', execution_time)
        
        success_response(top_carriers, execution_time)
      rescue StandardError => e
        Rails.logger.error "Carrier matching failed: #{e.message}"
        @errors = ["Matching failed: #{e.message}"]
        error_response
      end
    end
  end

  def create_automatic_matches
    begin
      eligible_carriers = find_eligible_carriers
      return error_response unless eligible_carriers[:success]
      
      carriers_data = eligible_carriers[:carriers]
      matches_created = []
      
      carriers_data.first(5).each do |carrier_data|  # Auto-match with top 5
        carrier = carrier_data[:carrier]
        
        # Check if match already exists
        existing_match = @load.matches.find_by(carrier: carrier)
        next if existing_match
        
        # Create new match
        match = create_match_for_carrier(carrier, carrier_data)
        matches_created << match if match
      end
      
      {
        success: true,
        matches_created: matches_created,
        total_matches: matches_created.count
      }
    rescue StandardError => e
      Rails.logger.error "Automatic matching failed: #{e.message}"
      @errors = ["Automatic matching failed: #{e.message}"]
      error_response
    end
  end

  private

  def apply_compatibility_filters(carriers_scope)
    # Use optimized scope for basic eligibility filtering
    carriers_scope = carriers_scope.eligible_for_matching
    
    # Equipment type compatibility - using optimized joins and composite indexes
    carriers_scope = carriers_scope.joins(:vehicles)
                                  .where(vehicles: { 
                                    equipment_type: @load.equipment_type, 
                                    status: 'active' 
                                  })
    
    # Service area compatibility - optimize JSON array search
    carriers_scope = carriers_scope.serving_area(@load.pickup_state)
    
    # Hazmat certification if required - using optimized scope and join
    if @load.is_hazmat?
      carriers_scope = carriers_scope.joins(:drivers)
                                   .merge(Driver.where(
                                     is_hazmat_certified: true, 
                                     status: 'available' 
                                   ))
    end
    
    # Team driver requirement - using optimized scope and join
    if @load.is_team_driver?
      carriers_scope = carriers_scope.joins(:drivers)
                                   .merge(Driver.where(
                                     is_team_driver: true, 
                                     status: 'available' 
                                   ))
    end
    
    # Weight capacity - using optimized vehicle scope with subquery
    if @load.weight.present?
      carriers_scope = carriers_scope.where(
        id: Vehicle.available_for_load(@load.equipment_type, @load.weight)
               .select(:carrier_id)
      )
    end
    
    carriers_scope.distinct
  end

  def apply_option_filters(carriers_scope)
    # Distance filter - use optimized geographic scope
    if @options[:max_distance_to_pickup].present? && @load.pickup_coordinates.present?
      pickup_lat, pickup_lng = @load.pickup_coordinates
      carriers_scope = carriers_scope.near_location(pickup_lat, pickup_lng, @options[:max_distance_to_pickup])
    end
    
    # Safety rating filter - use optimized composite scope
    if @options[:min_safety_rating].present?
      carriers_scope = carriers_scope.with_safety_standard(@options[:min_safety_rating])
    else
      # Default safety standard if not specified
      carriers_scope = carriers_scope.with_safety_standard('satisfactory')
    end
    
    # Verified only filter - already handled by eligible_for_matching scope
    # No additional filtering needed for verified_only since eligible_for_matching includes it
    
    carriers_scope
  end

  def filter_by_distance(carriers_scope, max_distance)
    return carriers_scope unless @load.pickup_coordinates.present?
    
    # Use database-level distance calculation for better performance
    pickup_lat, pickup_lng = @load.pickup_coordinates
    
    # Use Haversine formula in SQL with spatial index
    carriers_scope.where(
      "3959 * acos(
        cos(radians(?)) * cos(radians(latitude)) * 
        cos(radians(longitude) - radians(?)) + 
        sin(radians(?)) * sin(radians(latitude))
      ) <= ?",
      pickup_lat, pickup_lng, pickup_lat, max_distance
    ).where.not(latitude: nil, longitude: nil)
  end

  def calculate_carrier_scores(carriers_scope)
    carriers_with_scores = carriers_scope.map do |carrier|
      next unless @load.can_be_matched_with?(carrier)
      
      base_score = @load.matching_score_for(carrier)
      additional_factors = calculate_additional_factors(carrier)
      final_score = base_score + additional_factors[:bonus_points]
      
      {
        carrier: carrier,
        match_score: final_score,
        base_score: base_score,
        additional_factors: additional_factors,
        distance_to_pickup: carrier.distance_from(@load.pickup_coordinates),
        estimated_cost: calculate_estimated_cost(carrier),
        compatibility_rating: calculate_compatibility_rating(carrier)
      }
    end.compact
    
    # Sort by final score (highest first)
    carriers_with_scores.sort_by { |item| -item[:match_score] }
  end

  def calculate_additional_factors(carrier)
    bonus_points = 0
    factors = {}
    
    # Historical performance bonus
    on_time_perc = carrier.on_time_percentage
    if on_time_perc > 95
      bonus_points += 20
      factors[:on_time_bonus] = 20
    elsif on_time_perc > 90
      bonus_points += 10
      factors[:on_time_bonus] = 10
    end
    
    # Rating bonus
    avg_rating = carrier.average_rating
    if avg_rating >= 4.5
      bonus_points += 15
      factors[:rating_bonus] = 15
    elsif avg_rating >= 4.0
      bonus_points += 8
      factors[:rating_bonus] = 8
    end
    
    # Previous successful loads with this shipper - optimized query
    previous_loads = carrier.matches
                           .joins(:load)
                           .where(loads: { shipper_id: @load.shipper_id }, status: 'accepted')
                           .count
    
    if previous_loads > 0
      relationship_bonus = [previous_loads * 5, 25].min  # Max 25 points
      bonus_points += relationship_bonus
      factors[:relationship_bonus] = relationship_bonus
    end
    
    # Equipment specialization bonus - use preloaded data
    equipment_list = carrier.equipment_list
    if equipment_list.count == 1 && equipment_list.first == @load.equipment_type
      bonus_points += 10
      factors[:specialization_bonus] = 10
    end
    
    # Availability bonus (carriers with available capacity)
    available_capacity = carrier.available_capacity
    if available_capacity > 0
      bonus_points += 5
      factors[:availability_bonus] = 5
    end
    
    {
      bonus_points: bonus_points,
      factors: factors
    }
  end

  def calculate_estimated_cost(carrier)
    return nil unless @load.distance_miles.present?
    
    distance = @load.distance_miles
    deadhead = carrier.distance_from(@load.pickup_coordinates) || 0
    total_miles = distance + deadhead
    
    # Basic cost calculation
    fuel_cost = total_miles * 0.65
    driver_cost = total_miles * 0.50
    maintenance_cost = total_miles * 0.15
    
    fuel_cost + driver_cost + maintenance_cost
  end

  def calculate_compatibility_rating(carrier)
    score = 0
    max_score = 0
    
    # Equipment compatibility (25 points)
    max_score += 25
    if carrier.equipment_list.include?(@load.equipment_type)
      score += 25
    end
    
    # Service area compatibility (20 points)
    max_score += 20
    if carrier.service_area_list.include?(@load.pickup_state)
      score += 15
    end
    if carrier.service_area_list.include?(@load.delivery_state)
      score += 5
    end
    
    # Special requirements (20 points)
    max_score += 20
    special_req_score = 0
    
    if @load.is_hazmat?
      special_req_score += carrier.user.driver_profile&.is_hazmat_certified? ? 5 : 0
    else
      special_req_score += 5  # No special requirement
    end
    
    if @load.temperature_controlled?
      special_req_score += carrier.vehicles.temperature_controlled.any? ? 5 : 0
    else
      special_req_score += 5
    end
    
    if @load.is_team_driver?
      special_req_score += carrier.user.driver_profile&.is_team_driver? ? 5 : 0
    else
      special_req_score += 5
    end
    
    special_req_score += 5  # Base points
    score += special_req_score
    
    # Capacity compatibility (15 points)
    max_score += 15
    if @load.weight.present?
      max_capacity = carrier.vehicles.maximum(:capacity_weight) || 0
      if max_capacity >= @load.weight * 1.2  # 20% buffer
        score += 15
      elsif max_capacity >= @load.weight
        score += 10
      end
    else
      score += 15  # No weight specified
    end
    
    # Location proximity (20 points)
    max_score += 20
    if carrier.current_location.present? && @load.pickup_coordinates.present?
      distance = carrier.distance_from(@load.pickup_coordinates)
      case distance
      when 0..50
        score += 20
      when 50..100
        score += 15
      when 100..200
        score += 10
      when 200..300
        score += 5
      end
    else
      score += 10  # Unknown location gets middle score
    end
    
    # Return percentage
    max_score > 0 ? (score.to_f / max_score * 100).round(2) : 0
  end

  def create_match_for_carrier(carrier, carrier_data)
    match = @load.matches.build(
      carrier: carrier,
      status: 'offered',
      match_score: carrier_data[:match_score],
      rate_offered: @load.total_rate,
      estimated_pickup_time: estimate_pickup_time(carrier),
      estimated_delivery_time: estimate_delivery_time(carrier),
      distance_to_pickup: carrier_data[:distance_to_pickup],
      notes: "Auto-matched based on compatibility score: #{carrier_data[:match_score]}"
    )
    
    if match.save
      # Trigger state machine
      match.make_offer! if match.may_make_offer?
      
      # Send notification to carrier
      # NotifyCarrierOfMatchJob.perform_later(match.id)
      
      match
    else
      Rails.logger.warn "Failed to create match: #{match.errors.full_messages.join(', ')}"
      nil
    end
  end

  def estimate_pickup_time(carrier)
    return @load.pickup_date unless carrier.current_location.present? && @load.pickup_coordinates.present?
    
    distance = carrier.distance_from(@load.pickup_coordinates)
    travel_hours = distance / 55.0  # Assume 55 mph average
    
    earliest_pickup = Time.current + travel_hours.hours
    target_pickup = @load.pickup_date.beginning_of_day
    
    [earliest_pickup, target_pickup].max
  end

  def estimate_delivery_time(carrier)
    pickup_time = estimate_pickup_time(carrier)
    return @load.delivery_date unless @load.distance_miles.present?
    
    delivery_travel_hours = @load.distance_miles / 55.0
    estimated_delivery = pickup_time + delivery_travel_hours.hours
    
    [estimated_delivery, @load.delivery_date.beginning_of_day].max
  end

  def success_response(carriers_data, execution_time = nil)
    response = {
      success: true,
      carriers: carriers_data,
      total_found: carriers_data.count,
      search_criteria: {
        load_id: @load.id,
        equipment_type: @load.equipment_type,
        pickup_location: "#{@load.pickup_city}, #{@load.pickup_state}",
        special_requirements: @load.special_requirements
      }
    }
    
    response[:execution_time_ms] = execution_time.round(2) if execution_time
    response
  end

  def explain_carrier_query_performance(carriers_scope)
    explain_result = ActiveRecord::Base.connection.execute(
      "EXPLAIN ANALYZE #{carriers_scope.to_sql}"
    )
    Rails.logger.info "Carrier Matching Query Plan:"
    explain_result.each { |row| Rails.logger.info row['QUERY PLAN'] }
  rescue StandardError => e
    Rails.logger.warn "Failed to analyze carrier query: #{e.message}"
  end

  def error_response
    {
      success: false,
      errors: @errors,
      carriers: []
    }
  end
end