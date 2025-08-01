# == Schema Information
#
# Table name: load_requirements
#
#  id          :bigint           not null, primary key
#  load_id     :bigint           not null
#  requirement_type :string      not null
#  requirement_value :text
#  is_mandatory :boolean         default(true), not null
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class LoadRequirement < ApplicationRecord
  # Associations
  belongs_to :load

  # Validations
  validates :requirement_type, presence: true
  validates :requirement_value, presence: true

  # Enums
  enum requirement_type: {
    equipment_certification: 'equipment_certification',
    driver_certification: 'driver_certification',
    cargo_handling: 'cargo_handling',
    special_equipment: 'special_equipment',
    documentation: 'documentation',
    security_clearance: 'security_clearance',
    temperature_control: 'temperature_control',
    weight_capacity: 'weight_capacity',
    insurance_coverage: 'insurance_coverage',
    custom: 'custom'
  }

  # Scopes
  scope :mandatory, -> { where(is_mandatory: true) }
  scope :optional, -> { where(is_mandatory: false) }
  scope :by_type, ->(type) { where(requirement_type: type) }

  def display_name
    requirement_type.humanize
  end

  def formatted_value
    case requirement_type
    when 'weight_capacity'
      "#{requirement_value} lbs"
    when 'temperature_control'
      "#{requirement_value}°F"
    when 'insurance_coverage'
      "$#{requirement_value}"
    else
      requirement_value
    end
  end

  def self.common_requirements
    {
      'HAZMAT Certification' => { type: 'driver_certification', value: 'HAZMAT', mandatory: true },
      'CDL Class A' => { type: 'driver_certification', value: 'CDL_A', mandatory: true },
      'Team Driver' => { type: 'driver_certification', value: 'TEAM', mandatory: false },
      'Refrigerated Unit' => { type: 'special_equipment', value: 'REEFER', mandatory: true },
      'Tarps Required' => { type: 'cargo_handling', value: 'TARPS', mandatory: true },
      'Straps Required' => { type: 'cargo_handling', value: 'STRAPS', mandatory: true },
      'Chains Required' => { type: 'cargo_handling', value: 'CHAINS', mandatory: true }
    }
  end
end