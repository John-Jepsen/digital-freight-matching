# == Schema Information
#
# Table name: matches
#
#  id                    :bigint           not null, primary key
#  load_id               :bigint           not null
#  carrier_id            :bigint           not null
#  status                :string           default("pending"), not null
#  match_score           :decimal(5, 2)    default(0.0)
#  rate_offered          :decimal(10, 2)
#  rate_accepted         :decimal(10, 2)
#  estimated_pickup_time :datetime
#  estimated_delivery_time :datetime
#  distance_to_pickup    :decimal(8, 2)
#  fuel_cost_estimate    :decimal(8, 2)
#  margin_estimate       :decimal(8, 2)
#  notes                 :text
#  matched_at            :datetime
#  accepted_at           :datetime
#  rejected_at           :datetime
#  expired_at            :datetime
#  rejection_reason      :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class Match < ApplicationRecord
  include AASM

  # Associations
  belongs_to :load
  belongs_to :carrier
  has_one :shipper, through: :load
  has_one :shipment, dependent: :destroy

  # Validations
  validates :match_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :rate_offered, numericality: { greater_than: 0 }, allow_nil: true
  validates :rate_accepted, numericality: { greater_than: 0 }, allow_nil: true
  validates :status, presence: true
  validate :load_must_be_available, on: :create
  validate :carrier_must_be_eligible
  validate :unique_active_match_per_load

  # Enums
  enum status: {
    pending: 'pending',
    offered: 'offered',
    accepted: 'accepted',
    rejected: 'rejected',
    expired: 'expired',
    cancelled: 'cancelled'
  }

  enum rejection_reason: {
    rate_too_low: 'rate_too_low',
    timing_conflict: 'timing_conflict',
    equipment_unavailable: 'equipment_unavailable',
    location_too_far: 'location_too_far',
    shipper_requirements: 'shipper_requirements',
    carrier_policy: 'carrier_policy',
    other: 'other'
  }

  # State Machine
  aasm column: :status do
    state :pending, initial: true
    state :offered
    state :accepted
    state :rejected
    state :expired
    state :cancelled

    event :make_offer do
      transitions from: :pending, to: :offered
      after do
        self.matched_at = Time.current
        create_shipment_if_needed
      end
    end

    event :accept_offer do
      transitions from: [:pending, :offered], to: :accepted
      after do
        self.accepted_at = Time.current
        self.rate_accepted = rate_offered || load.total_rate
        load.accept_by_carrier! if load.may_accept_by_carrier?
        create_shipment_if_needed
        cancel_other_matches
      end
    end

    event :reject_offer do
      transitions from: [:pending, :offered], to: :rejected
      after do
        self.rejected_at = Time.current
      end
    end

    event :expire do
      transitions from: [:pending, :offered], to: :expired
      after do
        self.expired_at = Time.current
      end
    end

    event :cancel do
      transitions from: [:pending, :offered, :accepted], to: :cancelled
    end
  end

  # Scopes
  scope :active, -> { where(status: ['pending', 'offered', 'accepted']) }
  scope :by_score, -> { order(match_score: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_carrier, ->(carrier) { where(carrier: carrier) }
  scope :for_load, ->(load) { where(load: load) }

  # Callbacks
  before_create :calculate_match_score
  before_create :calculate_estimates
  after_create :notify_carrier
  after_update :notify_parties, if: :status_changed?

  def self.create_for_load(load, options = {})
    return [] unless load.available_for_matching?

    # Find eligible carriers
    eligible_carriers = find_eligible_carriers(load, options)
    
    matches = []
    eligible_carriers.each do |carrier|
      match = new(
        load: load,
        carrier: carrier,
        status: 'pending'
      )
      
      if match.valid?
        matches << match
        match.save!
      end
    end
    
    matches
  end

  def self.find_eligible_carriers(load, options = {})
    carriers = Carrier.active.verified
    
    # Equipment compatibility
    carriers = carriers.with_equipment(load.equipment_type)
    
    # Service area
    carriers = carriers.serving_area(load.pickup_state)
    
    # Distance filter (if specified)
    if options[:max_distance_to_pickup].present?
      # This would require more complex distance calculation
      # For now, we'll implement basic filtering
    end
    
    # Capacity check
    if load.weight.present?
      # Filter carriers with sufficient capacity
      carriers = carriers.joins(:vehicles)
                        .where('vehicles.capacity_weight >= ?', load.weight)
                        .distinct
    end
    
    # Safety rating filter
    carriers = carriers.where.not(safety_rating: 'unsatisfactory')
    
    # Insurance verification
    carriers = carriers.insurance_valid
    
    # Exclude carriers that already have a match for this load
    existing_carrier_ids = Match.where(load: load).pluck(:carrier_id)
    carriers = carriers.where.not(id: existing_carrier_ids)
    
    # Sort by preference/score
    carriers.limit(options[:limit] || 10)
  end

  def profit_margin_percentage
    return 0 if rate_accepted.blank? || rate_accepted.zero?
    return 0 if estimated_total_cost.blank? || estimated_total_cost.zero?
    
    profit = rate_accepted - estimated_total_cost
    (profit / rate_accepted * 100).round(2)
  end

  def estimated_total_cost
    return 0 if fuel_cost_estimate.blank?
    
    # Basic cost calculation (this could be more sophisticated)
    driver_cost = distance_miles * 0.50  # $0.50 per mile for driver
    maintenance_cost = distance_miles * 0.15  # $0.15 per mile for maintenance
    insurance_cost = rate_accepted.to_f * 0.02  # 2% of rate for insurance
    
    fuel_cost_estimate + driver_cost + maintenance_cost + insurance_cost
  end

  def distance_miles
    load.distance_miles || 0
  end

  def estimated_travel_time_hours
    return 0 if distance_miles.zero?
    
    # Assume average speed of 55 mph including stops
    distance_miles / 55.0
  end

  def deadhead_miles
    distance_to_pickup || 0
  end

  def total_miles
    distance_miles + deadhead_miles
  end

  def rate_per_mile
    return 0 if distance_miles.zero? || rate_accepted.blank?
    
    rate_accepted / distance_miles
  end

  def is_profitable?
    profit_margin_percentage > 0
  end

  def time_to_respond
    return nil if matched_at.blank?
    return nil if accepted_at.blank? && rejected_at.blank?
    
    response_time = accepted_at || rejected_at
    ((response_time - matched_at) / 1.hour).round(2)
  end

  def carrier_distance_score
    return 0 if distance_to_pickup.blank?
    
    # Score decreases as distance increases (max 50 points)
    [50 - distance_to_pickup, 0].max
  end

  def rate_competitiveness_score
    return 0 if rate_offered.blank?
    
    # Compare with load's asking rate (max 30 points)
    rate_ratio = rate_offered / load.total_rate
    [rate_ratio * 30, 30].min
  end

  def carrier_reliability_score
    # Based on carrier's ratings and performance (max 20 points)
    carrier.average_rating * 4  # Convert 5-star rating to 20-point scale
  end

  def estimated_revenue_per_mile
    return 0 if total_miles.zero? || rate_accepted.blank?
    
    rate_accepted / total_miles
  end

  private

  def calculate_match_score
    self.match_score = load.matching_score_for(carrier)
  end

  def calculate_estimates
    # Calculate distance to pickup
    if carrier.current_location.present? && load.pickup_coordinates.present?
      self.distance_to_pickup = Geocoder::Calculations.distance_between(
        carrier.current_location, 
        load.pickup_coordinates
      )
    end
    
    # Estimate fuel cost (based on current fuel prices and truck efficiency)
    if total_miles > 0
      fuel_price_per_gallon = 4.50  # This could come from a fuel price API
      miles_per_gallon = 6.5        # Average for semi trucks
      self.fuel_cost_estimate = (total_miles / miles_per_gallon) * fuel_price_per_gallon
    end
    
    # Calculate estimated margin
    if load.total_rate.present? && estimated_total_cost > 0
      self.margin_estimate = load.total_rate - estimated_total_cost
    end
    
    # Set estimated times
    if load.pickup_date.present?
      travel_time_to_pickup = deadhead_miles / 55.0  # hours
      self.estimated_pickup_time = Time.zone.parse("#{load.pickup_date} 08:00") + travel_time_to_pickup.hours
    end
    
    if estimated_pickup_time.present?
      self.estimated_delivery_time = estimated_pickup_time + estimated_travel_time_hours.hours
    end
  end

  def create_shipment_if_needed
    return if shipment.present?
    return unless accepted?
    
    Shipment.create!(
      load: load,
      carrier: carrier,
      match: self,
      status: 'pending_pickup',
      scheduled_pickup_date: load.pickup_date,
      scheduled_delivery_date: load.delivery_date
    )
  end

  def cancel_other_matches
    load.matches.where.not(id: id).where(status: ['pending', 'offered']).each do |match|
      match.cancel!
    end
  end

  def notify_carrier
    # This would integrate with notification system
    # For now, we'll just log the event
    Rails.logger.info "New match created for carrier #{carrier.id} and load #{load.id}"
  end

  def notify_parties
    # Notify relevant parties about status changes
    case status
    when 'accepted'
      Rails.logger.info "Match accepted: Carrier #{carrier.id} accepted load #{load.id}"
    when 'rejected'
      Rails.logger.info "Match rejected: Carrier #{carrier.id} rejected load #{load.id} - #{rejection_reason}"
    end
  end

  def load_must_be_available
    errors.add(:load, "must be available for matching") unless load&.available_for_matching?
  end

  def carrier_must_be_eligible
    return unless carrier.present? && load.present?
    
    errors.add(:carrier, "is not eligible for this load") unless load.can_be_matched_with?(carrier)
  end

  def unique_active_match_per_load
    return unless load.present? && carrier.present?
    
    existing_match = load.matches.active.where(carrier: carrier).where.not(id: id).first
    errors.add(:base, "An active match already exists for this load and carrier") if existing_match.present?
  end
end