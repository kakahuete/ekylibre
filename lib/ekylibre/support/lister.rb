module Ekylibre
  module Support
    class Item < Struct.new(:type, :args, :block)
      alias name type
    end

    class Lister
      delegate :map, :collect, :each, :any?, :size, :first, :[], :detect, to: :list

      attr_reader :list

      def initialize(*types)
        @list = []
        types.each do |type|
          raise 'Cannot use "list" as type name' if type.to_s == 'list'
          define_singleton_method type do |*args, &block|
            @list << Item.new(type.to_sym, args, block)
          end
          define_singleton_method type.to_s.pluralize do
            @list.select { |i| i.type == type }
          end
        end
      end

      def detect_and_extract!(&block)
        index = @list.find_index(&block)
        return nil unless index
        @list.delete_at(index)
      end
    end
  end
end
