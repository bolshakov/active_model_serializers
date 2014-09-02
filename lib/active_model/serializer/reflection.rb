module ActiveModel
  class Serializer
    module Reflection
      extend ActiveSupport::Concern

      included do
        class_attribute :_reflections
        self._reflections = {}
      end

      def self.create(macro, name, options, serializer_class)
        MacroReflection.new(macro, name, options, serializer_class)
      end

      def self.add_reflection(serializer_class, name, reflection)
        serializer_class._reflections = serializer_class._reflections.merge(name => reflection)
      end

      module ClassMethods

        # Returns a Hash of name of the reflection as the key and a AssociationReflection as the value.
        #
        #   AccountSerializer.reflections # => {balance: AggregateReflection}
        #
        # @api public
        def reflections
          _reflections
        end

        # Returns the AssociationReflection object for the +association+ (use the symbol).
        #
        #   Account.reflect_on_association(:owner)             # returns the owner AssociationReflection
        #   Invoice.reflect_on_association(:line_items).macro  # returns :has_many
        #
        #   @api public
        def reflect_on_association(association)
          reflections[association]
        end
      end

      class MacroReflection
        attr_reader :macro
        attr_reader :name
        attr_reader :options
        attr_reader :serializer_class

        def initialize(macro, name, options, serializer_class)
          @macro = macro
          @name = name
          @options = options
          @serializer_class = serializer_class
        end

        def association_class
          case macro
          when :belongs_to
            Associations::BelongsToAssociation
          when :has_many
            Associations::HasManyAssociation
          end
        end
      end
    end
  end
end
