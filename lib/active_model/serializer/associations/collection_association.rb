module ActiveModel
  class Serializer
    module Associations
      # = Active Record Association Collection
      #
      # CollectionAssociation is an abstract class that provides common stuff to
      # ease the implementation of association proxies that represent
      # collections. See the class hierarchy in Association.
      #
      #   CollectionAssociation:
      #     HasManyAssociation => has_many
      #       HasManyThroughAssociation + ThroughAssociation => has_many :through
      #
      # CollectionAssociation class provides common methods to the collections
      # defined by +has_and_belongs_to_many+, +has_many+ or +has_many+ with
      # +:through association+ option.
      #
      # You need to be careful with assumptions regarding the target: The proxy
      # does not fetch records from the database until it needs them, but new
      # ones created with +build+ are added to the target. So, the target may be
      # non-empty and still lack children waiting to be read from the database.
      # If you look directly to the database you cannot assume that's the entire
      # collection because new records may have been added to the target, etc.
      #
      # If you need to work on all current children, new and existing records,
      # +load_target+ and the +loaded+ flag are your friends.
      class CollectionAssociation < Association #:nodoc:

        # Implements the reader method, e.g. foo.items for Foo.has_many :items
        def reader(force_reload = false)
          if force_reload
            klass.uncached { reload }
          elsif stale_target?
            reload
          end

          @proxy ||= CollectionProxy.create(klass, self)
        end

        # Implements the writer method, e.g. foo.items= for Foo.has_many :items
        def writer(records)
          replace(records)
        end

        # Implements the ids reader method, e.g. foo.item_ids for Foo.has_many :items
        def ids_reader
          if loaded?
            load_target.map do |record|
              record.send(reflection.association_primary_key)
            end
          else
            column = "#{reflection.quoted_table_name}.#{reflection.association_primary_key}"
            scope.pluck(column)
          end
        end

        # Implements the ids writer method, e.g. foo.item_ids= for Foo.has_many :items
        def ids_writer(ids)
          pk_column = reflection.primary_key_column
          ids = Array(ids).reject { |id| id.blank? }
          ids.map! { |i| pk_column.type_cast(i) }
          replace(klass.find(ids).index_by { |r| r.id }.values_at(*ids))
        end

        def reset
          super
          @target = []
        end

        def select(*fields)
          if block_given?
            load_target.select.each { |e| yield e }
          else
            scope.select(*fields)
          end
        end

        def build(attributes = {}, &block)
          if attributes.is_a?(Array)
            attributes.collect { |attr| build(attr, &block) }
          else
            add_to_target(build_record(attributes)) do |record|
              yield(record) if block_given?
            end
          end
        end

        def create(attributes = {}, &block)
          _create_record(attributes, &block)
        end

        def create!(attributes = {}, &block)
          _create_record(attributes, true, &block)
        end

        # Add +records+ to this association. Returns +self+ so method calls may
        # be chained. Since << flattens its argument list and inserts each record,
        # +push+ and +concat+ behave identically.
        def concat(*records)
          if owner.new_record?
            load_target
            concat_records(records)
          else
            transaction { concat_records(records) }
          end
        end

        # Returns true if the collection is empty.
        #
        # If the collection has been loaded
        # it is equivalent to <tt>collection.size.zero?</tt>. If the
        # collection has not been loaded, it is equivalent to
        # <tt>collection.exists?</tt>. If the collection has not already been
        # loaded and you are going to fetch the records anyway it is better to
        # check <tt>collection.length.zero?</tt>.
        def empty?
          if loaded?
            size.zero?
          else
            @target.blank? && !scope.exists?
          end
        end

        # Returns true if the collections is not empty.
        # Equivalent to +!collection.empty?+.
        def any?
          if block_given?
            load_target.any? { |*block_args| yield(*block_args) }
          else
            !empty?
          end
        end

        # Returns true if the collection has more than 1 record.
        # Equivalent to +collection.size > 1+.
        def many?
          if block_given?
            load_target.many? { |*block_args| yield(*block_args) }
          else
            size > 1
          end
        end

        def include?(record)
          if record.is_a?(reflection.klass)
            if record.new_record?
              include_in_memory?(record)
            else
              loaded? ? target.include?(record) : scope.exists?(record.id)
            end
          else
            false
          end
        end

        def load_target
          if find_target?
            @target = merge_target_lists(find_target, target)
          end

          loaded!
          target
        end

        def scope(opts = {})
          scope = super()
          scope.none! if opts.fetch(:nullify, true) && null_scope?
          scope
        end

        def null_scope?
          owner.new_record? && !foreign_key_present?
        end

        private

        def find_target
          records = scope.to_a
          records.each { |record| set_inverse_instance(record) }
          records
        end

        def _create_record(attributes, raise = false, &block)
          unless owner.persisted?
            raise ActiveRecord::RecordNotSaved, "You cannot call create unless the parent is saved"
          end

          if attributes.is_a?(Array)
            attributes.collect { |attr| _create_record(attr, raise, &block) }
          else
            transaction do
              add_to_target(build_record(attributes)) do |record|
                yield(record) if block_given?
                insert_record(record, true, raise)
              end
            end
          end
        end

        # Do the relevant stuff to insert the given record into the association collection.
        def insert_record(record, validate = true, raise = false)
          raise NotImplementedError
        end

        def create_scope
          scope.scope_for_create.stringify_keys
        end

        def concat_records(records, should_raise = false)
          result = true

          records.flatten.each do |record|
            raise_on_type_mismatch!(record)
            add_to_target(record) do |rec|
              result &&= insert_record(rec, true, should_raise) unless owner.new_record?
            end
          end

          result && records
        end
      end
    end
  end
end
