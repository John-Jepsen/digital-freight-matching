# Business Logic & Domain Models

## Core Business Entities

### User Management System

#### User Types & Roles
```ruby
# Base user with role-based access
class User < ApplicationRecord
  has_one :shipper_profile, dependent: :destroy
  has_one :carrier_profile, dependent: :destroy
  
  enum user_type: { 
    shipper: 'shipper',    # Companies needing freight transportation
    carrier: 'carrier',    # Trucking companies and owner-operators
    driver: 'driver',      # Individual drivers
    admin: 'admin'         # Platform administrators
  }
  
  # Business validation rules
  validates :email, presence: true, uniqueness: true
  validates :user_type, presence: true
  validates :phone_number, presence: true, format: { with: /\A[\+]?[1-9][\d]{0,15}\z/ }
end
```

#### Shipper Profiles
```ruby
# Companies posting freight loads
class ShipperProfile < ApplicationRecord
  belongs_to :user
  has_many :loads, dependent: :destroy
  
  # Business attributes
  validates :company_name, presence: true
  validates :business_type, inclusion: { in: %w[manufacturer distributor retailer logistics] }
  
  # Credit and payment terms
  enum payment_terms: { 
    net_30: 'net_30', 
    net_15: 'net_15', 
    quick_pay: 'quick_pay',
    cash_on_delivery: 'cash_on_delivery'
  }
  
  # Business logic
  def credit_eligible?
    credit_rating >= 3.0
  end
  
  def preferred_carriers
    # Logic to find carriers based on historical performance
    Carrier.joins(:matches).where(matches: { status: 'completed' })
  end
end
```

#### Carrier Profiles
```ruby
# Trucking companies and owner-operators
class CarrierProfile < ApplicationRecord
  belongs_to :user
  has_many :drivers, dependent: :destroy
  has_many :vehicles, dependent: :destroy
  has_many :matches, dependent: :destroy
  
  # DOT and MC number validation (critical for compliance)
  validates :dot_number, presence: true, uniqueness: true
  validates :mc_number, presence: true, uniqueness: true
  validate :valid_dot_number_format
  
  enum status: { active: 'active', inactive: 'inactive', suspended: 'suspended' }
  
  # Business logic
  def available_capacity
    vehicles.active.sum(:capacity_weight)
  end
  
  def current_utilization
    active_shipments.sum(:weight) / available_capacity.to_f
  end
  
  def performance_score
    # Algorithm combining on-time delivery, damage rate, customer satisfaction
    base_score = rating * 20
    on_time_bonus = (on_time_delivery_rate - 0.95) * 100 if on_time_delivery_rate > 0.95
    base_score + (on_time_bonus || 0)
  end
end
```

### Freight Load Management

