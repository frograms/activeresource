module ActiveResource
  class Delegation
    class << self
    end

    attr_reader :_cache

    delegate :each, :each_with_index, :[], :map, to: :to_a

    def initialize(resource, *args, **options)
      @resource = resource
      @options = options
      @options[:params] ||= {}
      @options[:includes] ||= []
      @options[:extra] ||= []
      @options[:order_by] ||= {}.with_indifferent_access
      object = resource.is_a?(Class) ? resource : resource.class
      if object.superclass != ActiveResource::Base
        api_type_name = ActiveResource.api_type_name_object_map.api_type_name_of(object)
        @options[:params][:__type__] = api_type_name
      end
      @_cache = {}
    end

    def where(clauses = {})
      @options[:params] = (@options[:params] || {}).merge(clauses)
      @_cache = {}
      self
    end

    def includes(*args)
      @options[:includes] += args
      @_cache = {}
      self
    end

    def extra(*args)
      @options[:extra] += args
      @_cache = {}
      self
    end

    def order(*args, **kwargs)
      args.each do |k|
        @options[:order_by][k] = 'ASC'
      end
      kwargs.each_pair do |k, v|
        v ||= 'ASC'
        v = v.to_s.upcase
        case v
        when 'NONE' then @options[:order_by].delete(k)
        when 'DESC', 'ASC' then @options[:order_by][k] = v
        else raise "undefined sorting option: #{v}"
        end
      end
      @_cache = {}
      self
    end

    def build_options(opts = {})
      merged = Finder.merge_options(@options, opts)
      params = merged.delete(:params).with_indifferent_access
      @resource.build_belongs_to_params!(params)
      @resource.build_has_many_params!(params)
      merged[:params] = params
      merged
    end

    def all(*args)
      return _cache[:all] if _cache[:all]
      opts = args.extract_options!
      _cache[:all] = @resource.find(:all, build_options(opts))
    end
    alias_method :to_a, :all

    def last(*args)
      return _cache[:last] if _cache[:last]
      return _cache[:all].last if _cache[:all]
      opts = args.extract_options!
      _cache[:last] = @resource.find(:last, build_options(opts))
    end

    def first(*args)
      return _cache[:first] if _cache[:first]
      return _cache[:all].first if _cache[:all]
      opts = args.extract_options!
      _cache[:first] = @resource.find(:first, build_options(opts))
    end

    def find(*arguments)
      opts = arguments.extract_options!
      @resource.find(*arguments, build_options(opts))
    end

    def sum(attribute)
      return _cache.dig(:sum, attribute.to_s) if _cache.dig(:sum, attribute.to_s)
      _cache[:sum] ||= {}
      opts = build_options
      opts[:sum] = attribute
      _cache[:sum][attribute.to_s] = @resource.find(:sum, opts)
    end

    def count
      return _cache[:count] if _cache[:count]
      _cache[:count] = @resource.find(:count, build_options)
    end

    def size
      if _cache[:all]
        _cache[:all].length
      else
        count
      end
    end

    def exists?
      return _cache[:exists?] if _cache[:exists?]
      _cache[:exists?] = @resource.find(:exists?, build_options)
    end

    def blank?
      !exists?
    end
  end
end
