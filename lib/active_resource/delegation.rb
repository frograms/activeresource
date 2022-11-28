module ActiveResource
  class Delegation
    def initialize(resource, options = {})
      @resource = resource
      @options = options
    end

    def all(*args)
      options = @options.merge(args.extract_options!)
      @resource.find(:all, *args, **options)
    end

    def last(*args)
      options = @options.merge(args.extract_options!)
      @resource.find(:last, *args, **options)
    end

    def first(*args)
      options = @options.merge(args.extract_options!)
      @resource.find(:first, *args, **options)
    end

    def find(*arguments)
      options = @options.merge(args.extract_options!)
      @resource.find(*arguments, **options)
    end

    def where(clauses = {})
      @options.update(clauses)
      self
    end
  end
end
