module ActiveModel
  class Serializer
    module Associations
      module Builder
        class Association
          attr_reader :name, :options
          VALID_OPTIONS = %i(virtual_value embed except only serializer).freeze

          def self.build(serializer_class, name, options = {})
            builder = create_builder(name, options)
            reflection = builder.build(serializer_class)
            define_accessors(serializer_class, reflection)
            reflection
          end

          def self.create_builder(name, options)
            raise ArgumentError, 'association names must be a Symbol' unless name.kind_of?(Symbol)

            new(name, options)
          end

          def self.define_accessors(serializer_class, reflection)
            name = reflection.name
            # serializer_class.class_eval <<-CODE, __FILE__, __LINE__ + 1
            serializer_class.class_eval do
              define_method "#{name}_with_serialization" do |*args|
                association(name).reader(*args)
              end

              unless method_defined?(name)
                define_method name do
                  object.send(name)
                end
              end

              alias_method_chain name, :serialization
            end
          end

          def initialize(name, options)
            @name = name
            @options = options

            validate_options
          end

          def build(serializer_class)
            ActiveModel::Serializer::Reflection.create(macro, name, options, serializer_class)
          end

          def macro
            raise NotImplementedError
          end

          def validate_options
            options.assert_valid_keys(VALID_OPTIONS)
          end
        end
      end
    end
  end
end
