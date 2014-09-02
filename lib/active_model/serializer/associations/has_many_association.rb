module ActiveRecord
  # = Active Record Has Many Association
  module Associations
    # This is the proxy that handles a has many association.
    #
    # If the association has a <tt>:through</tt> option further specialization
    # is provided by its child HasManyThroughAssociation.
    class HasManyAssociation < CollectionAssociation #:nodoc:

      def handle_dependency
        case options[:dependent]
        when :restrict_with_exception
          raise ActiveRecord::DeleteRestrictionError.new(reflection.name) unless empty?

        when :restrict_with_error
          unless empty?
            record = klass.human_attribute_name(reflection.name).downcase
            owner.errors.add(:base, :"restrict_dependent_destroy.many", record: record)
            false
          end

        else
          if options[:dependent] == :destroy
            # No point in executing the counter update since we're going to destroy the parent anyway
            load_target.each { |t| t.destroyed_by_association = reflection }
            destroy_all
          else
            delete_all
          end
        end
      end
    end
  end
end
