# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  first_name             :string           not null
#  last_name              :string           not null
#  phone                  :string
#  user_type              :string           not null
#  status                 :string           default("active"), not null
#  confirmed_at           :datetime
#  confirmation_token     :string
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string
#  last_sign_in_ip        :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class User < ApplicationRecord
  # Include default devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable

  # Enums
  enum user_type: {
    shipper: 'shipper',
    carrier: 'carrier',
    driver: 'driver',
    broker: 'broker',
    admin: 'admin'
  }

  enum status: {
    active: 'active',
    inactive: 'inactive',
    suspended: 'suspended',
    pending: 'pending'
  }

  # Validations
  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :phone, format: { with: /\A[\+]?[1-9][\d]{0,15}\z/, message: "Invalid phone format" }, allow_blank: true
  validates :user_type, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }

  # Associations
  has_one :shipper_profile, class_name: 'Shipper', dependent: :destroy
  has_one :carrier_profile, class_name: 'Carrier', dependent: :destroy
  has_one :driver_profile, class_name: 'Driver', dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :ratings_given, class_name: 'Rating', foreign_key: 'rater_id', dependent: :destroy
  has_many :ratings_received, class_name: 'Rating', foreign_key: 'ratee_id', dependent: :destroy

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(user_type: type) }
  scope :confirmed, -> { where.not(confirmed_at: nil) }

  # Callbacks
  before_validation :normalize_email
  after_create :create_profile

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def initials
    "#{first_name&.first}#{last_name&.first}".upcase
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :account_inactive
  end

  def average_rating
    ratings_received.average(:score) || 0.0
  end

  def total_ratings
    ratings_received.count
  end

  def can_access_admin?
    admin?
  end

  def profile
    case user_type
    when 'shipper'
      shipper_profile
    when 'carrier'
      carrier_profile
    when 'driver'
      driver_profile
    else
      nil
    end
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def create_profile
    case user_type
    when 'shipper'
      create_shipper_profile!(company_name: "#{full_name} Shipping")
    when 'carrier'
      create_carrier_profile!(company_name: "#{full_name} Trucking")
    when 'driver'
      create_driver_profile!
    end
  end
end