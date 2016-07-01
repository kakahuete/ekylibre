# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2016 Brice Texier, David Joulin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: inspections
#
#  activity_id                    :integer          not null
#  comment                        :text
#  created_at                     :datetime         not null
#  creator_id                     :integer
#  id                             :integer          not null, primary key
#  implanter_application_width    :decimal(19, 4)
#  implanter_rows_number          :integer
#  implanter_working_width        :decimal(19, 4)
#  lock_version                   :integer          default(0), not null
#  number                         :string           not null
#  product_id                     :integer          not null
#  product_net_surface_area_unit  :string
#  product_net_surface_area_value :decimal(19, 4)
#  sampled_at                     :datetime         not null
#  sampling_distance              :decimal(19, 4)
#  updated_at                     :datetime         not null
#  updater_id                     :integer
#

class Inspection < Ekylibre::Record::Base
  belongs_to :activity
  belongs_to :product
  has_many :calibrations, class_name: 'InspectionCalibration',
                          inverse_of: :inspection, dependent: :destroy
  has_many :points, class_name: 'InspectionPoint',
                    inverse_of: :inspection, dependent: :destroy
  has_many :scales, through: :activity, source: :inspection_calibration_scales
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :sampled_at, timeliness: { allow_blank: true, on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.now + 50.years } }
  validates :implanter_rows_number, numericality: { allow_nil: true, only_integer: true }
  validates :implanter_application_width, :implanter_working_width, :product_net_surface_area_value, :sampling_distance, numericality: { allow_nil: true }
  validates :activity, :number, :product, :sampled_at, presence: true
  # ]VALIDATORS]
  validates :implanter_application_width, :implanter_rows_number,
            :sampling_distance, numericality: { greater_than: 0 }
  validates :sampling_distance, presence: true

  # composed_of :product_net_surface_area, class_name: 'Measure', mapping: [%w(product_net_surface_area_value to_d), %w(product_net_surface_area_unit unit)]

  acts_as_numbered :number

  accepts_nested_attributes_for :points, allow_destroy: true
  accepts_nested_attributes_for :calibrations, allow_destroy: true

  delegate :measure_grading_net_mass, :measure_grading_items_count,
           :measure_grading_sizes, :grading_net_mass_unit, to: :activity

  scope :of_products, lambda { |*products|
    products.flatten!
    where(product_id: products.map(&:id))
  }

  before_validation :set_implanter_values, on: :create
  after_validation :set_net_surface_area, on: :create

  before_validation do
    if implanter_application_width && implanter_rows_number && implanter_rows_number != 0
      self.implanter_working_width = implanter_application_width / implanter_rows_number
    end
  end

  def set_net_surface_area
    return unless product
    if product.net_surface_area
      self.product_net_surface_area_value ||= product.net_surface_area.to_d(:hectare)
      self.product_net_surface_area_unit ||= 'hectare'
    elsif product.shape
      self.product_net_surface_area_value ||= product.shape.area.to_d(:hectare)
      self.product_net_surface_area_unit ||= 'hectare'
    end
  end

  def set_implanter_values
    return unless product

    # get sowing intervention of current plant
    interventions = Intervention.with_outputs(product)

    equipment = nil

    if interventions.any?
      # get abilities of each tool to grab sower or implanter
      interventions.first.tools.each do |tool|
        if tool.product.able_to?('sow') || tool.product.able_to?('implant')
          equipment = tool.product
        end
      end

      if equipment
        # get rows_count and application_width of sower or implanter
        rows_count = equipment.rows_count(sampled_at) # if equipment.has_indicator?(rows_count)
        # rows_count = equipment.rows_count(self.sampled_at)
        application_width = equipment.application_width(sampled_at).convert(:meter) # if equipment.has_indicator?(application_width)
        # set rows_count to implanter_application_width
        self.implanter_rows_number ||= rows_count if rows_count
        self.implanter_application_width ||= application_width.to_d if application_width
      end
    end
  end

  # return the order of the grading relative to product
  def position
    siblings.reorder(:sampled_at).pluck(:id).index(id) + 1
  end

  def siblings
    product.inspections
  end

  # # return a measure of total net mass of all product grading checks of type :calibre
  # def net_mass(unit = :kilogram)
  #   total = checks.of_nature(:calibre).map(&:net_mass_value).compact.sum
  #   total = total.in(unit) if unit
  #   total
  # end

  # # return total count of all product grading checks of type :calibre
  # def item_count
  #   total = checks.of_nature(:calibre).map(&:items_count).compact.sum
  #   total
  # end

  # # return the current stock in ground
  # # unit could be :ton or :thousand
  # # n: number of product or net mass of product
  # # m: sampling distance value in meter (see abacus)
  # # c: coefficient (see abacus)
  # # total = n * ( plant_surface_area_in_hectare / m ) * c
  # def product_stock_in_ground(unit = :ton)
  #   # area unit
  #   area_unit = unit.to_s + '_per_hectare'
  #   # n
  #   n = if unit == :ton || unit == :kilogram
  #         net_mass.convert(unit)
  #       elsif unit == :unity
  #         item_count
  #       else
  #         net_mass.to_d(:ton)
  #       end
  #   # m
  #   m = sampling_distance if sampling_distance
  #   # c
  #   c = 10_000 / implanter_working_width if implanter_working_width
  #   # total
  #   if n && c
  #     current_stock = n * (net_surface_area_in_hectare / m) * c
  #     return current_stock.to_d.in(unit.to_sym)
  #   else
  #     return nil
  #   end
  # end

  def mass_statable?
    product_net_surface_area && measure_grading_net_mass
  end

  def product_net_surface_area
    return nil if product_net_surface_area_value.blank? ||
                  product_net_surface_area_unit.blank?
    product_net_surface_area_value.in(product_net_surface_area_unit)
  end

  def sampling_length
    (sampling_distance || 0).in(:meter)
  end

  def sampling_area
    (sampling_length.to_d(:meter) * implanter_working_width).in(:square_meter)
  end

  def points_of_category(category = nil)
    return points if category.blank?
    points.of_category(category)
  end

  def points_items_count(category = nil)
    points_of_category(category).sum(:items_count)
  end

  def points_net_mass(category = nil)
    points_of_category(category).sum(:net_mass_value).in(activity.grading_net_mass_unit)
  end

  def total_points_net_mass(category = nil)
    points_of_category(category).map(&:total_net_mass).sum.round(0)
  end

  def points_net_mass_yield(category = nil)
    points_of_category(category).map(&:net_mass_yield).sum.round(0)
  end

  def points_net_mass_percentage(category = nil)
    points_of_category(category).map(&:net_mass_percentage).sum
  end

  def items_count(scale = nil)
    if scale.nil?
      (scales.map { |s| net_mass(s) }.sum / scales.count).round(0)
    else
      calibrations.of_scale(scale).sum(:items_count).in(Nomen::Unit.find(:unity))
    end
  end

  def net_mass(scale = nil)
    if scale.nil?
      (scales.map { |s| net_mass(s) }.sum / scales.count).round(0)
    else
      calibrations.of_scale(scale).sum(:net_mass_value).in(activity.grading_net_mass_unit)
    end
  end

  def total_items_count(scale = nil)
    if scale.nil?
      (scales.map { |s| total_items_count(s) }.sum / scales.count).round(0)
    else
      calibrations.of_scale(scale).map(&:total_items_count).sum
    end
  end

  def total_net_mass(scale = nil)
    if scale.nil?
      (scales.map { |s| total_net_mass(s) }.sum / scales.count).round(0)
    else
      calibrations.of_scale(scale).map(&:total_net_mass).sum
    end
  end

  def net_mass_yield(scale = nil)
    if scale.nil?
      (scales.map { |s| net_mass_yield(s) }.sum / scales.count).round(0)
    else
      calibrations.of_scale(scale).map(&:net_mass_yield).sum.round(0)
    end
  end

  def net_items_yield(scale = nil)
    if scale.nil?
      (scales.map { |s| net_items_yield(s) }.sum / scales.count).round(0)
    else
      calibrations.of_scale(scale).map(&:net_items_yield).sum.round(0)
    end
  end

  def marketable_net_mass(scale = nil)
    if scale.nil?
      (scales.map { |s| marketable_net_mass(s) }.sum / scales.count).round(0)
    else
      calibrations.of_scale(scale).marketable.map(&:marketable_net_mass).sum.round(0)
    end
  end

  def marketable_items_count(scale = nil)
    if scale.nil?
      (scales.map { |s| marketable_items_count(s) }.sum / scales.count).round(0)
    else
      calibrations.of_scale(scale).marketable.map(&:marketable_items_count).sum.round(0)
    end
  end

  def marketable_mass_yield(scale = nil)
    if scale.nil?
      (scales.map { |s| marketable_mass_yield(s) }.sum / scales.count).round(0)
    else
      calibrations.of_scale(scale).marketable.map(&:marketable_mass_yield).sum.round(0)
    end
  end

    def marketable_items_yield(scale = nil)
    if scale.nil?
      (scales.map { |s| marketable_items_yield(s) }.sum / scales.count).round(0)
    else
      calibrations.of_scale(scale).marketable.map(&:marketable_items_yield).sum.round(0)
    end
  end

  def unmarketable_rate
    # raise [unmarketable_net_mass.to_s, total_net_mass.to_s].to_sentence
    net_mass.value != 0 ? unmarketable_net_mass / net_mass : nil
  end

  def unmarketable_net_mass
    points.unmarketable.sum(:net_mass_value).in(activity.grading_net_mass_unit)
  end
end
