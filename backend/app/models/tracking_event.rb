# == Schema Information
#
# Table name: tracking_events
#
#  id           :bigint           not null, primary key
#  shipment_id  :bigint           not null
#  event_type   :string           not null
#  status       :string           not null
#  location     :string
#  latitude     :decimal(10, 6)
#  longitude    :decimal(10, 6)
#  description  :text
#  notes        :text
#  occurred_at  :datetime         not null
#  reported_by  :string
#  source       :string           default("manual")
#  is_milestone :boolean          default(false)
#  temperature  :decimal(5, 2)    # For temperature-controlled shipments
#  humidity     :decimal(5, 2)    # For humidity monitoring
#  vehicle_id   :bigint
#  driver_id    :bigint
#  external_id  :string           # For third-party tracking integration
#  metadata     :text             # JSON for additional data
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class TrackingEvent < ApplicationRecord
  # Associations
  belongs_to :shipment
  belongs_to :vehicle, optional: true
  belongs_to :driver, optional: true

  # Validations
  validates :event_type, :status, :occurred_at, presence: true
  validates :latitude, :longitude, numericality: true, allow_blank: true
  validates :temperature, :humidity, numericality: true, allow_blank: true

  # Enums
  enum event_type: {
    pickup_scheduled: 'pickup_scheduled',
    pickup_arrived: 'pickup_arrived',
    pickup_started: 'pickup_started',
    pickup_completed: 'pickup_completed',
    in_transit: 'in_transit',
    delivery_scheduled: 'delivery_scheduled',
    delivery_arrived: 'delivery_arrived',
    delivery_started: 'delivery_started',
    delivery_completed: 'delivery_completed',
    delay: 'delay',
    breakdown: 'breakdown',
    accident: 'accident',
    fuel_stop: 'fuel_stop',
    rest_break: 'rest_break',
    border_crossing: 'border_crossing',
    inspection: 'inspection',
    temperature_alert: 'temperature_alert',
    security_alert: 'security_alert',
    location_update: 'location_update',
    status_change: 'status_change',
    exception: 'exception'
  }

  enum status: {
    scheduled: 'scheduled',
    in_progress: 'in_progress',
    completed: 'completed',
    delayed: 'delayed',
    cancelled: 'cancelled',
    exception: 'exception',
    on_hold: 'on_hold'
  }

  enum source: {
    manual: 'manual',
    gps: 'gps',
    eld: 'eld',          # Electronic Logging Device
    api: 'api',
    mobile_app: 'mobile_app',
    telematics: 'telematics',
    driver_input: 'driver_input',
    automated: 'automated'
  }

  # Scopes
  scope :milestones, -> { where(is_milestone: true) }
  scope :recent, -> { where('occurred_at >= ?', 24.hours.ago) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :chronological, -> { order(:occurred_at) }
  scope :reverse_chronological, -> { order(occurred_at: :desc) }
  scope :with_location, -> { where.not(latitude: nil, longitude: nil) }
  scope :alerts, -> { where(event_type: ['temperature_alert', 'security_alert', 'breakdown', 'accident', 'delay']) }

  # Callbacks
  before_save :set_milestone_flag
  after_create :update_shipment_status
  after_create :send_notifications

  def coordinates
    return nil unless latitude.present? && longitude.present?
    [latitude, longitude]
  end

  def display_location
    return location if location.present?
    return "#{latitude}, #{longitude}" if coordinates.present?
    'Unknown location'
  end

  def is_alert?
    ['temperature_alert', 'security_alert', 'breakdown', 'accident', 'delay', 'exception'].include?(event_type)
  end

  def is_positive_milestone?
    ['pickup_completed', 'delivery_completed', 'in_transit'].include?(event_type) && completed?
  end

  def is_negative_event?
    ['breakdown', 'accident', 'delay', 'exception'].include?(event_type) || exception?
  end

  def severity_level
    case event_type
    when 'accident', 'breakdown'
      'critical'
    when 'delay', 'temperature_alert', 'security_alert'
      'warning'
    when 'exception'
      'error'
    when 'pickup_completed', 'delivery_completed'
      'success'
    else
      'info'
    end
  end

  def time_since_occurred
    return nil unless occurred_at.present?
    
    diff = Time.current - occurred_at
    
    case diff
    when 0..3600
      "#{(diff / 60).to_i} minutes ago"
    when 3600..86400
      "#{(diff / 3600).to_i} hours ago"
    else
      "#{(diff / 86400).to_i} days ago"
    end
  end

  def estimated_delay_minutes
    return nil unless delay? && metadata.present?
    
    begin
      data = JSON.parse(metadata)
      data['delay_minutes']&.to_i
    rescue JSON::ParserError
      nil
    end
  end

  def temperature_in_fahrenheit
    return nil unless temperature.present?
    temperature
  end

  def temperature_in_celsius
    return nil unless temperature.present?
    (temperature - 32) * 5.0 / 9.0
  end

  def is_temperature_violation?
    return false unless temperature_alert? && shipment.load.temperature_controlled?
    
    min_temp = shipment.load.temperature_min
    max_temp = shipment.load.temperature_max
    
    return false unless min_temp.present? && max_temp.present? && temperature.present?
    
    temperature < min_temp || temperature > max_temp
  end

  def distance_from_previous_event
    previous_event = shipment.tracking_events
                           .where('occurred_at < ?', occurred_at)
                           .with_location
                           .order(:occurred_at)
                           .last
    
    return nil unless previous_event&.coordinates.present? && coordinates.present?
    
    Geocoder::Calculations.distance_between(previous_event.coordinates, coordinates)
  end

  def metadata_hash
    return {} unless metadata.present?
    
    begin
      JSON.parse(metadata)
    rescue JSON::ParserError
      {}
    end
  end

  def set_metadata(data)
    self.metadata = data.to_json
  end

  def formatted_event_description
    base_description = description.presence || default_event_description
    
    case event_type
    when 'temperature_alert'
      "#{base_description} (Temperature: #{temperature}°F)"
    when 'delay'
      delay_info = estimated_delay_minutes ? " (#{estimated_delay_minutes} minutes)" : ""
      "#{base_description}#{delay_info}"
    when 'fuel_stop', 'rest_break'
      duration = metadata_hash['duration_minutes']
      duration_info = duration ? " (#{duration} minutes)" : ""
      "#{base_description}#{duration_info}"
    else
      base_description
    end
  end

  def self.create_milestone(shipment, event_type, status, options = {})
    create!(
      shipment: shipment,
      event_type: event_type,
      status: status,
      occurred_at: options[:occurred_at] || Time.current,
      location: options[:location],
      latitude: options[:latitude],
      longitude: options[:longitude],
      description: options[:description],
      notes: options[:notes],
      is_milestone: true,
      source: options[:source] || 'automated',
      reported_by: options[:reported_by],
      vehicle: options[:vehicle],
      driver: options[:driver]
    )
  end

  def self.latest_location_for_shipment(shipment)
    shipment.tracking_events
           .with_location
           .order(:occurred_at)
           .last
  end

  private

  def default_event_description
    case event_type
    when 'pickup_scheduled'
      'Pickup has been scheduled'
    when 'pickup_arrived'
      'Driver has arrived at pickup location'
    when 'pickup_started'
      'Pickup process has started'
    when 'pickup_completed'
      'Pickup has been completed'
    when 'in_transit'
      'Shipment is in transit'
    when 'delivery_scheduled'
      'Delivery has been scheduled'
    when 'delivery_arrived'
      'Driver has arrived at delivery location'
    when 'delivery_started'
      'Delivery process has started'
    when 'delivery_completed'
      'Delivery has been completed'
    when 'delay'
      'Shipment has been delayed'
    when 'breakdown'
      'Vehicle breakdown reported'
    when 'accident'
      'Accident reported'
    when 'fuel_stop'
      'Vehicle stopped for fuel'
    when 'rest_break'
      'Driver taking required rest break'
    when 'temperature_alert'
      'Temperature monitoring alert'
    when 'security_alert'
      'Security alert triggered'
    else
      event_type.humanize
    end
  end

  def set_milestone_flag
    milestone_events = [
      'pickup_completed', 'delivery_completed', 'in_transit',
      'breakdown', 'accident', 'delay'
    ]
    
    self.is_milestone = milestone_events.include?(event_type)
  end

  def update_shipment_status
    return unless is_milestone?
    
    case event_type
    when 'pickup_completed'
      shipment.update(status: 'picked_up') if shipment.may_pickup?
    when 'in_transit'
      shipment.update(status: 'in_transit') if shipment.may_start_transit?
    when 'delivery_completed'
      shipment.update(status: 'delivered') if shipment.may_deliver?
    end
  end

  def send_notifications
    return unless is_alert? || is_milestone?
    
    # This would trigger notification jobs
    # NotifyShipmentUpdateJob.perform_later(shipment.id, id) if is_milestone?
    # NotifyShipmentAlertJob.perform_later(shipment.id, id) if is_alert?
  end
end