class DistanceCalculationService
  def initialize
    @errors = []
  end

  def calculate(origin_coords, destination_coords)
    validate_coordinates!(origin_coords, destination_coords)
    
    # Calculate straight-line distance
    straight_line_distance = Geocoder::Calculations.distance_between(origin_coords, destination_coords)
    
    # Estimate driving distance (typically 1.2-1.4x straight line for most routes)
    driving_distance = estimate_driving_distance(straight_line_distance)
    
    # Calculate driving time
    driving_time_hours = estimate_driving_time(driving_distance)
    
    {
      miles: driving_distance.round(2),
      kilometers: (driving_distance * 1.60934).round(2),
      straight_line_miles: straight_line_distance.round(2),
      driving_time_hours: driving_time_hours.round(2)
    }
  rescue StandardError => e
    Rails.logger.error "Distance calculation error: #{e.message}"
    raise e
  end

  private

  def validate_coordinates!(origin, destination)
    unless valid_coordinate_pair?(origin)
      raise ArgumentError, "Invalid origin coordinates: #{origin}"
    end
    
    unless valid_coordinate_pair?(destination)
      raise ArgumentError, "Invalid destination coordinates: #{destination}"
    end
  end

  def valid_coordinate_pair?(coords)
    return false unless coords.is_a?(Array) && coords.length == 2
    
    lat, lng = coords
    lat.between?(-90, 90) && lng.between?(-180, 180)
  end

  def estimate_driving_distance(straight_line_distance)
    # Apply realistic multiplier based on distance
    case straight_line_distance
    when 0..50
      straight_line_distance * 1.4  # More roads/turns in short distances
    when 50..200
      straight_line_distance * 1.3  # Medium distance routes
    when 200..500
      straight_line_distance * 1.25 # Highway-heavy long distances
    else
      straight_line_distance * 1.2  # Interstate routes
    end
  end

  def estimate_driving_time(driving_distance)
    # Estimate based on distance and typical speeds
    case driving_distance
    when 0..50
      driving_distance / 45.0  # City/local roads - 45 mph average
    when 50..200
      driving_distance / 50.0  # Mixed roads - 50 mph average
    else
      driving_distance / 55.0  # Highway routes - 55 mph average
    end
  end
end