# == Schema Information
#
# Table name: drivers
#
#  id                    :bigint           not null, primary key
#  user_id               :bigint
#  carrier_id            :bigint           not null
#  vehicle_id            :bigint
#  driver_number         :string           not null
#  first_name            :string           not null
#  last_name             :string           not null
#  phone                 :string
#  email                 :string
#  license_number        :string           not null
#  license_state         :string           not null
#  license_expiry        :date             not null
#  cdl_class             :string           not null
#  cdl_endorsements      :string           # Comma-separated endorsements
#  medical_cert_expiry   :date             not null
#  status                :string           default("available"), not null
#  hire_date             :date
#  termination_date      :date
#  is_team_driver        :boolean          default(false)
#  is_hazmat_certified   :boolean          default(false)
#  is_owner_operator     :boolean          default(false)
#  emergency_contact_name :string
#  emergency_contact_phone :string
#  address_line1         :string
#  address_line2         :string
#  city                  :string
#  state                 :string
#  postal_code           :string
#  country               :string           default("US")
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class Driver < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  belongs_to :carrier
  belongs_to :vehicle, optional: true
  has_many :shipments, dependent: :nullify
  has_many :driver_violations, dependent: :destroy
  has_many :ratings, as: :rateable, dependent: :destroy

  # Validations
  validates :driver_number, presence: true, uniqueness: { scope: :carrier_id }
  validates :first_name, :last_name, presence: true
  validates :license_number, presence: true, uniqueness: { scope: :license_state }
  validates :license_state, presence: true, length: { is: 2 }
  validates :license_expiry, :medical_cert_expiry, presence: true
  validates :cdl_class, presence: true, inclusion: { in: %w[A B C] }
  validates :phone, format: { with: /\A[\+]?[1-9][\d]{0,15}\z/, message: "Invalid phone format" }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :license_not_expired
  validate :medical_cert_not_expired
  validate :termination_date_after_hire_date

  # Enums
  enum status: {
    available: 'available',
    assigned: 'assigned',
    driving: 'driving',
    off_duty: 'off_duty',
    on_break: 'on_break',
    inactive: 'inactive',
    terminated: 'terminated'
  }

  enum cdl_class: {
    A: 'A',
    B: 'B',
    C: 'C'
  }

  # Scopes
  scope :active, -> { where.not(status: ['inactive', 'terminated']) }
  scope :available_for_assignment, -> { where(status: 'available', vehicle: nil) }
  scope :with_endorsement, ->(endorsement) { where('cdl_endorsements ILIKE ?', "%#{endorsement}%") }
  scope :hazmat_certified, -> { where(is_hazmat_certified: true) }
  scope :team_drivers, -> { where(is_team_driver: true) }
  scope :owner_operators, -> { where(is_owner_operator: true) }
  scope :license_expiring_soon, ->(days = 30) { where('license_expiry <= ?', Date.current + days.days) }
  scope :medical_cert_expiring_soon, ->(days = 30) { where('medical_cert_expiry <= ?', Date.current + days.days) }

  # Callbacks
  before_validation :normalize_data
  after_create :create_user_account, if: :should_create_user_account?

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    "#{full_name} (#{driver_number})"
  end

  def endorsement_list
    return [] if cdl_endorsements.blank?
    cdl_endorsements.split(',').map(&:strip).reject(&:blank?)
  end

  def has_endorsement?(endorsement)
    endorsement_list.map(&:upcase).include?(endorsement.upcase)
  end

  def add_endorsement(endorsement)
    current_endorsements = endorsement_list
    return false if current_endorsements.include?(endorsement)
    
    current_endorsements << endorsement
    self.cdl_endorsements = current_endorsements.join(', ')
    save
  end

  def remove_endorsement(endorsement)
    current_endorsements = endorsement_list
    return false unless current_endorsements.include?(endorsement)
    
    current_endorsements.delete(endorsement)
    self.cdl_endorsements = current_endorsements.join(', ')
    save
  end

  def is_available?
    available? && !license_expired? && !medical_cert_expired? && vehicle.nil?
  end

  def is_assigned?
    assigned? && vehicle.present?
  end

  def license_expired?
    license_expiry < Date.current
  end

  def medical_cert_expired?
    medical_cert_expiry < Date.current
  end

  def license_expires_soon?(days = 30)
    license_expiry <= Date.current + days.days
  end

  def medical_cert_expires_soon?(days = 30)
    medical_cert_expiry <= Date.current + days.days
  end

  def compliance_status
    issues = []
    issues << "License Expired" if license_expired?
    issues << "Medical Certificate Expired" if medical_cert_expired?
    issues << "License Expiring Soon" if license_expires_soon? && !license_expired?
    issues << "Medical Cert Expiring Soon" if medical_cert_expires_soon? && !medical_cert_expired?
    
    issues.empty? ? "Compliant" : issues.join(", ")
  end

  def is_compliant?
    !license_expired? && !medical_cert_expired?
  end

  def assign_to_vehicle(new_vehicle)
    return false unless new_vehicle.is_a?(Vehicle)
    return false unless new_vehicle.carrier == carrier
    return false unless new_vehicle.is_available?
    return false unless is_available?
    
    transaction do
      self.vehicle = new_vehicle
      self.status = 'assigned'
      new_vehicle.driver = self
      save!
      new_vehicle.save!
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def unassign_from_vehicle
    return true unless vehicle.present?
    
    transaction do
      old_vehicle = vehicle
      self.vehicle = nil
      self.status = 'available'
      old_vehicle.driver = nil
      save!
      old_vehicle.save!
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def can_drive_equipment?(equipment_type)
    case equipment_type.to_s.downcase
    when 'hazmat', 'tanker'
      is_hazmat_certified? && has_endorsement?('H')
    when 'passenger'
      has_endorsement?('P')
    when 'school_bus'
      has_endorsement?('S')
    when 'double_triple'
      has_endorsement?('T')
    else
      true  # Most equipment types don't require special endorsements
    end
  end

  def can_handle_load?(load)
    return false unless is_compliant? && active?
    return false if load.is_hazmat? && !is_hazmat_certified?
    return false if load.is_team_driver? && !is_team_driver?
    return false unless can_drive_equipment?(load.equipment_type)
    
    true
  end

  def total_miles_driven
    return 0 unless vehicle.present?
    
    # This would typically come from ELD data or odometer readings
    # For now, estimate based on completed shipments
    shipments.joins(:load).where(status: 'delivered').sum do |shipment|
      shipment.load.distance_miles || 0
    end
  end

  def safety_score
    return 100 if driver_violations.empty?
    
    # Calculate score based on violations in the last 2 years
    recent_violations = driver_violations.where('violation_date >= ?', 2.years.ago)
    
    base_score = 100
    recent_violations.each do |violation|
      case violation.severity
      when 'minor'
        base_score -= 5
      when 'major'
        base_score -= 15
      when 'serious'
        base_score -= 25
      end
    end
    
    [base_score, 0].max
  end

  def average_rating
    return 0.0 if ratings.empty?
    ratings.average(:score) || 0.0
  end

  def years_of_experience
    return 0 unless hire_date.present?
    
    end_date = terminated? ? termination_date : Date.current
    ((end_date - hire_date) / 365.0).floor
  end

  def current_location
    vehicle&.current_location
  end

  def hours_of_service_status
    # This would integrate with ELD systems
    # For now, return a simple status
    case status
    when 'driving'
      'On Duty - Driving'
    when 'on_break'
      'Off Duty'
    when 'available', 'assigned'
      'On Duty - Not Driving'
    else
      'Off Duty'
    end
  end

  def available_driving_hours
    # DOT regulations: 11 hours driving after 10 consecutive hours off duty
    # This would integrate with ELD systems for accurate tracking
    # For now, return a simple calculation
    case status
    when 'driving'
      # Assume they've been driving for some time
      rand(6..10)
    when 'available', 'assigned'
      11  # Full hours available
    else
      0
    end
  end

  def next_required_break
    # DOT regulations: 30-minute break after 8 hours of driving
    # This would integrate with ELD systems
    case status
    when 'driving'
      'Break required in 2 hours'
    else
      'No break required'
    end
  end

  def emergency_contact
    return nil unless emergency_contact_name.present? && emergency_contact_phone.present?
    
    {
      name: emergency_contact_name,
      phone: emergency_contact_phone
    }
  end

  def full_address
    [address_line1, address_line2, city, state, postal_code, country].compact.join(', ')
  end

  private

  def normalize_data
    self.first_name = first_name.strip.titleize if first_name.present?
    self.last_name = last_name.strip.titleize if last_name.present?
    self.license_number = license_number.upcase.strip if license_number.present?
    self.license_state = license_state.upcase.strip if license_state.present?
    self.cdl_class = cdl_class.upcase if cdl_class.present?
    self.phone = phone.gsub(/\D/, '') if phone.present?
    self.emergency_contact_phone = emergency_contact_phone.gsub(/\D/, '') if emergency_contact_phone.present?
  end

  def license_not_expired
    return unless license_expiry.present?
    
    errors.add(:license_expiry, "cannot be in the past") if license_expiry < Date.current
  end

  def medical_cert_not_expired
    return unless medical_cert_expiry.present?
    
    errors.add(:medical_cert_expiry, "cannot be in the past") if medical_cert_expiry < Date.current
  end

  def termination_date_after_hire_date
    return unless hire_date.present? && termination_date.present?
    
    errors.add(:termination_date, "must be after hire date") if termination_date < hire_date
  end

  def should_create_user_account?
    email.present? && user.blank?
  end

  def create_user_account
    return if user.present? || email.blank?
    
    new_user = User.create!(
      email: email,
      first_name: first_name,
      last_name: last_name,
      phone: phone,
      user_type: 'driver',
      password: SecureRandom.hex(12)  # Temporary password
    )
    
    self.update_column(:user_id, new_user.id)
  end
end