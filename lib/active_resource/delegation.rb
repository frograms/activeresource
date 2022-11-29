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

    def initialize(resource, options = {})
      @resource = resource
      @options = options
    end

    def merge_options(opts)
      self.class.merge_options(@options, opts)
    end

    def all(*args)
      opts = args.extract_options!
      @resource.find(:all, *args, **merge_options(opts))
    end

    def last(*args)
      opts = args.extract_options!
      @resource.find(:last, *args, **merge_options(opts))
    end

    def first(*args)
      opts = args.extract_options!
      @resource.find(:first, *args, **merge_options(opts))
    end

    def find(*arguments)
      ops = arguments.extract_options!
      @resource.find(*arguments, **merge_options(opts))
    end

    def where(clauses = {})
      @options[:params] = (@options[:params] || {}).merge(clauses)
      self
    end
  end
end
