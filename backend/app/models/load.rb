# == Schema Information
#
# Table name: loads
#
#  id                    :bigint           not null, primary key
#  shipper_id            :bigint           not null
#  reference_number      :string           not null
#  status                :string           default("posted"), not null
#  load_type             :string           not null
#  commodity             :string           not null
#  description           :text
#  weight                :decimal(8, 2)    # in pounds
#  dimensions            :string           # LxWxH format
#  special_instructions  :text
#  pickup_address_line1  :string           not null
#  pickup_address_line2  :string
#  pickup_city           :string           not null
#  pickup_state          :string           not null
#  pickup_postal_code    :string           not null
#  pickup_country        :string           default("US")
#  pickup_latitude       :decimal(10, 6)
#  pickup_longitude      :decimal(10, 6)
#  pickup_date           :date             not null
#  pickup_time_window_start :time
#  pickup_time_window_end   :time
#  pickup_contact_name   :string
#  pickup_contact_phone  :string
#  delivery_address_line1 :string          not null
#  delivery_address_line2 :string
#  delivery_city         :string           not null
#  delivery_state        :string           not null
#  delivery_postal_code  :string           not null
#  delivery_country      :string           default("US")
#  delivery_latitude     :decimal(10, 6)
#  delivery_longitude    :decimal(10, 6)
#  delivery_date         :date             not null
#  delivery_time_window_start :time
#  delivery_time_window_end   :time
#  delivery_contact_name :string
#  delivery_contact_phone :string
#  equipment_type        :string           not null
#  rate                  :decimal(10, 2)   not null
#  rate_type             :string           default("flat"), not null
#  mileage               :decimal(8, 2)
#  estimated_distance    :decimal(8, 2)
#  fuel_surcharge        :decimal(6, 2)    default(0.0)
#  accessorial_charges   :decimal(8, 2)    default(0.0)
#  total_rate            :decimal(10, 2)
#  currency              :string           default("USD")
#  payment_terms         :integer          default(30)
#  requires_tracking     :boolean          default(true)
#  requires_signature    :boolean          default(false)
#  is_hazmat             :boolean          default(false)
#  is_expedited          :boolean          default(false)
#  is_team_driver        :boolean          default(false)
#  temperature_controlled :boolean         default(false)
#  temperature_min       :integer
#  temperature_max       :integer
#  posted_at             :datetime
#  expires_at            :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class Load < ApplicationRecord
  include AASM

  # Associations
  belongs_to :shipper
  has_one :user, through: :shipper
  has_many :load_requirements, dependent: :destroy
  has_many :cargo_details, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :carriers, through: :matches
  has_one :active_match, -> { where(status: 'accepted') }, class_name: 'Match'
  has_one :assigned_carrier, through: :active_match, source: :carrier
  has_one :shipment, dependent: :destroy
  has_many :tracking_events, through: :shipment
  has_many :invoices, dependent: :destroy

  # Validations
  validates :reference_number, presence: true, uniqueness: { scope: :shipper_id }
  validates :commodity, presence: true
  validates :weight, numericality: { greater_than: 0, less_than_or_equal_to: 80000 } # DOT limit
  validates :pickup_date, :delivery_date, presence: true
  validates :pickup_city, :pickup_state, :pickup_postal_code, presence: true
  validates :delivery_city, :delivery_state, :delivery_postal_code, presence: true
  validates :equipment_type, presence: true
  validates :rate, numericality: { greater_than: 0 }
  validates :payment_terms, numericality: { greater_than: 0, less_than_or_equal_to: 120 }
  validate :delivery_after_pickup
  validate :valid_time_windows
  validate :valid_temperature_range

  # Geocoding
  geocoded_by :pickup_full_address, latitude: :pickup_latitude, longitude: :pickup_longitude
  geocoded_by :delivery_full_address, latitude: :delivery_latitude, longitude: :delivery_longitude

  # Enums
  enum load_type: {
    full_truckload: 'full_truckload',
    less_than_truckload: 'less_than_truckload',
    partial: 'partial',
    intermodal: 'intermodal'
  }

  enum equipment_type: {
    dry_van: 'dry_van',
    refrigerated: 'refrigerated',
    flatbed: 'flatbed',
    step_deck: 'step_deck',
    lowboy: 'lowboy',
    tanker: 'tanker',
    container: 'container',
    car_carrier: 'car_carrier',
    specialized: 'specialized'
  }

  enum rate_type: {
    flat: 'flat',
    per_mile: 'per_mile',
    per_pound: 'per_pound',
    hourly: 'hourly'
  }

  enum currency: {
    USD: 'USD',
    CAD: 'CAD',
    MXN: 'MXN'
  }

  # State Machine
  aasm column: :status do
    state :posted, initial: true
    state :matched
    state :accepted
    state :picked_up
    state :in_transit
    state :delivered
    state :cancelled
    state :expired

    event :match_with_carrier do
      transitions from: :posted, to: :matched
    end

    event :accept_by_carrier do
      transitions from: [:posted, :matched], to: :accepted
    end

    event :pickup do
      transitions from: :accepted, to: :picked_up
    end

    event :start_transit do
      transitions from: :picked_up, to: :in_transit
    end

    event :deliver do
      transitions from: :in_transit, to: :delivered
    end

    event :cancel do
      transitions from: [:posted, :matched, :accepted], to: :cancelled
    end

    event :expire do
      transitions from: :posted, to: :expired
    end
  end

  # Scopes
  scope :active, -> { where(status: ['posted', 'matched', 'accepted', 'picked_up', 'in_transit']) }
  scope :available, -> { where(status: 'posted').where('expires_at > ?', Time.current) }
  scope :by_equipment, ->(equipment) { where(equipment_type: equipment) }
  scope :by_origin_state, ->(state) { where(pickup_state: state) }
  scope :by_destination_state, ->(state) { where(delivery_state: state) }
  scope :by_date_range, ->(start_date, end_date) { where(pickup_date: start_date..end_date) }
  scope :expedited, -> { where(is_expedited: true) }
  scope :hazmat, -> { where(is_hazmat: true) }
  scope :temperature_controlled, -> { where(temperature_controlled: true) }

  # Callbacks
  before_validation :generate_reference_number, on: :create
  before_save :calculate_total_rate
  before_save :set_posted_at
  after_validation :geocode_addresses, if: :address_changed?

  def pickup_full_address
    [pickup_address_line1, pickup_address_line2, pickup_city, pickup_state, pickup_postal_code, pickup_country].compact.join(', ')
  end

  def delivery_full_address
    [delivery_address_line1, delivery_address_line2, delivery_city, delivery_state, delivery_postal_code, delivery_country].compact.join(', ')
  end

  def distance_miles
    return estimated_distance if estimated_distance.present?
    return nil unless pickup_coordinates.present? && delivery_coordinates.present?
    
    Geocoder::Calculations.distance_between(pickup_coordinates, delivery_coordinates)
  end

  def pickup_coordinates
    return nil unless pickup_latitude.present? && pickup_longitude.present?
    [pickup_latitude, pickup_longitude]
  end

  def delivery_coordinates
    return nil unless delivery_latitude.present? && delivery_longitude.present?
    [delivery_latitude, delivery_longitude]
  end

  def rate_per_mile
    return 0 if distance_miles.blank? || distance_miles.zero?
    total_rate / distance_miles
  end

  def days_in_transit
    return nil unless pickup_date.present? && delivery_date.present?
    (delivery_date - pickup_date).to_i
  end

  def time_to_pickup
    return nil unless pickup_date.present?
    (pickup_date - Date.current).to_i
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def available_for_matching?
    posted? && !expired? && time_to_pickup >= 0
  end

  def can_be_matched_with?(carrier)
    return false unless available_for_matching?
    return false unless carrier.active? && carrier.verified?
    return false unless carrier.can_handle_equipment?(equipment_type)
    return false unless carrier.serves_area?(pickup_state)
    return false if is_hazmat? && !carrier.hazmat_certified?
    
    true
  end

  def matching_score_for(carrier)
    return 0 unless can_be_matched_with?(carrier)
    
    score = 0
    
    # Distance factor (closer = higher score)
    if carrier.current_location.present? && pickup_coordinates.present?
      distance = Geocoder::Calculations.distance_between(carrier.current_location, pickup_coordinates)
      score += [100 - distance, 0].max
    end
    
    # Equipment match
    score += 50 if carrier.can_handle_equipment?(equipment_type)
    
    # Service area match
    score += 30 if carrier.serves_area?(pickup_state)
    score += 20 if carrier.serves_area?(delivery_state)
    
    # Carrier rating
    score += carrier.average_rating * 10
    
    # On-time performance
    score += carrier.on_time_percentage * 0.5
    
    score
  end

  def estimated_delivery_time
    return nil unless pickup_date.present?
    
    # Estimate based on distance (assuming 500 miles per day average)
    travel_days = distance_miles.present? ? (distance_miles / 500.0).ceil : 1
    pickup_date + travel_days.days
  end

  def special_requirements
    requirements = []
    requirements << "Hazmat" if is_hazmat?
    requirements << "Expedited" if is_expedited?
    requirements << "Team Driver Required" if is_team_driver?
    requirements << "Temperature Controlled" if temperature_controlled?
    requirements << "Tracking Required" if requires_tracking?
    requirements << "Signature Required" if requires_signature?
    requirements
  end

  def temperature_range
    return nil unless temperature_controlled? && temperature_min.present? && temperature_max.present?
    "#{temperature_min}°F - #{temperature_max}°F"
  end

  def pickup_time_window
    return nil unless pickup_time_window_start.present? && pickup_time_window_end.present?
    "#{pickup_time_window_start.strftime('%I:%M %p')} - #{pickup_time_window_end.strftime('%I:%M %p')}"
  end

  def delivery_time_window
    return nil unless delivery_time_window_start.present? && delivery_time_window_end.present?
    "#{delivery_time_window_start.strftime('%I:%M %p')} - #{delivery_time_window_end.strftime('%I:%M %p')}"
  end

  private

  def generate_reference_number
    return if reference_number.present?
    
    prefix = shipper.company_name.first(3).upcase
    date_part = Date.current.strftime('%Y%m%d')
    sequence = shipper.loads.where('created_at >= ?', Date.current.beginning_of_day).count + 1
    
    self.reference_number = "#{prefix}-#{date_part}-#{sequence.to_s.rjust(4, '0')}"
  end

  def calculate_total_rate
    self.total_rate = rate + fuel_surcharge + accessorial_charges
  end

  def set_posted_at
    self.posted_at = Time.current if posted_at.blank? && status == 'posted'
  end

  def address_changed?
    pickup_address_line1_changed? || pickup_city_changed? || pickup_state_changed? ||
    delivery_address_line1_changed? || delivery_city_changed? || delivery_state_changed?
  end

  def geocode_addresses
    # Geocode pickup address
    pickup_result = Geocoder.search(pickup_full_address).first
    if pickup_result
      self.pickup_latitude = pickup_result.latitude
      self.pickup_longitude = pickup_result.longitude
    end
    
    # Geocode delivery address
    delivery_result = Geocoder.search(delivery_full_address).first
    if delivery_result
      self.delivery_latitude = delivery_result.latitude
      self.delivery_longitude = delivery_result.longitude
    end
    
    # Calculate estimated distance
    if pickup_coordinates.present? && delivery_coordinates.present?
      self.estimated_distance = Geocoder::Calculations.distance_between(pickup_coordinates, delivery_coordinates)
    end
  end

  def delivery_after_pickup
    return unless pickup_date.present? && delivery_date.present?
    
    errors.add(:delivery_date, "must be after pickup date") if delivery_date < pickup_date
  end

  def valid_time_windows
    if pickup_time_window_start.present? && pickup_time_window_end.present?
      errors.add(:pickup_time_window_end, "must be after start time") if pickup_time_window_end <= pickup_time_window_start
    end
    
    if delivery_time_window_start.present? && delivery_time_window_end.present?
      errors.add(:delivery_time_window_end, "must be after start time") if delivery_time_window_end <= delivery_time_window_start
    end
  end

  def valid_temperature_range
    return unless temperature_controlled?
    
    if temperature_min.present? && temperature_max.present?
      errors.add(:temperature_max, "must be greater than minimum temperature") if temperature_max <= temperature_min
    end
  end
end