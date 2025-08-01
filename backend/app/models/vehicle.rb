# == Schema Information
#
# Table name: vehicles
#
#  id                    :bigint           not null, primary key
#  carrier_id            :bigint           not null
#  driver_id             :bigint
#  vehicle_number        :string           not null
#  vin                   :string           not null
#  make                  :string           not null
#  model                 :string           not null
#  year                  :integer          not null
#  equipment_type        :string           not null
#  capacity_weight       :decimal(8, 2)    # in pounds
#  capacity_volume       :decimal(8, 2)    # in cubic feet
#  length                :decimal(6, 2)    # in feet
#  width                 :decimal(6, 2)    # in feet
#  height                :decimal(6, 2)    # in feet
#  fuel_type             :string           default("diesel")
#  mpg                   :decimal(4, 2)    # miles per gallon
#  status                :string           default("active"), not null
#  current_location_lat  :decimal(10, 6)
#  current_location_lng  :decimal(10, 6)
#  last_location_update  :datetime
#  maintenance_due_date  :date
#  inspection_due_date   :date
#  registration_expiry   :date
#  insurance_expiry      :date
#  is_temperature_controlled :boolean      default(false)
#  is_hazmat_certified   :boolean          default(false)
#  is_team_capable       :boolean          default(false)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class Vehicle < ApplicationRecord
  # Associations
  belongs_to :carrier
  belongs_to :driver, optional: true
  has_many :shipments, dependent: :nullify
  has_many :vehicle_maintenance_records, dependent: :destroy

  # Validations
  validates :vehicle_number, presence: true, uniqueness: { scope: :carrier_id }
  validates :vin, presence: true, uniqueness: true, length: { is: 17 }
  validates :make, :model, presence: true
  validates :year, numericality: { 
    greater_than: 1990, 
    less_than_or_equal_to: Date.current.year + 1 
  }
  validates :capacity_weight, numericality: { greater_than: 0, less_than_or_equal_to: 80000 }
  validates :capacity_volume, numericality: { greater_than: 0 }, allow_nil: true
  validates :length, :width, :height, numericality: { greater_than: 0 }, allow_nil: true
  validates :mpg, numericality: { greater_than: 0, less_than_or_equal_to: 15 }, allow_nil: true
  validates :equipment_type, presence: true

  # Enums
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

  enum status: {
    active: 'active',
    inactive: 'inactive',
    maintenance: 'maintenance',
    out_of_service: 'out_of_service'
  }

  enum fuel_type: {
    diesel: 'diesel',
    gasoline: 'gasoline',
    electric: 'electric',
    hybrid: 'hybrid',
    natural_gas: 'natural_gas'
  }

  # Scopes
  scope :available, -> { where(status: 'active').where(driver: nil) }
  scope :assigned, -> { where.not(driver: nil) }
  scope :by_equipment_type, ->(type) { where(equipment_type: type) }
  scope :temperature_controlled, -> { where(is_temperature_controlled: true) }
  scope :hazmat_certified, -> { where(is_hazmat_certified: true) }
  scope :team_capable, -> { where(is_team_capable: true) }
  scope :maintenance_due, -> { where('maintenance_due_date <= ?', Date.current) }
  scope :inspection_due, -> { where('inspection_due_date <= ?', Date.current) }

  # Callbacks
  before_validation :normalize_vin
  before_save :update_location_timestamp

  def display_name
    "#{year} #{make} #{model} (#{vehicle_number})"
  end

  def current_location
    return nil unless current_location_lat.present? && current_location_lng.present?
    [current_location_lat, current_location_lng]
  end

  def is_available?
    active? && driver.nil? && !maintenance_due? && !inspection_due?
  end

  def is_assigned?
    driver.present?
  end

  def assign_driver(new_driver)
    return false unless new_driver.is_a?(Driver)
    return false unless new_driver.carrier == carrier
    return false unless new_driver.available?
    
    transaction do
      self.driver = new_driver
      new_driver.update!(vehicle: self, status: 'assigned')
      save!
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def unassign_driver
    return true unless driver.present?
    
    transaction do
      old_driver = driver
      self.driver = nil
      old_driver.update!(vehicle: nil, status: 'available')
      save!
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def update_location(latitude, longitude)
    self.current_location_lat = latitude
    self.current_location_lng = longitude
    self.last_location_update = Time.current
    save!
  end

  def distance_from(location)
    return nil unless current_location.present? && location.present?
    
    Geocoder::Calculations.distance_between(current_location, location)
  end

  def fuel_efficiency
    mpg || estimated_mpg_by_equipment_type
  end

  def estimated_mpg_by_equipment_type
    case equipment_type
    when 'dry_van', 'refrigerated'
      6.5
    when 'flatbed', 'step_deck'
      6.0
    when 'lowboy', 'specialized'
      5.5
    when 'tanker'
      5.8
    when 'container'
      6.2
    else
      6.0
    end
  end

  def fuel_cost_per_mile(fuel_price_per_gallon = 4.50)
    fuel_price_per_gallon / fuel_efficiency
  end

  def operating_cost_per_mile
    # Rough estimate including fuel, maintenance, insurance, etc.
    fuel_cost = fuel_cost_per_mile
    maintenance_cost = 0.15  # $0.15 per mile
    insurance_cost = 0.05    # $0.05 per mile
    depreciation_cost = 0.20 # $0.20 per mile
    
    fuel_cost + maintenance_cost + insurance_cost + depreciation_cost
  end

  def maintenance_due?
    maintenance_due_date.present? && maintenance_due_date <= Date.current
  end

  def inspection_due?
    inspection_due_date.present? && inspection_due_date <= Date.current
  end

  def registration_expired?
    registration_expiry.present? && registration_expiry < Date.current
  end

  def insurance_expired?
    insurance_expiry.present? && insurance_expiry < Date.current
  end

  def compliance_status
    issues = []
    issues << "Maintenance Due" if maintenance_due?
    issues << "Inspection Due" if inspection_due?
    issues << "Registration Expired" if registration_expired?
    issues << "Insurance Expired" if insurance_expired?
    
    issues.empty? ? "Compliant" : issues.join(", ")
  end

  def is_compliant?
    !maintenance_due? && !inspection_due? && !registration_expired? && !insurance_expired?
  end

  def can_handle_load?(load)
    return false unless active? && is_compliant?
    return false unless equipment_type == load.equipment_type
    return false if load.weight.present? && load.weight > capacity_weight
    return false if load.is_hazmat? && !is_hazmat_certified?
    return false if load.temperature_controlled? && !is_temperature_controlled?
    return false if load.is_team_driver? && !is_team_capable?
    
    # Check dimensions if specified
    if load.dimensions.present? && length.present? && width.present? && height.present?
      load_dimensions = parse_dimensions(load.dimensions)
      return false if load_dimensions && !can_fit_dimensions?(load_dimensions)
    end
    
    true
  end

  def utilization_percentage(period_days = 30)
    return 0 unless driver.present?
    
    total_days = period_days
    active_days = shipments.where(
      'created_at >= ? AND status IN (?)', 
      period_days.days.ago, 
      ['in_transit', 'delivered']
    ).count
    
    (active_days.to_f / total_days * 100).round(2)
  end

  def maintenance_cost_per_mile
    return 0 if vehicle_maintenance_records.empty?
    
    total_cost = vehicle_maintenance_records.sum(:cost)
    total_miles = calculate_total_miles_driven
    
    return 0 if total_miles.zero?
    
    total_cost / total_miles
  end

  private

  def normalize_vin
    self.vin = vin.upcase.strip if vin.present?
  end

  def update_location_timestamp
    self.last_location_update = Time.current if current_location_lat_changed? || current_location_lng_changed?
  end

  def parse_dimensions(dimensions_string)
    # Expected format: "Length x Width x Height" (e.g., "53 x 8.5 x 13.5")
    parts = dimensions_string.split('x').map(&:strip).map(&:to_f)
    return nil unless parts.length == 3 && parts.all? { |p| p > 0 }
    
    { length: parts[0], width: parts[1], height: parts[2] }
  end

  def can_fit_dimensions?(load_dimensions)
    load_dimensions[:length] <= length &&
    load_dimensions[:width] <= width &&
    load_dimensions[:height] <= height
  end

  def calculate_total_miles_driven
    # This would typically track odometer readings or GPS data
    # For now, we'll estimate based on shipments
    shipments.where(status: 'delivered').sum do |shipment|
      shipment.load&.distance_miles || 0
    end
  end
end