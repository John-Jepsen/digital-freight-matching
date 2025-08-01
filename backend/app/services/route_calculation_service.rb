class RouteCalculationService
  attr_reader :route, :errors

  def initialize(route)
    @route = route
    @errors = []
  end

  def calculate
    begin
      # Validate input
      return error_response(['Invalid route object']) unless route&.origin_coordinates&.all?(&:present?)
      return error_response(['Invalid destination coordinates']) unless route&.destination_coordinates&.all?(&:present?)

      # Calculate basic route information
      route_data = calculate_basic_route
      
      # Try to get enhanced route data from Google Maps API if available
      enhanced_data = calculate_enhanced_route if google_maps_available?
      
      # Merge the data
      final_route_data = enhanced_data.present? ? enhanced_data : route_data
      
      # Calculate costs
      cost_data = calculate_route_costs(final_route_data)
      
      # Combine all data
      success_response(final_route_data.merge(cost_data))
    rescue StandardError => e
      Rails.logger.error "Route calculation failed: #{e.message}"
      error_response(["Route calculation failed: #{e.message}"])
    end
  end

  private

  def calculate_basic_route
    origin = route.origin_coordinates
    destination = route.destination_coordinates
    
    # Calculate straight-line distance
    distance = Geocoder::Calculations.distance_between(origin, destination)
    
    # Estimate driving distance (typically 1.2-1.4x straight line)
    driving_distance = distance * 1.3
    
    # Estimate duration based on average speed
    average_speed = route.avoid_highways ? 45.0 : 55.0
    duration_hours = driving_distance / average_speed
    duration_minutes = (duration_hours * 60).round
    
    {
      distance_miles: driving_distance.round(2),
      estimated_duration: duration_minutes,
      route_geometry: nil,
      waypoints: [],
      route_instructions: generate_basic_instructions(origin, destination),
      traffic_conditions: 'unknown'
    }
  end

  def calculate_enhanced_route
    return nil unless google_maps_api_key.present?
    
    begin
      # This would integrate with Google Maps Directions API
      # For now, return enhanced basic calculation
      basic_data = calculate_basic_route
      
      # Add some realistic variations for different optimization types
      case route.optimization_type
      when 'shortest'
        basic_data[:distance_miles] *= 0.95
        basic_data[:estimated_duration] = (basic_data[:estimated_duration] * 1.1).round
      when 'most_fuel_efficient'
        basic_data[:distance_miles] *= 1.05
        basic_data[:estimated_duration] = (basic_data[:estimated_duration] * 0.9).round
      when 'avoid_traffic'
        basic_data[:distance_miles] *= 1.1
        basic_data[:estimated_duration] = (basic_data[:estimated_duration] * 0.85).round
        basic_data[:traffic_conditions] = 'light'
      end
      
      # Add highway/toll adjustments
      if route.avoid_highways
        basic_data[:distance_miles] *= 1.15
        basic_data[:estimated_duration] = (basic_data[:estimated_duration] * 1.2).round
      end
      
      basic_data
    rescue StandardError => e
      Rails.logger.warn "Google Maps API call failed: #{e.message}"
      nil
    end
  end

  def calculate_route_costs(route_data)
    distance = route_data[:distance_miles]
    return {} unless distance.present? && distance > 0
    
    # Base fuel calculation
    fuel_price_per_gallon = 4.50  # Average diesel price
    mpg = 6.0  # Average truck MPG
    fuel_cost = (distance / mpg) * fuel_price_per_gallon
    
    # Toll cost estimation
    toll_cost = route.avoid_tolls ? 0 : estimate_toll_cost(distance)
    
    # Apply adjustments
    fuel_cost *= 1.1 if route.avoid_highways  # Less efficient roads
    
    {
      fuel_cost: fuel_cost.round(2),
      toll_cost: toll_cost.round(2)
    }
  end

  def estimate_toll_cost(distance)
    # Basic toll estimation - varies by region
    # This would integrate with toll calculation APIs
    case distance
    when 0..50
      0
    when 50..200
      distance * 0.15
    when 200..500
      distance * 0.12
    else
      distance * 0.10
    end
  end

  def generate_basic_instructions(origin, destination)
    [
      {
        instruction: "Head towards destination",
        distance: 0,
        duration: 0
      },
      {
        instruction: "Continue on route to #{destination[0]}, #{destination[1]}",
        distance: route.distance_miles || 100,
        duration: route.estimated_duration || 120
      },
      {
        instruction: "Arrive at destination",
        distance: 0,
        duration: 0
      }
    ]
  end

  def google_maps_available?
    google_maps_api_key.present?
  end

  def google_maps_api_key
    Rails.application.credentials.google_maps_api_key || ENV['GOOGLE_MAPS_API_KEY']
  end

  def success_response(route_attributes)
    {
      success: true,
      route_attributes: route_attributes
    }
  end

  def error_response(error_messages)
    @errors = error_messages
    {
      success: false,
      errors: error_messages
    }
  end
end