#### Core Load Entity
```ruby
class Load < ApplicationRecord
  include AASM
  
  belongs_to :shipper, class_name: 'ShipperProfile'
  has_many :matches, dependent: :destroy
  has_many :load_requirements, dependent: :destroy
  has_many :cargo_details, dependent: :destroy
  has_one :shipment, dependent: :destroy
  
  # State machine for load lifecycle
  aasm column: :status do
    state :posted, initial: true
    state :matched, :accepted, :in_transit, :delivered, :cancelled
    
    event :match_with_carrier do
      transitions from: :posted, to: :matched
      after do
        update_match_timestamp
      end
    end
    
    event :accept_by_carrier do
      transitions from: :matched, to: :accepted
      after do
        create_shipment_record
        notify_shipper_of_acceptance
      end
    end
    
    event :start_transit do
      transitions from: :accepted, to: :in_transit
      after do
        start_tracking
      end
    end
    
    event :complete_delivery do
      transitions from: :in_transit, to: :delivered
      after do
        finalize_payment
        update_carrier_metrics
      end
    end
  end
  
  # Business validations
  validates :pickup_location, :delivery_location, presence: true
  validates :pickup_datetime, :delivery_datetime, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validate :pickup_before_delivery
  validate :reasonable_price_range
  
  # Geographic calculations
  geocoded_by :pickup_location, latitude: :pickup_lat, longitude: :pickup_lng
  geocoded_by :delivery_location, latitude: :delivery_lat, longitude: :delivery_lng
  after_validation :geocode_locations
  
  # Business logic methods
  def distance_miles
    return 0 unless pickup_lat && pickup_lng && delivery_lat && delivery_lng
    
    Geocoder::Calculations.distance_between(
      [pickup_lat, pickup_lng], 
      [delivery_lat, delivery_lng]
    )
  end
  
  def estimated_transit_time
    # Base calculation: 50 mph average + loading/unloading time
    base_hours = distance_miles / 50.0
    loading_time = 2.0  # 2 hours for pickup/delivery
    
    base_hours + loading_time
  end
  
  def price_per_mile
    return 0 if distance_miles.zero?
    price / distance_miles
  end
  
  def market_rate_comparison
    # Compare against industry averages ($1.855 per mile baseline)
    industry_average = 1.855
    current_rate = price_per_mile
    
    {
      current_rate: current_rate,
      industry_average: industry_average,
      variance_percentage: ((current_rate - industry_average) / industry_average * 100).round(2)
    }
  end
  
  # Scopes for business queries
  scope :available, -> { where(status: 'posted') }
  scope :high_priority, -> { where('pickup_datetime <= ?', 24.hours.from_now) }
  scope :near_location, ->(lat, lng, radius_miles) {
    where(
      "ST_DWithin(ST_Point(pickup_lng, pickup_lat)::geography, 
                  ST_Point(?, ?)::geography, ?)",
      lng, lat, radius_miles * 1609.34  # Convert miles to meters
    )
  }
  scope :price_range, ->(min, max) { where(price: min..max) }
  scope :by_equipment_type, ->(equipment_type) {
    joins(:load_requirements).where(load_requirements: { equipment_type: equipment_type })
  }
end
```

### Matching Algorithm System

#### Core Matching Logic
```ruby
class MatchingAlgorithmService
  SCORING_WEIGHTS = {
    distance: 0.3,        # Proximity to pickup location
    equipment: 0.2,       # Equipment compatibility
    rating: 0.2,          # Carrier performance rating
    price: 0.15,          # Price competitiveness
    availability: 0.15    # Carrier availability window
  }.freeze
  
  def initialize(load, options = {})
    @load = load
    @max_distance = options[:max_distance] || 100
    @min_rating = options[:min_rating] || 0
    @max_results = options[:max_results] || 10
  end
  
  def call
    eligible_carriers = find_eligible_carriers
    scored_matches = calculate_match_scores(eligible_carriers)
    create_match_records(scored_matches.take(@max_results))
    
    ServiceResult.success(data: scored_matches)
  rescue => e
    ServiceResult.failure(error: e.message)
  end
  
  private
  
  def find_eligible_carriers
    CarrierProfile.joins(:vehicles)
                  .includes(:user, :vehicles)
                  .active
                  .near(@load.pickup_location, @max_distance)
                  .where(rating: @min_rating..)
                  .where.not(id: already_matched_carrier_ids)
  end
  
  def calculate_match_scores(carriers)
    carriers.map do |carrier|
      score_components = {
        distance: distance_score(carrier),
        equipment: equipment_score(carrier),
        rating: rating_score(carrier),
        price: price_score(carrier),
        availability: availability_score(carrier)
      }
      
      total_score = score_components.sum { |component, score| 
        score * SCORING_WEIGHTS[component] 
      }
      
      {
        carrier: carrier,
        score: total_score.round(2),
        components: score_components,
        estimated_pickup_time: calculate_pickup_time(carrier),
        recommended_price: calculate_recommended_price(carrier)
      }
    end.sort_by { |match| -match[:score] }
  end
  
  def distance_score(carrier)
    distance = Geocoder::Calculations.distance_between(
      [@load.pickup_lat, @load.pickup_lng],
      [carrier.latitude, carrier.longitude]
    )
    
    # Score: 100 for 0 miles, decreasing to 0 at max_distance
    [100 - (distance / @max_distance * 100), 0].max
  end
  
  def equipment_score(carrier)
    required_equipment = @load.load_requirements.pluck(:equipment_type)
    available_equipment = carrier.vehicles.active.pluck(:vehicle_type)
    
    return 100 if required_equipment.empty?
    
    matches = (required_equipment & available_equipment).size
    matches.to_f / required_equipment.size * 100
  end
  
  def rating_score(carrier)
    (carrier.rating / 5.0) * 100
  end
  
  def price_score(carrier)
    # Score based on historical pricing efficiency
    avg_price_per_mile = carrier.average_price_per_mile || 1.855
    market_rate = @load.price_per_mile
    
    # Optimal when carrier's rate aligns with market rate
    variance = (market_rate - avg_price_per_mile).abs / avg_price_per_mile
    [100 - (variance * 100), 0].max
  end
  
  def availability_score(carrier)
    current_utilization = carrier.current_utilization
    
    # Score: 100 for 0% utilization, decreasing as utilization increases
    [100 - (current_utilization * 100), 0].max
  end
end
```

