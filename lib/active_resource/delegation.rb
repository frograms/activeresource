module ActiveResource
  class Delegation
    class << self
      def merge_options(*options)
        result_opts = {}
        params = {}
        includes = []
        extra = []
        order_by = {}.with_indifferent_access

        options.each do |opt|
          opt = opt.dup
          params.update(opt.delete(:params) || {})
          includes += (Array.wrap(opt.delete(:includes)) || [])
          extra += (Array.wrap(opt.delete(:extra)) || [])

          opt_order_by = opt.delete(:order_by)
          opt_order_by = case opt_order_by
          when Symbol, String then { opt_order_by => :asc }
          when Array then opt_order_by.index_with{ :asc }
          when NilClass then {}
          else opt_order_by
          end
          order_by.update(opt_order_by)

          result_opts.update(opt)
        end

        params[:includes] = includes
        params[:extra] = extra
        params[:order_by] = order_by
        result_opts[:params] = params
        result_opts
      end

      def build_includes_params!(resource, params)
        incs = []
        Array.wrap(params.delete(:includes)).each do |e|
          incs << e if e.present?
        end
        if incs.present?
          params[:__includes__] = incs.uniq
        end
        params
      end

      def build_extra_params!(resource, params)
        ext_configs = resource.schema.extra.select{|k, v| v.options.dig(:extra, :default_request)}.values
        exts = ext_configs.map{|cfg| cfg.server_name}

        Array.wrap(params.delete(:extra)).each do |e|
          if (e_config = resource.schema.extra[e])
            exts << e_config.server_name
          else
            exts << e
          end
        end

        if exts.present?
          ext_set = Set.new
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

      def build_order_by_params!(resource, params)
        order_by = params.delete(:order_by)
        params[:__order_by__] = order_by if order_by.present?
        params
      end

      def build_params!(resource, params)
        build_includes_params!(resource, params)
        build_extra_params!(resource, params)
        build_order_by_params!(resource, params)
      end
    end

    attr_reader :_cache

    delegate :each, to: :to_a

    def initialize(resource, options = {})
      @resource = resource
      @options = options
      @options[:params] ||= {}
      @options[:includes] ||= []
      @options[:extra] ||= []
      @options[:order_by] ||= {}.with_indifferent_access
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

    def build_options(opts)
      merged = self.class.merge_options(@options, opts)
      params = merged.delete(:params).with_indifferent_access
      @resource.build_belongs_to_params!(params)
      @resource.build_has_many_params!(params)
      self.class.build_params!(@resource, params)
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
