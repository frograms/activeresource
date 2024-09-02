ActiveSupport.on_load(:active_record) do
  class ::ActiveRecord::PredicateBuilder::PolymorphicArrayValue
    # Support to SomeActiveRecord.where(polymorphic_belongs_to: SomeActiveResource)
    alias_method :__klass, :klass
    def klass(value)
      __klass(value) || begin
        if value.class.respond_to?(:polymorphic_name)
          value.class
        end
      end
    end

    alias_method :__convert_to_id, :convert_to_id
    def convert_to_id(value)
      converted = __convert_to_id(value)
      if converted && converted.eql?(value)
        if value.respond_to?(:_read_attribute)
          value._read_attribute(primary_key(value))
        else
          value
        end
      else
        converted
      end
    end
  end
end
