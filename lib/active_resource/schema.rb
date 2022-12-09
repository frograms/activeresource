# frozen_string_literal: true

module ActiveResource # :nodoc:
  class Schema # :nodoc:

    class AlreadyDefinedMethod < Error; end

    class TypeConfig
      attr_reader :name, :load_proc

      def initialize(name, &block)
        @name = name
        @load_proc = block || proc {|attributes, key, value| attributes[key] = value}
      end

      def set_load_proc(&block)
        @load_proc = block
      end

      def load(attributes, key, value)
        load_proc.call(attributes, key ,value)
      end

      def define_accessor_in_model(model, attr_name, repo_name, schema_name, options = {})
        # TODO: add defaults
        # the_attr = [type.to_s]
        # the_attr << options[:default] if options.has_key? :default

        if model.method_defined?(attr_name) || model.method_defined?("#{attr_name}=")
          raise AlreadyDefinedMethod, "attribute method already defined `#{attr_name}` or `#{attr_name}=` in `#{model.name}`"
        end
        model.define_method(attr_name) do
          send(repo_name)[attr_name]
        end
        model.define_method("#{attr_name}=") do |value|
          send(repo_name)[attr_name] = value
        end
      end
    end

    # attributes can be known to be one of these types. They are easy to
    # cast to/from.
    KNOWN_ATTRIBUTE_TYPES = {
      string: TypeConfig.new(:string),
      text: TypeConfig.new(:text),
      integer: TypeConfig.new(:integer) do |attributes, key, value|
        attributes[key] = Integer(value)
      end,
      float: TypeConfig.new(:float) do |attributes, key, value|
        attributes[key] = Float(value)
      end,
      decimal: TypeConfig.new(:decimal) do |attributes, key, value|
        attributes[key] = Integer(value)
      end,
      datetime: TypeConfig.new(:datetime) do |attributes, key, value|
        attributes[key] = Time.zone.parse(value)
      end,
      timestamp: TypeConfig.new(:timestamp) do |attributes, key, value|
        attributes[key] = Time.zone.parse(value)
      end,
      time: TypeConfig.new(:time) do |attributes, key, value|
        attributes[key] = Time.zone.parse(value)
      end,
      date: TypeConfig.new(:date) do |attributes, key, value|
        attributes[key] = Date.parse(value)
      end,
      binary: TypeConfig.new(:binary),
      boolean: TypeConfig.new(:boolean),
      serialize: TypeConfig.new(:serialize)
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

      def type_config(type)
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
      @attrs.each { |k, v| attribute(k, v) }
      unless @attrs.key?(@model.primary_key)
        attribute(@model.primary_key, 'integer', skip_define_accessor: true)
      end
      @extra = {}.with_indifferent_access
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

    def attribute(name, type, options = {})
      raise ArgumentError, "Unknown Attribute type: #{type.inspect} for key: #{name.inspect}" unless type.nil? || Schema.known_attribute_types.include?(type.to_s)

      if options[:extra]
        extra_attribute(name, type, options)
        return self
      end

      type_config = self.class.type_config(type)
      @attrs[name.to_s] = type_config
      type_config.define_accessor_in_model(@model, name, :attributes, :attrs, options) unless options[:skip_define_accessor]
      self
    end

    def extra_attribute(name, type, options = {})
      raise ArgumentError, "Unknown Attribute type: #{type.inspect} for key: #{name.inspect}" unless type.nil? || Schema.known_attribute_types.include?(type.to_s)

      type_config = self.class.type_config(type)
      @extra[name.to_s] = type_config
      type_config.define_accessor_in_model(@model, name, :extra, :extra, options) unless options[:skip_define_accessor]
    end

    # The following are the attribute types supported by Active Resource
    # migrations.
    KNOWN_ATTRIBUTE_TYPES.each_value{|attr_type_config| define_attribute_method(attr_type_config)}
  end
end
