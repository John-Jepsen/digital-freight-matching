# == Schema Information
#
# Table name: locations
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  address_line1 :string           not null
#  address_line2 :string
#  city          :string           not null
#  state         :string           not null
#  postal_code   :string           not null
#  country       :string           default("US")
#  latitude      :decimal(10, 6)
#  longitude     :decimal(10, 6)
#  location_type :string           not null
#  contact_name  :string
#  contact_phone :string
#  contact_email :string
#  hours_of_operation :text
#  special_instructions :text
#  facility_type :string
#  dock_type     :string
#  equipment_available :text
#  is_active     :boolean          default(true)
#  timezone      :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class Location < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :address_line1, :city, :state, :postal_code, presence: true
  validates :location_type, presence: true
  validates :latitude, :longitude, numericality: true, allow_blank: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Geocoding
  geocoded_by :full_address, latitude: :latitude, longitude: :longitude

  # Enums
  enum location_type: {
    warehouse: 'warehouse',
    distribution_center: 'distribution_center',
    manufacturing_plant: 'manufacturing_plant',
    port: 'port',
    rail_yard: 'rail_yard',
    truck_stop: 'truck_stop',
    customer_site: 'customer_site',
    drop_yard: 'drop_yard',
    cross_dock: 'cross_dock',
    retail_store: 'retail_store',
    construction_site: 'construction_site',
    other: 'other'
  }

  enum facility_type: {
    indoor: 'indoor',
    outdoor: 'outdoor',
    covered: 'covered',
    climate_controlled: 'climate_controlled',
    refrigerated: 'refrigerated',
    hazmat_approved: 'hazmat_approved'
  }

  enum dock_type: {
    ground_level: 'ground_level',
    dock_high: 'dock_high',
    rail_dock: 'rail_dock',
    ramp: 'ramp',
    no_dock: 'no_dock'
  }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_state, ->(state) { where(state: state) }
  scope :by_type, ->(type) { where(location_type: type) }
  scope :near, ->(lat, lng, distance_miles = 50) {
    where(
      "ST_DWithin(ST_MakePoint(longitude, latitude)::geography, ST_MakePoint(?, ?)::geography, ?)",
      lng, lat, distance_miles * 1609.34
    )
  }

  # Callbacks
  after_validation :geocode_address, if: :address_changed?

  def full_address
    [address_line1, address_line2, city, state, postal_code, country].compact.join(', ')
  end

  def coordinates
    return nil unless latitude.present? && longitude.present?
    [latitude, longitude]
  end

  def display_address
    parts = [address_line1]
    parts << address_line2 if address_line2.present?
    parts << "#{city}, #{state} #{postal_code}"
    parts.join("\n")
  end

  def distance_from(other_location)
    return nil unless coordinates.present? && other_location.present?
    
    other_coords = case other_location
                  when Location
                    other_location.coordinates
                  when Array
                    other_location
                  else
                    nil
                  end
    
    return nil unless other_coords.present?
    
    Geocoder::Calculations.distance_between(coordinates, other_coords)
  end

  def operating_hours_for_day(day)
    return 'Not specified' unless hours_of_operation.present?
    
    begin
      hours_data = JSON.parse(hours_of_operation)
      day_key = day.downcase
      hours_data[day_key] || 'Closed'
    rescue JSON::ParserError
      hours_of_operation
    end
  end

  def current_operating_hours
    operating_hours_for_day(Date.current.strftime('%A'))
  end

  def is_currently_open?
    return false unless timezone.present? && hours_of_operation.present?
    
    begin
      hours_data = JSON.parse(hours_of_operation)
      current_day = Time.current.in_time_zone(timezone).strftime('%A').downcase
      today_hours = hours_data[current_day]
      
      return false if today_hours.blank? || today_hours.downcase == 'closed'
      
      # Parse hours format like "08:00-17:00"
      open_time, close_time = today_hours.split('-')
      return false unless open_time && close_time
      
      current_time = Time.current.in_time_zone(timezone)
      open_hour, open_min = open_time.split(':').map(&:to_i)
      close_hour, close_min = close_time.split(':').map(&:to_i)
      
      open_today = current_time.beginning_of_day + open_hour.hours + open_min.minutes
      close_today = current_time.beginning_of_day + close_hour.hours + close_min.minutes
      
      current_time >= open_today && current_time <= close_today
    rescue
      false
    end
  end

  def equipment_list
    return [] unless equipment_available.present?
    
    begin
      JSON.parse(equipment_available)
    rescue JSON::ParserError
      equipment_available.split(',').map(&:strip)
    end
  end

  def has_equipment?(equipment_type)
    equipment_list.include?(equipment_type)
  end

  def can_handle_load?(load)
    return false unless is_active?
    
    # Check facility requirements
    if load.is_hazmat? && facility_type != 'hazmat_approved'
      return false
    end
    
    if load.temperature_controlled? && !['climate_controlled', 'refrigerated'].include?(facility_type)
      return false
    end
    
    # Check dock compatibility
    if load.equipment_type == 'dry_van' && dock_type == 'no_dock'
      return false
    end
    
    true
  end

  def self.search_by_address(query)
    where(
      "name ILIKE ? OR address_line1 ILIKE ? OR city ILIKE ? OR state ILIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
    )
  end

  def self.common_timezones
    {
      'Eastern Time' => 'America/New_York',
      'Central Time' => 'America/Chicago',
      'Mountain Time' => 'America/Denver',
      'Pacific Time' => 'America/Los_Angeles',
      'Alaska Time' => 'America/Anchorage',
      'Hawaii Time' => 'Pacific/Honolulu'
    }
  end

  private

  def address_changed?
    address_line1_changed? || address_line2_changed? || city_changed? || 
    state_changed? || postal_code_changed? || country_changed?
  end

  def geocode_address
    return unless address_changed?
    
    result = Geocoder.search(full_address).first
    if result
      self.latitude = result.latitude
      self.longitude = result.longitude
      self.timezone ||= result.timezone if result.respond_to?(:timezone)
    end
  end
end