# == Schema Information
#
# Table name: carriers
#
#  id                    :bigint           not null, primary key
#  user_id               :bigint           not null
#  company_name          :string           not null
#  company_description   :text
#  mc_number             :string           # Motor Carrier Number
#  dot_number            :string           # DOT Number
#  scac_code             :string           # Standard Carrier Alpha Code
#  address_line1         :string
#  address_line2         :string
#  city                  :string
#  state                 :string
#  postal_code           :string
#  country               :string           default("US")
#  latitude              :decimal(10, 6)
#  longitude             :decimal(10, 6)
#  phone                 :string
#  website               :string
#  fleet_size            :integer          default(1)
#  equipment_types       :text             # JSON array of equipment types
#  service_areas         :text             # JSON array of states/regions
#  insurance_amount      :decimal(12, 2)
#  insurance_expiry      :date
#  operating_authority   :string
#  safety_rating         :string           default("satisfactory")
#  is_verified           :boolean          default(false)
#  is_active             :boolean          default(true)
#  preferred_lanes       :text             # JSON array of preferred routes
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class Carrier < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :vehicles, dependent: :destroy
  has_many :drivers, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :loads, through: :matches
  has_many :shipments, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :shipper_carrier_relationships, dependent: :destroy
  has_many :preferred_shippers, through: :shipper_carrier_relationships, source: :shipper

  # Validations
  validates :company_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :mc_number, presence: true, uniqueness: true, format: { with: /\A[A-Z]{0,4}\d{4,7}\z/, message: "Invalid MC number format" }
  validates :dot_number, presence: true, uniqueness: true, format: { with: /\A\d{5,8}\z/, message: "Invalid DOT number format" }
  validates :scac_code, uniqueness: true, format: { with: /\A[A-Z]{4}\z/, message: "SCAC must be 4 uppercase letters" }, allow_blank: true
  validates :fleet_size, numericality: { greater_than: 0, less_than_or_equal_to: 10000 }
  validates :insurance_amount, numericality: { greater_than: 0 }
  validates :insurance_expiry, presence: true
  validates :phone, format: { with: /\A[\+]?[1-9][\d]{0,15}\z/, message: "Invalid phone format" }, allow_blank: true
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "Invalid URL format" }, allow_blank: true
  validates :country, inclusion: { in: %w[US CA MX] }

  # Geocoding
  geocoded_by :full_address
  after_validation :geocode, if: :address_changed?

  # Enums
  enum safety_rating: {
    satisfactory: 'satisfactory',
    conditional: 'conditional',
    unsatisfactory: 'unsatisfactory',
    not_rated: 'not_rated'
  }

  enum operating_authority: {
    interstate: 'interstate',
    intrastate: 'intrastate',
    both: 'both'
  }

  # Scopes
  scope :verified, -> { where(is_verified: true) }
  scope :active, -> { where(is_active: true) }
  scope :by_safety_rating, ->(rating) { where(safety_rating: rating) }
  scope :by_fleet_size, ->(min_size, max_size = nil) { 
    query = where('fleet_size >= ?', min_size)
    query = query.where('fleet_size <= ?', max_size) if max_size
    query
  }
  scope :with_equipment, ->(equipment_type) {
    where("equipment_types::text ILIKE ?", "%#{equipment_type}%")
  }
  scope :serving_area, ->(state_code) {
    where("service_areas::text ILIKE ?", "%#{state_code}%")
  }
  scope :insurance_valid, -> { where('insurance_expiry > ?', Date.current) }

  # Callbacks
  before_save :normalize_data
  before_create :generate_scac_if_needed

  def full_address
    [address_line1, address_line2, city, state, postal_code, country].compact.join(', ')
  end

  def display_name
    company_name
  end

  def equipment_list
    return [] if equipment_types.blank?
    JSON.parse(equipment_types)
  rescue JSON::ParserError
    []
  end

  def service_area_list
    return [] if service_areas.blank?
    JSON.parse(service_areas)
  rescue JSON::ParserError
    []
  end

  def preferred_lane_list
    return [] if preferred_lanes.blank?
    JSON.parse(preferred_lanes)
  rescue JSON::ParserError
    []
  end

  def add_equipment_type(equipment_type)
    current_types = equipment_list
    return false if current_types.include?(equipment_type)
    
    current_types << equipment_type
    self.equipment_types = current_types.to_json
    save
  end

  def remove_equipment_type(equipment_type)
    current_types = equipment_list
    return false unless current_types.include?(equipment_type)
    
    current_types.delete(equipment_type)
    self.equipment_types = current_types.to_json
    save
  end

  def add_service_area(state_code)
    current_areas = service_area_list
    return false if current_areas.include?(state_code)
    
    current_areas << state_code
    self.service_areas = current_areas.to_json
    save
  end

  def insurance_valid?
    insurance_expiry.present? && insurance_expiry > Date.current
  end

  def safety_score
    case safety_rating
    when 'satisfactory' then 100
    when 'conditional' then 70
    when 'unsatisfactory' then 30
    else 50
    end
  end

  def total_completed_loads
    matches.joins(:load).where(loads: { status: 'delivered' }).count
  end

  def on_time_percentage
    completed = total_completed_loads
    return 0 if completed.zero?
    
    on_time = matches.joins(:load).where(
      loads: { status: 'delivered' },
      shipments: { delivered_on_time: true }
    ).count
    
    (on_time.to_f / completed * 100).round(2)
  end

  def average_rating
    user.average_rating
  end

  def current_location
    # This would typically come from the most recent GPS tracking
    # For now, return the carrier's base location
    return nil unless latitude.present? && longitude.present?
    [latitude, longitude]
  end

  def available_capacity
    total_capacity = vehicles.active.sum(:capacity_weight)
    used_capacity = shipments.in_transit.sum(:weight)
    total_capacity - used_capacity
  end

  def distance_from(location)
    return nil unless current_location.present? && location.present?
    
    Geocoder::Calculations.distance_between(current_location, location)
  end

  def can_handle_equipment?(required_equipment)
    return false if required_equipment.blank?
    
    equipment_list.any? { |eq| eq.downcase.include?(required_equipment.downcase) }
  end

  def serves_area?(state_code)
    service_area_list.include?(state_code.upcase)
  end

  private

  def address_changed?
    address_line1_changed? || address_line2_changed? || 
    city_changed? || state_changed? || postal_code_changed? || country_changed?
  end

  def normalize_data
    self.company_name = company_name.strip.titleize if company_name.present?
    self.mc_number = mc_number.upcase.strip if mc_number.present?
    self.dot_number = dot_number.strip if dot_number.present?
    self.scac_code = scac_code.upcase.strip if scac_code.present?
    self.phone = phone.gsub(/\D/, '') if phone.present?
    self.website = "https://#{website}" if website.present? && !website.start_with?('http')
  end

  def generate_scac_if_needed
    return if scac_code.present?
    
    # Generate SCAC from company name or MC number
    base = company_name.present? ? company_name : "MC#{mc_number}"
    self.scac_code = base.gsub(/[^A-Z]/, '')[0,4].ljust(4, 'X')
    
    # Ensure uniqueness
    counter = 1
    original_scac = scac_code
    while Carrier.exists?(scac_code: scac_code)
      self.scac_code = "#{original_scac[0,3]}#{counter}"
      counter += 1
    end
  end
end