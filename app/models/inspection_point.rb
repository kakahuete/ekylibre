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
# == Table: inspection_points
#
#  created_at         :datetime         not null
#  creator_id         :integer
#  id                 :integer          not null, primary key
#  inspection_id      :integer          not null
#  items_count        :integer
#  lock_version       :integer          default(0), not null
#  maximal_size_value :decimal(19, 4)
#  minimal_size_value :decimal(19, 4)
#  nature_id          :integer          not null
#  net_mass_value     :decimal(19, 4)
#  updated_at         :datetime         not null
#  updater_id         :integer
#

class InspectionPoint < Ekylibre::Record::Base
  include Inspectable
  belongs_to :nature, class_name: 'ActivityInspectionPointNature'
  belongs_to :inspection, inverse_of: :points
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :maximal_size_value, :minimal_size_value, :net_mass_value, numericality: { allow_nil: true }
  validates :inspection, :nature, presence: true
  # ]VALIDATORS]

  scope :of_nature, lambda { |nature|
    where(nature_id: ActivityInspectionPointNature.select(:id).where(nature: nature))
  }

  scope :of_products, lambda { |*products|
    where(inspection_id: Inspection.of_products(products).select(:id))
  }

  scope :of_category, ->(category) { where(nature_id: ActivityInspectionPointNature.where(category: category)) }

  scope :unmarketable, -> { where(nature_id: ActivityInspectionPointNature.unmarketable) }

  def net_mass_percentage
    (100 * (net_mass_in_unit / inspection.net_mass))
  end

  def items_count_percentage
    (100 * (items_count_in_unit / inspection.items_count))
  end
end
