# == Schema Information
#
# Table name: routes
#
#  id                    :bigint           not null, primary key
#  match_id              :bigint           not null
#  origin_latitude       :decimal(10, 6)   not null
#  origin_longitude      :decimal(10, 6)   not null
#  destination_latitude  :decimal(10, 6)   not null
#  destination_longitude :decimal(10, 6)   not null
#  distance_miles        :decimal(8, 2)
#  estimated_duration    :integer          # in minutes
#  route_geometry        :text             # Encoded polyline
#  waypoints             :text             # JSON array of waypoints
#  route_instructions    :text             # JSON array of turn-by-turn directions
#  traffic_conditions    :string
#  toll_cost             :decimal(8, 2)
#  fuel_cost             :decimal(8, 2)
#  total_cost            :decimal(10, 2)
#  optimization_type     :string           default("fastest")
#  avoid_highways        :boolean          default(false)
#  avoid_tolls          :boolean          default(false)
#  vehicle_restrictions  :text             # JSON for truck restrictions
#  calculated_at         :datetime
#  expires_at            :datetime
#  is_optimized          :boolean          default(false)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class Route < ApplicationRecord
  # Associations
  belongs_to :match

  # Validations
  validates :origin_latitude, :origin_longitude, presence: true
  validates :destination_latitude, :destination_longitude, presence: true
  validates :distance_miles, numericality: { greater_than: 0 }, allow_blank: true
  validates :estimated_duration, numericality: { greater_than: 0 }, allow_blank: true

  # Enums
  enum optimization_type: {
    fastest: 'fastest',
    shortest: 'shortest',
    most_fuel_efficient: 'most_fuel_efficient',
    avoid_traffic: 'avoid_traffic',
    truck_optimized: 'truck_optimized'
  }

  enum traffic_conditions: {
    light: 'light',
    moderate: 'moderate',
    heavy: 'heavy',
    severe: 'severe',
    unknown: 'unknown'
  }

  # Scopes
  scope :optimized, -> { where(is_optimized: true) }
  scope :current, -> { where('expires_at > ?', Time.current) }
  scope :by_optimization, ->(type) { where(optimization_type: type) }

  # Callbacks
  before_save :calculate_total_cost
  before_save :set_expiration

  def origin_coordinates
    [origin_latitude, origin_longitude]
  end

  def destination_coordinates
    [destination_latitude, destination_longitude]
  end

  def waypoints_list
    return [] unless waypoints.present?
    
    begin
      JSON.parse(waypoints)
    rescue JSON::ParserError
      []
    end
  end

  def instructions_list
    return [] unless route_instructions.present?
    
    begin
      JSON.parse(route_instructions)
    rescue JSON::ParserError
      []
    end
  end

  def vehicle_restrictions_list
    return {} unless vehicle_restrictions.present?
    
    begin
      JSON.parse(vehicle_restrictions)
    rescue JSON::ParserError
      {}
    end
  end

  def estimated_duration_hours
    return nil unless estimated_duration.present?
    (estimated_duration / 60.0).round(2)
  end

  def estimated_arrival_time
    return nil unless estimated_duration.present?
    Time.current + estimated_duration.minutes
  end

  def cost_per_mile
    return 0 unless distance_miles.present? && distance_miles > 0 && total_cost.present?
    total_cost / distance_miles
  end

  def is_expired?
    expires_at.present? && expires_at < Time.current
  end

  def is_current?
    !is_expired?
  end

  def fuel_efficiency_score
    return nil unless distance_miles.present? && fuel_cost.present? && distance_miles > 0
    
    # Lower cost per mile = higher efficiency score
    cost_per_mile = fuel_cost / distance_miles
    baseline_cost = 0.65  # Baseline fuel cost per mile
    
    return 100 if cost_per_mile <= baseline_cost * 0.8
    return 0 if cost_per_mile >= baseline_cost * 1.2
    
    # Scale between 0-100 based on cost efficiency
    ((baseline_cost * 1.2 - cost_per_mile) / (baseline_cost * 0.4) * 100).round
  end

  def traffic_delay_minutes
    return 0 unless traffic_conditions.present? && estimated_duration.present?
    
    base_duration = distance_miles.present? ? (distance_miles / 55.0 * 60) : estimated_duration
    
    case traffic_conditions
    when 'light'
      0
    when 'moderate'
      (estimated_duration - base_duration) * 0.1
    when 'heavy'
      (estimated_duration - base_duration) * 0.2
    when 'severe'
      (estimated_duration - base_duration) * 0.3
    else
      0
    end
  end

  def estimated_fuel_gallons
    return nil unless distance_miles.present?
    
    # Assume average truck fuel efficiency of 6 MPG
    mpg = match.load.vehicle&.fuel_efficiency || 6.0
    distance_miles / mpg
  end

  def environmental_impact_score
    gallons = estimated_fuel_gallons
    return nil unless gallons.present?
    
    # CO2 emissions: approximately 22.4 lbs CO2 per gallon of diesel
    co2_pounds = gallons * 22.4
    
    # Score based on efficiency (lower emissions = higher score)
    baseline_emissions = distance_miles * 3.73  # Baseline: 22.4 lbs / 6 MPG
    
    return 100 if co2_pounds <= baseline_emissions * 0.8
    return 0 if co2_pounds >= baseline_emissions * 1.2
    
    ((baseline_emissions * 1.2 - co2_pounds) / (baseline_emissions * 0.4) * 100).round
  end

  def route_quality_score
    score = 0
    total_factors = 0
    
    # Distance efficiency (compared to straight-line distance)
    if distance_miles.present?
      straight_line = Geocoder::Calculations.distance_between(
        origin_coordinates, destination_coordinates
      )
      if straight_line > 0
        efficiency_ratio = straight_line / distance_miles
        score += efficiency_ratio * 30
        total_factors += 30
      end
    end
    
    # Traffic factor
    if traffic_conditions.present?
      traffic_score = case traffic_conditions
                     when 'light' then 25
                     when 'moderate' then 20
                     when 'heavy' then 10
                     when 'severe' then 5
                     else 15
                     end
      score += traffic_score
      total_factors += 25
    end
    
    # Cost efficiency
    if fuel_efficiency_score.present?
      score += fuel_efficiency_score * 0.25
      total_factors += 25
    end
    
    # Duration reasonableness
    if estimated_duration.present? && distance_miles.present?
      expected_duration = distance_miles / 55.0 * 60  # 55 mph average
      if estimated_duration <= expected_duration * 1.2
        score += 20
      elsif estimated_duration <= expected_duration * 1.5
        score += 10
      end
      total_factors += 20
    end
    
    total_factors > 0 ? (score / total_factors * 100).round : 0
  end

  def self.calculate_route(origin_coords, destination_coords, options = {})
    # This would integrate with Google Maps or other routing service
    # For now, return a basic calculation
    distance = Geocoder::Calculations.distance_between(origin_coords, destination_coords)
    duration = (distance / 55.0 * 60).round  # Assume 55 mph average speed
    
    {
      distance_miles: distance.round(2),
      estimated_duration: duration,
      route_geometry: nil,
      waypoints: [],
      route_instructions: [],
      traffic_conditions: 'unknown'
    }
  end

  def refresh_route_data!
    return false if is_expired?
    
    new_data = self.class.calculate_route(
      origin_coordinates,
      destination_coordinates,
      {
        optimization_type: optimization_type,
        avoid_highways: avoid_highways,
        avoid_tolls: avoid_tolls,
        vehicle_restrictions: vehicle_restrictions_list
      }
    )
    
    update!(
      distance_miles: new_data[:distance_miles],
      estimated_duration: new_data[:estimated_duration],
      route_geometry: new_data[:route_geometry],
      waypoints: new_data[:waypoints].to_json,
      route_instructions: new_data[:route_instructions].to_json,
      traffic_conditions: new_data[:traffic_conditions],
      calculated_at: Time.current
    )
  end

  private

  def calculate_total_cost
    costs = []
    costs << fuel_cost if fuel_cost.present?
    costs << toll_cost if toll_cost.present?
    
    self.total_cost = costs.sum if costs.any?
  end

  def set_expiration
    # Route data expires after 2 hours by default
    self.expires_at = (calculated_at || Time.current) + 2.hours
  end
end