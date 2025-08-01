# == Schema Information
#
# Table name: shipments
#
#  id                      :bigint           not null, primary key
#  load_id                 :bigint           not null
#  carrier_id              :bigint           not null
#  match_id                :bigint           not null
#  status                  :string           default("pending_pickup"), not null
#  scheduled_pickup_date   :date             not null
#  scheduled_delivery_date :date             not null
#  actual_pickup_date      :date
#  actual_delivery_date    :date
#  delivered_on_time       :boolean          default(true)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
class Shipment < ApplicationRecord
  include AASM

  # Associations
  belongs_to :load
  belongs_to :carrier
  belongs_to :match
  has_one :shipper, through: :load
  has_many :tracking_events, dependent: :destroy

  # Validations
  validates :status, presence: true
  validates :scheduled_pickup_date, :scheduled_delivery_date, presence: true
  validate :delivery_after_pickup

  # State Machine
  aasm column: :status do
    state :pending_pickup, initial: true
    state :picked_up
    state :in_transit
    state :delivered
    state :exception

    event :pickup do
      transitions from: :pending_pickup, to: :picked_up
      after do
        self.actual_pickup_date = Date.current
        load.pickup! if load.may_pickup?
      end
    end

    event :start_transit do
      transitions from: :picked_up, to: :in_transit
      after do
        load.start_transit! if load.may_start_transit?
      end
    end

    event :deliver do
      transitions from: :in_transit, to: :delivered
      after do
        self.actual_delivery_date = Date.current
        self.delivered_on_time = actual_delivery_date <= scheduled_delivery_date
        load.deliver! if load.may_deliver?
      end
    end

    event :report_exception do
      transitions from: [:pending_pickup, :picked_up, :in_transit], to: :exception
    end
  end

  # Scopes
  scope :active, -> { where(status: ['pending_pickup', 'picked_up', 'in_transit']) }
  scope :completed, -> { where(status: 'delivered') }
  scope :on_time, -> { where(delivered_on_time: true) }
  scope :late, -> { where(delivered_on_time: false) }

  def is_active?
    ['pending_pickup', 'picked_up', 'in_transit'].include?(status)
  end

  def is_on_time?
    return nil unless delivered?
    delivered_on_time
  end

  def days_in_transit
    return nil unless actual_pickup_date.present?
    
    end_date = actual_delivery_date || Date.current
    (end_date - actual_pickup_date).to_i
  end

  def estimated_delivery_date
    return scheduled_delivery_date unless actual_pickup_date.present?
    
    # Recalculate based on actual pickup date
    transit_days = (scheduled_delivery_date - scheduled_pickup_date).to_i
    actual_pickup_date + transit_days.days
  end

  private

  def delivery_after_pickup
    return unless scheduled_pickup_date.present? && scheduled_delivery_date.present?
    
    errors.add(:scheduled_delivery_date, "must be after pickup date") if scheduled_delivery_date < scheduled_pickup_date
  end
end