### Route Optimization System

#### Route Calculation Service
```ruby
class RouteCalculationService
  include GoogleMapsClient
  
  def initialize(origin, destination, waypoints = [])
    @origin = origin
    @destination = destination
    @waypoints = waypoints
  end
  
  def call
    route_data = fetch_route_from_google_maps
    
    {
      distance_miles: route_data[:distance] * 0.000621371,  # meters to miles
      duration_hours: route_data[:duration] / 3600.0,       # seconds to hours
      fuel_cost: calculate_fuel_cost(route_data[:distance]),
      toll_cost: estimate_toll_cost(route_data),
      total_cost: calculate_total_operating_cost(route_data),
      coordinates: route_data[:polyline],
      traffic_data: route_data[:traffic]
    }
  rescue GoogleMaps::Error => e
    ServiceResult.failure(error: "Route calculation failed: #{e.message}")
  end
  
  private
  
  def calculate_fuel_cost(distance_meters)
    # Based on industry averages: 6.5 MPG, $3.50/gallon
    miles = distance_meters * 0.000621371
    gallons_needed = miles / 6.5
    gallons_needed * 3.50
  end
  
  def calculate_total_operating_cost(route_data)
    miles = route_data[:distance] * 0.000621371
    
    # Industry standard operating cost: $1.855 per mile
    base_cost = miles * 1.855
    
    # Add fuel and tolls
    fuel_cost = calculate_fuel_cost(route_data[:distance])
    toll_cost = estimate_toll_cost(route_data)
    
    base_cost + fuel_cost + toll_cost
  end
end
```

### Real-time Tracking System

#### Shipment Tracking
```ruby
class Shipment < ApplicationRecord
  include AASM
  
  belongs_to :match
  has_many :tracking_events, dependent: :destroy
  
  aasm column: :status do
    state :pending, initial: true
    state :in_transit, :delivered, :exception
    
    event :start_journey do
      transitions from: :pending, to: :in_transit
      after do
        create_tracking_event('pickup_confirmed', 'Load picked up')
        notify_shipper_of_pickup
      end
    end
    
    event :complete_delivery do
      transitions from: :in_transit, to: :delivered
      after do
        create_tracking_event('delivered', 'Load delivered successfully')
        finalize_shipment
      end
    end
    
    event :report_exception do
      transitions from: [:pending, :in_transit], to: :exception
      after do |exception_details|
        create_tracking_event('exception', exception_details)
        notify_stakeholders_of_exception
      end
    end
  end
  
  # Business logic
  def progress_percentage
    return 0 unless in_transit?
    
    total_distance = match.load.distance_miles
    return 0 if total_distance.zero?
    
    if current_latitude && current_longitude
      remaining_distance = Geocoder::Calculations.distance_between(
        [current_latitude, current_longitude],
        [match.load.delivery_lat, match.load.delivery_lng]
      )
      
      ((total_distance - remaining_distance) / total_distance * 100).round
    else
      0
    end
  end
  
  def estimated_arrival
    return nil unless in_transit? && current_latitude && current_longitude
    
    remaining_distance = distance_to_destination
    avg_speed = 50  # mph
    hours_remaining = remaining_distance / avg_speed
    
    Time.current + hours_remaining.hours
  end
  
  def on_time_status
    return :unknown unless pickup_confirmed_at && estimated_arrival
    
    scheduled_delivery = match.load.delivery_datetime
    
    if estimated_arrival <= scheduled_delivery
      :on_time
    elsif estimated_arrival <= scheduled_delivery + 2.hours
      :minor_delay
    else
      :significant_delay
    end
  end
end
```

