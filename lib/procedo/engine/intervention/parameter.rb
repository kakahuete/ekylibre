# require 'procedo/engine/intervention'

module Procedo
  module Engine
    class Intervention
      class Parameter
        attr_reader :name, :intervention, :group, :id, :reference, :type

        delegate :procedure, to: :intervention
        delegate :working_periods, to: :intervention
        delegate :name, :reflection_name, to: :reference, prefix: true

        def initialize(group, id, attributes = {})
          if group.is_a?(Procedo::Engine::Intervention)
            @intervention = group
          elsif group.is_a?(Procedo::Engine::Intervention::GroupParameter)
            @group = group
            @intervention = @group.intervention
          else
            raise "Invalid group: #{group.inspect}"
          end
          @attributes = attributes.symbolize_keys
          @id = id.to_s
          unless root?
            @name = @attributes[:reference_name].to_sym
            @reference = procedure.find!(@name)
            @type = @reference.type
          end
        end

        def root?
          @id == Procedo::Procedure::ROOT_NAME
        end

        def to_hash
          { reference_name: @reference.name }
        end

        def param_name
          "#{type.to_s.pluralize}_attributes".to_sym
        end

        def impact_with(_steps)
          raise NotImplementedError
        end

        def impact(field)
          # puts "Impact #{field}".magenta
          send(field + '=', send(field))
        end

        def impact_dependencies!(field)
          # puts "Impact dependencies from #{field}!".red
        end

        def env
          { self: self }
        end
      end
    end
  end
end
