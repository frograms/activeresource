module ActiveResource
  class Delegation
    class << self
      def merge_options(base_opts, arg_opts, except: [])
        except += [:params]
        params_opts = (base_opts[:params] || {}).merge(arg_opts[:params] || {})
        opts = base_opts.except(*except).merge(arg_opts.except(:params))
        opts[:params] = params_opts
        opts
      end

      def build_extra_params(resource, options, params)
        exts = resource.schema.extra.keys
        exts += options[:extra] if options[:extra].present?
        if exts.present?
          params ||= {}
          ext_set ||= Set.new
          exts.each do |ext|
            case ext
            when Symbol, String then ext_set << ext.to_s
            end
          end
          exts.each do |ext|
            case ext
            when Array
              n = ext.shift.to_s
              ext_set.delete(n)
              param_name = "__extra__#{n}"
              params[param_name] = ext
            end
          end
          params[:__extra__] = ext_set.to_a
        end
        params
      end
    end

    attr_reader :_cache

    delegate :each, to: :to_a

    def initialize(resource, options = {})
      @resource = resource
      @options = options
      @options[:params] ||= {}
      @options[:__includes__] ||= []
      @options[:__extra__] ||= []
      @options[:__order_by__] ||= {}.with_indifferent_access
      @_cache = {}
    end

    def where(clauses = {})
      @options[:params] = (@options[:params] || {}).merge(clauses)
      @_cache = {}
      self
    end

    def includes(*args)
      @options[:__includes__] += args
      @_cache = {}
      self
    end

    def extra(*args)
      @options[:__extra__] += args
      @_cache = {}
      self
    end

    def order(*args, **kwargs)
      args.each do |k|
        @options[:__order_by__][k] = 'ASC'
      end
      kwargs.each_pair do |k, v|
        v ||= 'ASC'
        v = v.to_s.upcase
        case v
        when 'NONE' then @options[:__order_by__].delete(k)
        when 'DESC', 'ASC' then @options[:__order_by__][k] = v
        else raise "undefined sorting option: #{v}"
        end
      end
      @_cache = {}
      self
    end

    def build_options(opts)
      merged = self.class.merge_options(@options, opts, except: %i[__includes__ __order_by__ __extra__])
      params = merged.delete(:params).with_indifferent_access
      @resource.build_belongs_to_params!(params)
      @resource.build_has_many_params!(params)
      params[:__includes__] = @options[:__includes__] if @options[:__includes__].present?
      self.class.build_extra_params(@resource, @options, params)
      params[:__order_by__] = @options[:__order_by__] if @options[:__order_by__].present?
      merged[:params] = params
      merged
    end

    def all(*args)
      return _cache[:all] if _cache[:all]
      opts = args.extract_options!
      _cache[:all] = @resource.find(:all, *args, **build_options(opts))
    end
    alias_method :to_a, :all

    def last(*args)
      return _cache[:last] if _cache[:last]
      return _cache[:all].last if _cache[:all]
      opts = args.extract_options!
      _cache[:last] = @resource.find(:last, *args, **build_options(opts))
    end

    def first(*args)
      return _cache[:first] if _cache[:first]
      return _cache[:all].first if _cache[:all]
      opts = args.extract_options!
      _cache[:first] = @resource.find(:first, *args, **build_options(opts))
    end

    def find(*arguments)
      opts = arguments.extract_options!
      @resource.find(*arguments, **build_options(opts))
    end
  end
end
