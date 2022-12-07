# frozen_string_literal: true
require 'active_resource/custom_type_config'

module ActiveResource # :nodoc:
  class Schema # :nodoc:

    class AlreadyDefinedMethod < Error; end

    # attributes can be known to be one of these types. They are easy to
    # cast to/from.
    KNOWN_ATTRIBUTE_TYPES = %w( string text integer float decimal datetime timestamp time date binary boolean serialize )

    @custom_attribute_types = {}
    
    class << self
      attr_reader :custom_attribute_types

      def custom_attribute_type(name, &block)
        if block_given?
          @custom_attribute_types[name.to_s] = block
        else
          @custom_attribute_types[name.to_s]
        end
      end

      def known_attribute_types
        KNOWN_ATTRIBUTE_TYPES + @custom_attribute_types.keys
      end

      def load_custom_attributes
        @custom_attribute_types.keys.each{|attr_type| define_attribute_method(attr_type)}
      end

      # def string(*args)
      #   options = args.extract_options!
      #   attr_names = args
      #
      #   attr_names.each { |name| attribute(name, 'string', options) }
      # end
      def define_attribute_method(attr_type)
        class_eval <<-EOV, __FILE__, __LINE__ + 1
        # frozen_string_literal: true
        def #{attr_type}(*args)
          options = args.extract_options!
          attr_names = args

          attr_names.each { |name| attribute(name, '#{attr_type}', options) }
        end
        EOV
      end
    end

    # An array of attribute definitions, representing the attributes that
    # have been defined.
    attr_accessor :attrs

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
      @attrs[@model.primary_key] = 'integer'
    end

    def known_attributes
      @attrs.keys
    end

    def attribute(name, type, options = {})
      raise ArgumentError, "Unknown Attribute type: #{type.inspect} for key: #{name.inspect}" unless type.nil? || Schema.known_attribute_types.include?(type.to_s)

      the_type = type.to_s
      # TODO: add defaults
      # the_attr = [type.to_s]
      # the_attr << options[:default] if options.has_key? :default
      @attrs[name.to_s] = the_type
      if @model.method_defined?(name) || @model.method_defined?("#{name}=")
        raise AlreadyDefinedMethod, "attribute method already defined: #{name} or #{name}= in #{@model.name}"
      end
      @model.define_method(name) do
        attributes[name]
      end
      @model.define_method("#{name}=") do |value|
        attributes["#{name}"] = value
      end
      self
    end

    # The following are the attribute types supported by Active Resource
    # migrations.
    KNOWN_ATTRIBUTE_TYPES.each{|attr_type| define_attribute_method(attr_type)}
  end
end
