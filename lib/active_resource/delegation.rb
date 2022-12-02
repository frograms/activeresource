module ActiveResource
  class Delegation
    class << self
      def merge_options(base_opts, arg_opts)
        params_opts = (base_opts[:params] || {}).merge(arg_opts[:params] || {})
        opts = base_opts.except(:params).merge(arg_opts.except(:params))
        opts[:params] = params_opts
        opts
      end
    end

    delegate :each, to: :to_a

    def initialize(resource, options = {})
      @resource = resource
      @options = options
      @options[:params] ||= {}
      @options[:__includes__] ||= []
      @options[:__extra__] ||= []
    end

    def where(clauses = {})
      @options[:params] = (@options[:params] || {}).merge(clauses)
      self
    end

    def includes(*args)
      @options[:__includes__] += args
      self
    end

    def extra(*args)
      @options[:__extra__] += args
      self
    end

    def build_options(opts)
      merged = self.class.merge_options(@options, opts)
      params = merged.delete(:params).with_indifferent_access
      @resource.reflections_of(macro: :belongs_to).each do |name, assoc|
        if params.key?(name) && params[name]
          if params[name].respond_to?(:id)
            obj = params.delete(name)
            params[assoc.foreign_key] = obj.id
            params[assoc.foreign_type] = obj.model_name.name if assoc.options[:polymorphic]
          else
            raise InvalidValue, "attribute must have id method: #{@resource.name}##{name}"
          end
        end
      end
      params[:__includes__] = @options[:__includes__] if @options[:__includes__].present?
      params[:__extra__] = @options[:__extra__] if @options[:__extra__].present?
      merged[:params] = params
      merged
    end

    def all(*args)
      opts = args.extract_options!
      @resource.find(:all, *args, **build_options(opts))
    end
    alias_method :to_a, :all

    def last(*args)
      opts = args.extract_options!
      @resource.find(:last, *args, **build_options(opts))
    end

    def first(*args)
      opts = args.extract_options!
      @resource.find(:first, *args, **build_options(opts))
    end

    def find(*arguments)
      opts = arguments.extract_options!
      @resource.find(*arguments, **build_options(opts))
    end
  end
end
