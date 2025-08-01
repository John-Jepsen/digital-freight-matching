# == Schema Information
#
# Table name: cargo_details
#
#  id              :bigint           not null, primary key
#  load_id         :bigint           not null
#  item_name       :string           not null
#  item_description :text
#  quantity        :integer          not null
#  unit_type       :string           not null
#  weight_per_unit :decimal(8, 2)
#  total_weight    :decimal(8, 2)
#  dimensions      :string           # LxWxH format
#  volume          :decimal(10, 3)
#  value           :decimal(10, 2)
#  commodity_class :string
#  hazmat_class    :string
#  nmfc_code       :string
#  packaging_type  :string
#  special_handling :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class CargoDetail < ApplicationRecord
  # Associations
  belongs_to :load

  # Validations
  validates :item_name, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_type, presence: true
  validates :weight_per_unit, numericality: { greater_than: 0 }, allow_blank: true
  validates :total_weight, numericality: { greater_than: 0 }, allow_blank: true
  validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validate :weight_consistency

  # Enums
  enum unit_type: {
    pieces: 'pieces',
    pallets: 'pallets',
    boxes: 'boxes',
    cartons: 'cartons',
    crates: 'crates',
    bundles: 'bundles',
    rolls: 'rolls',
    drums: 'drums',
    bags: 'bags',
    containers: 'containers',
    pounds: 'pounds',
    tons: 'tons',
    gallons: 'gallons',
    cubic_feet: 'cubic_feet'
  }

  enum packaging_type: {
    loose: 'loose',
    wrapped: 'wrapped',
    boxed: 'boxed',
    palletized: 'palletized',
    crated: 'crated',
    shrink_wrapped: 'shrink_wrapped',
    banded: 'banded',
    custom_packaging: 'custom_packaging'
  }

  enum commodity_class: {
    class_50: '50',
    class_55: '55',
    class_60: '60',
    class_65: '65',
    class_70: '70',
    class_77_5: '77.5',
    class_85: '85',
    class_92_5: '92.5',
    class_100: '100',
    class_110: '110',
    class_125: '125',
    class_150: '150',
    class_175: '175',
    class_200: '200',
    class_250: '250',
    class_300: '300',
    class_400: '400',
    class_500: '500'
  }

  # Callbacks
  before_save :calculate_total_weight
  before_save :calculate_volume

  # Scopes
  scope :hazmat, -> { where.not(hazmat_class: [nil, '']) }
  scope :high_value, -> { where('value > ?', 10000) }
  scope :by_commodity_class, ->(klass) { where(commodity_class: klass) }

  def total_cubic_feet
    return nil unless dimensions.present?
    
    begin
      l, w, h = dimensions.split('x').map(&:to_f)
      return nil if [l, w, h].any?(&:zero?)
      
      cubic_inches = l * w * h * quantity
      cubic_inches / 1728.0 # Convert to cubic feet
    rescue
      nil
    end
  end

  def density
    return nil unless total_weight.present? && total_cubic_feet.present? && total_cubic_feet > 0
    
    total_weight / total_cubic_feet
  end

  def is_hazmat?
    hazmat_class.present?
  end

  def is_high_value?
    value.present? && value > 10000
  end

  def weight_per_cubic_foot
    return nil unless total_weight.present? && total_cubic_feet.present? && total_cubic_feet > 0
    
    total_weight / total_cubic_feet
  end

  def freight_class_estimate
    return commodity_class if commodity_class.present?
    
    # Estimate based on density if no class specified
    return nil unless density.present?
    
    case density
    when 0..1
      '500'
    when 1..2
      '400'
    when 2..4
      '300'
    when 4..6
      '250'
    when 6..8
      '200'
    when 8..10
      '175'
    when 10..12
      '150'
    when 12..15
      '125'
    when 15..22.5
      '100'
    when 22.5..30
      '85'
    else
      '50'
    end
  end

  def requires_special_handling?
    special_handling.present? || is_hazmat? || is_high_value?
  end

  def display_dimensions
    return 'Not specified' unless dimensions.present?
    
    begin
      l, w, h = dimensions.split('x')
      "#{l}\" × #{w}\" × #{h}\""
    rescue
      dimensions
    end
  end

  def display_weight
    return 'Not specified' unless total_weight.present?
    
    if total_weight >= 2000
      "#{(total_weight / 2000.0).round(2)} tons"
    else
      "#{total_weight} lbs"
    end
  end

  def display_value
    return 'Not specified' unless value.present?
    
    "$#{value.to_f.round(2)}"
  end

  private

  def calculate_total_weight
    if weight_per_unit.present? && quantity.present?
      self.total_weight = weight_per_unit * quantity
    end
  end

  def calculate_volume
    if dimensions.present? && quantity.present?
      self.volume = total_cubic_feet
    end
  end

  def weight_consistency
    return unless weight_per_unit.present? && total_weight.present? && quantity.present?
    
    calculated_total = weight_per_unit * quantity
    if (calculated_total - total_weight).abs > 0.01
      errors.add(:total_weight, "doesn't match weight per unit × quantity")
    end
  end
end