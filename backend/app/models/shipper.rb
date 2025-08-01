# == Schema Information
#
# Table name: shippers
#
#  id                    :bigint           not null, primary key
#  user_id               :bigint           not null
#  company_name          :string           not null
#  company_description   :text
#  industry              :string
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
#  tax_id                :string
#  dot_number            :string
#  credit_limit          :decimal(10, 2)   default(0.0)
#  payment_terms         :integer          default(30)
#  preferred_carriers    :text             # JSON array of carrier IDs
#  shipping_volume_monthly :integer        default(0)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class Shipper < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :loads, dependent: :destroy
  has_many :shipments, through: :loads
  has_many :invoices, through: :loads
  has_many :shipper_carrier_relationships, dependent: :destroy
  has_many :preferred_carriers, through: :shipper_carrier_relationships, source: :carrier

  # Validations
  validates :company_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :industry, presence: true
  validates :phone, format: { with: /\A[\+]?[1-9][\d]{0,15}\z/, message: "Invalid phone format" }, allow_blank: true
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "Invalid URL format" }, allow_blank: true
  validates :tax_id, uniqueness: true, allow_blank: true
  validates :dot_number, uniqueness: true, allow_blank: true
  validates :credit_limit, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_terms, numericality: { greater_than: 0, less_than_or_equal_to: 120 }
  validates :shipping_volume_monthly, numericality: { greater_than_or_equal_to: 0 }
  validates :country, inclusion: { in: %w[US CA MX] }

  # Geocoding
  geocoded_by :full_address
  after_validation :geocode, if: :address_changed?

  # Enums
  enum industry: {
    manufacturing: 'manufacturing',
    retail: 'retail',
    agriculture: 'agriculture',
    automotive: 'automotive',
    construction: 'construction',
    food_beverage: 'food_beverage',
    chemicals: 'chemicals',
    textiles: 'textiles',
    electronics: 'electronics',
    other: 'other'
  }

  # Scopes
  scope :verified, -> { where.not(tax_id: nil) }
  scope :by_industry, ->(industry) { where(industry: industry) }
  scope :by_location, ->(state) { where(state: state) }
  scope :high_volume, -> { where('shipping_volume_monthly > ?', 100) }

  # Callbacks
  before_save :normalize_data

  def full_address
    [address_line1, address_line2, city, state, postal_code, country].compact.join(', ')
  end

  def display_name
    company_name
  end

  def verified?
    tax_id.present? && dot_number.present?
  end

  def active_loads_count
    loads.where(status: ['posted', 'matched', 'in_transit']).count
  end

  def completed_loads_count
    loads.where(status: 'delivered').count
  end

  def total_shipped_value
    loads.where(status: 'delivered').sum(:rate)
  end

  def average_rating
    user.average_rating
  end

  def monthly_volume
    shipping_volume_monthly
  end

  def credit_available
    credit_limit - outstanding_balance
  end

  def outstanding_balance
    invoices.where(status: ['pending', 'overdue']).sum(:amount)
  end

  def preferred_carrier_ids
    return [] if preferred_carriers_json.blank?
    JSON.parse(preferred_carriers_json)
  rescue JSON::ParserError
    []
  end

  def add_preferred_carrier(carrier)
    return false unless carrier.is_a?(Carrier)
    
    shipper_carrier_relationships.find_or_create_by(carrier: carrier) do |relationship|
      relationship.relationship_type = 'preferred'
      relationship.created_at = Time.current
    end
  end

  def remove_preferred_carrier(carrier)
    shipper_carrier_relationships.where(carrier: carrier).destroy_all
  end

  def location_coordinates
    return nil unless latitude.present? && longitude.present?
    [latitude, longitude]
  end

  def within_radius(distance_miles)
    return Shipper.all unless location_coordinates.present?
    
    Shipper.near(location_coordinates, distance_miles)
  end

  private

  def address_changed?
    address_line1_changed? || address_line2_changed? || 
    city_changed? || state_changed? || postal_code_changed? || country_changed?
  end

  def normalize_data
    self.company_name = company_name.strip.titleize if company_name.present?
    self.phone = phone.gsub(/\D/, '') if phone.present?
    self.website = "https://#{website}" if website.present? && !website.start_with?('http')
  end
end