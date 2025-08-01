class CostCalculationService
  attr_reader :errors

  def initialize
    @errors = []
  end

  def calculate(origin:, destination:, vehicle_type: 'dry_van', fuel_price: 4.50, driver_rate: 0.55)
    begin
      # Calculate distance first
      distance_service = DistanceCalculationService.new
      distance_data = distance_service.calculate(origin, destination)
      distance_miles = distance_data[:miles]
      
      # Calculate different cost components
      fuel_cost = calculate_fuel_cost(distance_miles, vehicle_type, fuel_price)
      driver_cost = calculate_driver_cost(distance_miles, distance_data[:driving_time_hours], driver_rate)
      maintenance_cost = calculate_maintenance_cost(distance_miles, vehicle_type)
      toll_cost = estimate_toll_cost(distance_miles)
      
      # Calculate total operational cost
      total_operational_cost = fuel_cost + driver_cost + maintenance_cost + toll_cost
      
      # Add markup for profit margin (typically 15-25%)
      profit_margin = 0.20
      total_cost_with_margin = total_operational_cost * (1 + profit_margin)
      
      {
        distance_miles: distance_miles,
        driving_time_hours: distance_data[:driving_time_hours],
        cost_breakdown: {
          fuel_cost: fuel_cost.round(2),
          driver_cost: driver_cost.round(2),
          maintenance_cost: maintenance_cost.round(2),
          toll_cost: toll_cost.round(2),
          total_operational_cost: total_operational_cost.round(2),
          profit_margin_percentage: (profit_margin * 100).round(1),
          profit_margin_amount: (total_operational_cost * profit_margin).round(2),
          total_cost_with_margin: total_cost_with_margin.round(2)
        },
        cost_per_mile: (total_cost_with_margin / distance_miles).round(2),
        vehicle_type: vehicle_type,
        fuel_price_per_gallon: fuel_price,
        driver_rate_per_mile: driver_rate
      }
    rescue StandardError => e
      Rails.logger.error "Cost calculation error: #{e.message}"
      raise e
    end
  end

  private

  def calculate_fuel_cost(distance_miles, vehicle_type, fuel_price_per_gallon)
    mpg = get_fuel_efficiency(vehicle_type)
    gallons_needed = distance_miles / mpg
    gallons_needed * fuel_price_per_gallon
  end

  def calculate_driver_cost(distance_miles, driving_time_hours, driver_rate_per_mile)
    # Driver cost based on miles (most common in trucking)
    base_driver_cost = distance_miles * driver_rate_per_mile
    
    # Add additional cost for very long trips (fatigue, overnight stays)
    if driving_time_hours > 10
      overnight_allowance = ((driving_time_hours - 10) / 10).ceil * 150 # $150 per night
      base_driver_cost += overnight_allowance
    end
    
    base_driver_cost
  end

  def calculate_maintenance_cost(distance_miles, vehicle_type)
    maintenance_rate_per_mile = get_maintenance_rate(vehicle_type)
    distance_miles * maintenance_rate_per_mile
  end

  def estimate_toll_cost(distance_miles)
    # Basic toll estimation
    case distance_miles
    when 0..100
      0  # Local routes typically no tolls
    when 100..300
      distance_miles * 0.15  # $0.15 per mile average
    when 300..600
      distance_miles * 0.12  # Lower rate for longer distances
    else
      distance_miles * 0.10  # Interstate rates
    end
  end

  def get_fuel_efficiency(vehicle_type)
    # Miles per gallon for different vehicle types
    case vehicle_type
    when 'dry_van'
      6.0
    when 'refrigerated'
      5.5  # Reefer units consume more fuel
    when 'flatbed'
      6.2
    when 'step_deck'
      5.8
    when 'lowboy'
      4.5  # Heavy haul equipment
    when 'tanker'
      5.5
    when 'container'
      6.1
    when 'car_carrier'
      5.0
    when 'specialized'
      5.0
    else
      6.0  # Default
    end
  end

  def get_maintenance_rate(vehicle_type)
    # Maintenance cost per mile for different vehicle types
    case vehicle_type
    when 'dry_van'
      0.15
    when 'refrigerated'
      0.18  # More complex equipment
    when 'flatbed'
      0.16
    when 'step_deck'
      0.17
    when 'lowboy'
      0.25  # Heavy equipment, more wear
    when 'tanker'
      0.20
    when 'container'
      0.15
    when 'car_carrier'
      0.22
    when 'specialized'
      0.25
    else
      0.15  # Default
    end
  end
end