## Financial & Pricing Models

### Dynamic Pricing Algorithm
```ruby
class PricingCalculationService
  # Market-based pricing factors
  COST_FACTORS = {
    base_rate_per_mile: 1.855,    # Industry average
    fuel_surcharge_rate: 0.15,    # 15% of base rate
    equipment_premiums: {
      dry_van: 0.0,
      refrigerated: 0.25,         # 25% premium
      flatbed: 0.15,              # 15% premium
      hazmat: 0.50               # 50% premium for hazardous materials
    },
    seasonal_multipliers: {
      peak_season: 1.20,          # December-January
      normal_season: 1.0,
      slow_season: 0.85           # March-May
    }
  }.freeze
  
  def initialize(load, market_conditions = {})
    @load = load
    @market_conditions = market_conditions
  end
  
  def calculate_recommended_price
    base_cost = calculate_base_transportation_cost
    equipment_premium = calculate_equipment_premium
    market_adjustment = calculate_market_adjustment
    seasonal_factor = calculate_seasonal_factor
    
    total_cost = base_cost * (1 + equipment_premium + market_adjustment) * seasonal_factor
    
    {
      base_cost: base_cost.round(2),
      equipment_premium_rate: equipment_premium,
      market_adjustment_rate: market_adjustment,
      seasonal_factor: seasonal_factor,
      recommended_price: total_cost.round(2),
      margin_percentage: ((total_cost - base_cost) / base_cost * 100).round(2)
    }
  end
  
  private
  
  def calculate_base_transportation_cost
    distance = @load.distance_miles
    base_rate = COST_FACTORS[:base_rate_per_mile]
    fuel_surcharge = base_rate * COST_FACTORS[:fuel_surcharge_rate]
    
    distance * (base_rate + fuel_surcharge)
  end
  
  def calculate_equipment_premium
    equipment_types = @load.load_requirements.pluck(:equipment_type)
    return 0 if equipment_types.empty?
    
    equipment_types.map { |type| 
      COST_FACTORS[:equipment_premiums][type.to_sym] || 0 
    }.max
  end
  
  def calculate_market_adjustment
    # Supply/demand ratio affects pricing
    supply_demand_ratio = @market_conditions[:supply_demand_ratio] || 1.0
    
    case supply_demand_ratio
    when 0..0.8   then 0.20    # High demand, low supply: 20% premium
    when 0.8..1.2 then 0.0     # Balanced market
    when 1.2..2.0 then -0.15   # Oversupply: 15% discount
    else              -0.25    # Severe oversupply: 25% discount
    end
  end
  
  def calculate_seasonal_factor
    current_month = Date.current.month
    
    case current_month
    when 12, 1, 2  # Peak season (holidays, winter)
      COST_FACTORS[:seasonal_multipliers][:peak_season]
    when 3, 4, 5   # Slow season
      COST_FACTORS[:seasonal_multipliers][:slow_season]
    else           # Normal season
      COST_FACTORS[:seasonal_multipliers][:normal_season]
    end
  end
end
```

## Performance Metrics & Analytics

### Carrier Performance Scoring
```ruby
module CarrierMetrics
  def update_performance_metrics(shipment)
    calculate_on_time_delivery_rate
    calculate_damage_rate
    calculate_customer_satisfaction
    update_overall_rating
  end
  
  def calculate_on_time_delivery_rate
    total_deliveries = shipments.delivered.count
    return 0 if total_deliveries.zero?
    
    on_time_deliveries = shipments.delivered.joins(:match).where(
      'shipments.actual_delivery <= matches.scheduled_delivery + INTERVAL \'2 hours\''
    ).count
    
    (on_time_deliveries.to_f / total_deliveries * 100).round(2)
  end
  
  def calculate_efficiency_score
    # Deadhead miles reduction compared to industry average
    total_miles = routes.sum(:distance_miles)
    loaded_miles = routes.joins(:shipment).sum(:distance_miles)
    
    return 0 if total_miles.zero?
    
    utilization_rate = (loaded_miles / total_miles * 100).round(2)
    industry_average = 70.0  # 30% deadhead industry average
    
    [utilization_rate - industry_average, 0].max
  end
end
```

*This business logic foundation ensures the platform operates according to real-world freight industry requirements and performance standards.*
