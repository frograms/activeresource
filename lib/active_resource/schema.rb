# frozen_string_literal: true
require 'active_resource/attribute_config'

module ActiveResource # :nodoc:
  class Schema # :nodoc:

    class AlreadyDefinedMethod < Error; end

    # attributes can be known to be one of these types. They are easy to
    # cast to/from.
    KNOWN_ATTRIBUTE_TYPES = {
      string: AttributeConfig.new(:string),
      text: AttributeConfig.new(:text),
      integer: AttributeConfig.new(:integer) do |attributes, attr_name, value|
        attributes[attr_name] = value ? Integer(value) : nil
      end,
      float: AttributeConfig.new(:float) do |attributes, attr_name, value|
        attributes[attr_name] = value ? Float(value) : nil
      end,
      decimal: AttributeConfig.new(:decimal) do |attributes, attr_name, value|
        attributes[attr_name] = value ? Integer(value) : nil
      end,
      datetime: AttributeConfig.new(:datetime) do |attributes, attr_name, value|
        attributes[attr_name] = value ? Time.zone.parse(value) : nil
      end,
      timestamp: AttributeConfig.new(:timestamp) do |attributes, attr_name, value|
        attributes[attr_name] = value ? Time.zone.parse(value) : nil
      end,
      time: AttributeConfig.new(:time) do |attributes, attr_name, value|
        attributes[attr_name] = value ? Time.zone.parse(value) : nil
      end,
      date: AttributeConfig.new(:date) do |attributes, attr_name, value|
        attributes[attr_name] = value ? Date.parse(value) : nil
      end,
      binary: AttributeConfig.new(:binary),
      boolean: AttributeConfig.new(:boolean),
      serialize: AttributeConfig.new(:serialize),
      enum: EnumAttributeConfig.new(:enum)
    }.with_indifferent_access

    @custom_attribute_types = {}.with_indifferent_access
    
    class << self
      attr_reader :custom_attribute_types

      def known_attribute_types
        (KNOWN_ATTRIBUTE_TYPES.values + @custom_attribute_types.values).map{|t| t.name.to_s}
      end

      def set_custom_attribute_type(config)
        @custom_attribute_types[config.name] = config
        define_attribute_method(config)
      end

      def attribute_config(type)
        KNOWN_ATTRIBUTE_TYPES[type] || @custom_attribute_types[type]
      end

      # def string(*args)
      #   options = args.extract_options!
      #   attr_names = args
      #
      #   attr_names.each { |name| attribute(name, 'string', options) }
      # end
      def define_attribute_method(attr_type_config)
        class_eval <<-EOV, __FILE__, __LINE__ + 1
        # frozen_string_literal: true
        def #{attr_type_config.name}(*args)
          options = args.extract_options!
          attr_names = args
          attr_names.each { |name| attribute(name, '#{attr_type_config.name}', options) }
        end
        EOV
      end
    end

    # An array of attribute definitions, representing the attributes that
    # have been defined.
    attr_accessor :attrs, :extra
    attr_accessor :attrs_by_server_name, :extra_by_server_name

    delegate :[], :has_key?, :<=>, :blank?, :present?, to: :attrs

    # The internals of an Active Resource Schema are very simple -
    # unlike an Active Record TableDefinition (on which it is based).
    # It provides a set of convenience methods for people to define their
    # schema using the syntax:
    #  schema do
    #    string :foo
    #    integer :bar
    #  end
    #
    #  The schema stores the name and type of each attribute. That is then
    #  read out by the schema method to populate the schema of the actual
    #  resource.
    def initialize(model, attrs: {})
      @model = model
      @attrs = attrs.with_indifferent_access
      @extra = {}.with_indifferent_access
      @attrs_by_server_name = {}.with_indifferent_access
      @extra_by_server_name = {}.with_indifferent_access

      @attrs.each { |k, v| attribute(k, v) }
      unless @attrs.key?(@model.primary_key)
        attribute(@model.primary_key, 'integer', skip_define_accessor: true)
      end
    end

    # { 'name' => 'string', 'age' => 'integer' }
    def attrs_type_name
      @attrs.keys.index_with { |attr| @attrs[attr].name.to_s }
    end

    def known_attributes
      @attrs.keys
    end

    def extra_attributes
      @extra.keys
    end

    def extra_attribute_config_by_server_name(key)
      @extra_by_server_name[key]
    end

    def server_attribute_names
      @server_attribute_names ||= @attrs.values.map{|attribute_config| attribute_config.server_name.to_s}
    end

    def attribute(name, type, options = {})
      raise ArgumentError, "Unknown Attribute type: #{type.inspect} for key: #{name.inspect}" unless type.nil? || Schema.known_attribute_types.include?(type.to_s)

      if options[:extra]
        extra_attribute(name, type, options)
        return self
      end

      attribute_config = self.class.attribute_config(type)
      attribute_config = attribute_config.with_attribute(@model, name, type, options)
      @attrs[name.to_s] = attribute_config
      @attrs_by_server_name[attribute_config.server_name] = attribute_config
      attribute_config.define_accessor_in_model(:attributes, :attrs)
      self
    end

    def extra_attribute(name, type, options = {})
      raise ArgumentError, "Unknown Attribute type: #{type.inspect} for key: #{name.inspect}" unless type.nil? || Schema.known_attribute_types.include?(type.to_s)

      attribute_config = self.class.attribute_config(type)
      attribute_config = attribute_config.with_attribute(@model, name, type, options)
      @extra[name.to_s] = attribute_config
      @extra_by_server_name[attribute_config.server_name] = attribute_config
      attribute_config.define_accessor_in_model(:extra, :extra)
    end

    # The following are the attribute types supported by Active Resource
    # migrations.
    KNOWN_ATTRIBUTE_TYPES.each_value{|attr_type_config| define_attribute_method(attr_type_config)}
  end
end
