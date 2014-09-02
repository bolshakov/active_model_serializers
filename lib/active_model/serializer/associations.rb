module ActiveModel
  class Serializer
    module Associations # :nodoc:
      extend ActiveSupport::Autoload
      extend ActiveSupport::Concern

      module Builder #:nodoc:
        autoload :Association, 'active_model/serializer/associations/builder/association'
        autoload :BelongsTo, 'active_model/serializer/associations/builder/belongs_to'
        autoload :HasMany, 'active_model/serializer/associations/builder/has_many'
      end

      module ClassMethods
        def has_many(name, options = {})
          reflection = Builder::HasMany.build(self, name, options)
          Reflection.add_reflection(self, name, reflection)
        end

        def belongs_to(name, options = {})
          reflection = Builder::BelongsTo.build(self, name, options)
          Reflection.add_reflection(self, name, reflection)
        end

        alias_method :has_one, :belongs_to
      end

      def association(name)
        reflection = self.class.reflect_on_association(name)
        reflection.association_class.new(self, reflection)
      end
    end
  end
end
