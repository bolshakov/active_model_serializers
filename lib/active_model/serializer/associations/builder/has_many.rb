module ActiveModel::Serializer::Associations::Builder
  class HasMany < Association
    def macro
      :has_many
    end

    def valid_options
      super + [:each_serializer]
    end
  end
end
