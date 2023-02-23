module ActiveResource
  class AttributeConfig
    attr_reader :name, :options, :load_proc, :after_collect

    def initialize(name, &block)
      @name = name
      @options = {}
      @load_proc = block || proc do |resource, repository_name, attr_name, value|
        resource.send(repository_name)[attr_name] = value
      end
    end

    def set_load_proc(&block)
      @load_proc = block
    end

    def load(resource, repository_name, server_name, value, **options)
      if options[:collection] && @after_collect_proc
        options[:collection].collect_cache[self] ||= {}
        options[:collect_cache] = options[:collection].collect_cache[self]
      end
      options.update(attribute_config: self)
      load_proc.call(resource, repository_name, attr_name, value, **options)
    end

    def after_collect(&block)
      @after_collect_proc = block
    end

    def run_after_collect(cache)
      @after_collect_proc.call(self, cache)
    end

    attr_reader :model, :attr_name, :attr_type, :options

    def with_attribute(model, attr_name, attr_type, options = {})
      cfg = dup
      cfg.instance_variable_set(:@model, model)
      cfg.instance_variable_set(:@attr_name, attr_name)
      cfg.instance_variable_set(:@attr_type, attr_type)

      if options[:extra] == true
        options[:extra] = {default_request: true}
      end
      cfg.instance_variable_set(:@options, options)
      cfg
    end

    def server_name
      options[:server_name] || attr_name
    end

    def define_accessor_in_model
      return if options[:skip_define_accessor]
      if model.method_defined?(attr_name) || model.method_defined?("#{attr_name}=")
        raise AlreadyDefinedMethod, "attribute method already defined `#{attr_name}` or `#{attr_name}=` in `#{model.name}`"
      end
      attr_name = self.attr_name
      options = self.options

      if options.has_key?(:default)
        if options[:default].is_a?(Proc)
          model.define_method(attr_name) do
            attributes[attr_name] || options[:default].call(self)
          end
        else
          model.define_method(attr_name) do
            attributes[attr_name] || options[:default]
          end
        end
      else
        model.define_method(attr_name) do
          attributes[attr_name]
        end
      end
      model.define_method("#{attr_name}=") do |value|
        attributes[attr_name] = value
      end
    end

    def define_extra_accessor_in_model
      return if options[:skip_define_accessor]
      if model.method_defined?(attr_name) || model.method_defined?("#{attr_name}=")
        raise AlreadyDefinedMethod, "attribute method already defined `#{attr_name}` or `#{attr_name}=` in `#{model.name}`"
      end
      attr_name = self.attr_name
      options = self.options

      if options.has_key?(:default)
        if options[:default].is_a?(Proc)
          model.define_method(attr_name) do
            reload(extra: attr_name) unless extra.has_key?(attr_name)
            extra[attr_name] || options[:default].call(self)
          end
        else
          model.define_method(attr_name) do
            reload(extra: attr_name) unless extra.has_key?(attr_name)
            extra[attr_name] || options[:default]
          end
        end
      else
        model.define_method(attr_name) do
          reload(extra: attr_name) unless extra.has_key?(attr_name)
          extra[attr_name]
        end
      end
      model.define_method("#{attr_name}=") do |value|
        extra[attr_name] = value
      end
    end
  end

  class EnumAttributeConfig < AttributeConfig
    def load(resource, repository_name, server_name, value, **options)
      value = value.to_s.strip
      validate(value)
      options[:attribute_config] = self
      load_proc.call(resource, repository_name, attr_name, value, **options)
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

    def define_accessor_in_model
      return if options[:skip_define_accessor]
      if model.method_defined?(attr_name) || model.method_defined?("#{attr_name}=")
        raise AlreadyDefinedMethod, "attribute method already defined `#{attr_name}` or `#{attr_name}=` in `#{model.name}`"
      end

      attr_name = self.attr_name
      options = self.options
      model.define_method(attr_name) do
        attributes.key?(attr_name) ? attributes[attr_name] : options[:default]
      end
      model.define_method("#{attr_name}=") do |value|
        value = value.to_s.strip
        schema.attrs[attr_name].validate!(value)
        attributes[attr_name] = value
      end
      model.define_singleton_method("#{attr_name}_values") do
        schema.attrs[attr_name].allowed_values
      end
    end

    def define_extra_accessor_in_model
      return if options[:skip_define_accessor]
      if model.method_defined?(attr_name) || model.method_defined?("#{attr_name}=")
        raise AlreadyDefinedMethod, "attribute method already defined `#{attr_name}` or `#{attr_name}=` in `#{model.name}`"
      end

      attr_name = self.attr_name
      model.define_method(attr_name) do
        extra[attr_name]
      end
      model.define_method("#{attr_name}=") do |value|
        value = value.to_s.strip
        schema.extra[attr_name].validate!(value)
        extra[attr_name] = value
      end
      model.define_singleton_method("#{attr_name}_values") do
        schema.extra[attr_name].allowed_values
      end
    end
  end
end
