class MatchingAlgorithmService
  attr_reader :load, :options, :errors

  def initialize(load, options = {})
    @load = load
    @options = options
    @errors = []
  end

  def find_eligible_carriers
    begin
      # Get all active carriers
      carriers_scope = Carrier.active.verified
      
      # Apply basic compatibility filters
      carriers_scope = apply_compatibility_filters(carriers_scope)
      
      # Apply optional filters from options
      carriers_scope = apply_option_filters(carriers_scope)
      
      # Calculate match scores and sort
      carriers_with_scores = calculate_carrier_scores(carriers_scope)
      
      # Apply limits
      limit = @options[:limit] || 10
      top_carriers = carriers_with_scores.first(limit)
      
      success_response(top_carriers)
    rescue StandardError => e
      Rails.logger.error "Carrier matching failed: #{e.message}"
      @errors = ["Matching failed: #{e.message}"]
      error_response
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
    # Equipment type compatibility
    carriers_scope = carriers_scope.joins(:vehicles)
                                  .where(vehicles: { equipment_type: @load.equipment_type, is_active: true })
    
    # Service area compatibility
    carriers_scope = carriers_scope.where(
      "service_areas LIKE ? OR service_areas LIKE ?", 
      "%#{@load.pickup_state}%", 
      "%ALL%"
    )
    
    # Hazmat certification if required
    if @load.is_hazmat?
      carriers_scope = carriers_scope.joins(:drivers)
                                   .where(drivers: { is_hazmat_certified: true, is_active: true })
    end
    
    # Team driver requirement
    if @load.is_team_driver?
      carriers_scope = carriers_scope.joins(:drivers)
                                   .where(drivers: { is_team_driver: true, is_active: true })
    end
    
    # Weight capacity
    if @load.weight.present?
      carriers_scope = carriers_scope.joins(:vehicles)
                                   .where('vehicles.capacity_weight >= ?', @load.weight)
    end
    
    carriers_scope.distinct
  end

  def apply_option_filters(carriers_scope)
    # Distance filter
    if @options[:max_distance_to_pickup].present?
      carriers_scope = filter_by_distance(carriers_scope, @options[:max_distance_to_pickup])
    end
    
    # Safety rating filter
    if @options[:min_safety_rating].present?
      carriers_scope = carriers_scope.where('safety_rating >= ?', @options[:min_safety_rating])
    end
    
    # Verified only filter
    if @options[:verified_only]
      carriers_scope = carriers_scope.where(is_verified: true)
    end
    
    carriers_scope
  end

  def filter_by_distance(carriers_scope, max_distance)
    return carriers_scope unless @load.pickup_coordinates.present?
    
    # This is simplified - in production use PostGIS
    carriers_scope.select do |carrier|
      next false unless carrier.current_location.present?
      
      distance = Geocoder::Calculations.distance_between(
        carrier.current_location,
        @load.pickup_coordinates
      )
      distance <= max_distance
    end
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
    if carrier.on_time_percentage > 95
      bonus_points += 20
      factors[:on_time_bonus] = 20
    elsif carrier.on_time_percentage > 90
      bonus_points += 10
      factors[:on_time_bonus] = 10
    end
    
    # Rating bonus
    if carrier.average_rating >= 4.5
      bonus_points += 15
      factors[:rating_bonus] = 15
    elsif carrier.average_rating >= 4.0
      bonus_points += 8
      factors[:rating_bonus] = 8
    end
    
    # Previous successful loads with this shipper
    previous_loads = carrier.matches
                           .joins(:load)
                           .where(loads: { shipper_id: @load.shipper_id })
                           .where(status: 'accepted')
                           .count
    
    if previous_loads > 0
      relationship_bonus = [previous_loads * 5, 25].min  # Max 25 points
      bonus_points += relationship_bonus
      factors[:relationship_bonus] = relationship_bonus
    end
    
    # Equipment specialization bonus
    if carrier.equipment_list.count == 1 && carrier.equipment_list.first == @load.equipment_type
      bonus_points += 10
      factors[:specialization_bonus] = 10
    end
    
    # Availability bonus (carriers with available capacity)
    if carrier.available_capacity > 0
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

  def success_response(carriers_data)
    {
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
  end

  def error_response
    {
      success: false,
      errors: @errors,
      carriers: []
    }
  end
end