module ActiveResource
  class AttributeConfig
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

    attr_reader :model, :attr_name, :attr_type, :options

    def with_attribute(model, attr_name, attr_type, options = {})
      cfg = dup
      cfg.instance_variable_set(:@model, model)
      cfg.instance_variable_set(:@attr_name, attr_name)
      cfg.instance_variable_set(:@attr_type, attr_type)
      cfg.instance_variable_set(:@options, options)
      cfg
    end

    def define_accessor_in_model(repo_name, schema_name)
      # TODO: add defaults
      # the_attr = [type.to_s]
      # the_attr << options[:default] if options.has_key? :default

      return if options[:skip_define_accessor]
      if model.method_defined?(attr_name) || model.method_defined?("#{attr_name}=")
        raise AlreadyDefinedMethod, "attribute method already defined `#{attr_name}` or `#{attr_name}=` in `#{model.name}`"
      end
      attr_name = self.attr_name
      model.define_method(attr_name) do
        send(repo_name)[attr_name]
      end
      model.define_method("#{attr_name}=") do |value|
        send(repo_name)[attr_name] = value
      end
    end
  end

  class EnumAttributeConfig < AttributeConfig
    def load(attributes, key, value)
      value = value.to_s.strip
      validate(value)
      load_proc.call(attributes, key, value)
    end

    def allowed_values
      options[:in]
    end

    def validate!(value)
      unless allowed_values.include?(value.strip)
        raise InvalidValue, "`model: #{model.name}` `attribute: #{name}` value #{value} is not in #{allowed_values}"
      end
    end

    def validate(value)
      validate!(value)
    rescue InvalidValue => e
      ActiveResource::Base.logger.info(e.message)
    end

    def define_accessor_in_model(repo_name, schema_name)
      return if options[:skip_define_accessor]
      if model.method_defined?(attr_name) || model.method_defined?("#{attr_name}=")
        raise AlreadyDefinedMethod, "attribute method already defined `#{attr_name}` or `#{attr_name}=` in `#{model.name}`"
      end
      attr_name = self.attr_name
      model.define_method(attr_name) do
        send(repo_name)[attr_name]
      end
      model.define_method("#{attr_name}=") do |value|
        value = value.to_s.strip
        schema.send(schema_name)[attr_name].validate!(value)
        send(repo_name)[attr_name] = value
      end
      model.define_singleton_method("#{attr_name}_values") do
        schema.send(schema_name)[attr_name].allowed_values
      end
    end
  end
end
