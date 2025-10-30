module ActiveResource
  class Delegation
    class << self
    end

    attr_reader :_condition, :_cache, :options
    attr_accessor :limit_value # ActiveRecord::QueryMethods
    attr_accessor :klass, :args, :kwargs

    delegate :each, :each_with_index, :[], :map, to: :to_a

    def initialize(resource, *args, **options)
      @klass = klass
      @args = args
      @resource = resource
      @options = options
      @options[:params] ||= {}
      @options[:includes] ||= []
      @options[:extra] ||= []
      @options[:order_by] ||= {}.with_indifferent_access
      object = resource.is_a?(Class) ? resource : resource.class
      if object.superclass != ActiveResource::Base
        api_type_name = ActiveResource.record_map.record_name(object)
        @options[:params][:__type__] = api_type_name
      end
      @_condition = (options[:_condition] || {}).with_indifferent_access
      @_associations = (options[:_associations] || [])
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

    # active record
    def merge!(arg)
      if arg.is_a?(self.class)
        @options[:params] = (@options[:params] || {}).merge(arg.options)
      end
      self
    end

    # active record
    def reset_scope
      self
    end

    # Association#skip_statement_cache?
    def eager_loading?
      false
    end

    # active record
    def take
      first
    end

    # active_record/calculations
    def pluck(*column_names)
      to_a.map do |obj|
        column_names.one? ? obj.send(column_names.first) : column_names.map{|name| obj.send(name)}
      end
    end

    # active record
    def first_or_initialize
      return to_a.first if to_a.present?
      klass.new(_condition)
    end

    def _association
      args[0]
    end

    # sample
    # #<ActiveRecord::Reflection::HasManyReflection:0x00007fcd6b78a628
    #   @name=:content_action_counts, @scope=nil, @options={:as=>:contentable},
    #   @active_record=Book(id: integer, created_at: datetime, updated_at: datetime),
    #   @klass=ContentActionCount, @plural_name="content_action_counts", @constructable=true,
    #   @type="contentable_type", @class_name="ContentActionCount", @inverse_name=nil>
    def _reflection
      _association&.reflection
    end

    def _reflection_as
      @_reflection_as ||= _reflection&.options&.dig(:as)
    end

    def _owner
      _association&.owner
    end

    def build_options(opts = {})
      _opts = Finder.merge_options(@options, opts)
      params = _opts.delete(:params).with_indifferent_access
      @resource.build_belongs_to_params!(params)
      @resource.build_has_many_params!(params)
      _opts[:params] = params

      if _reflection_as && _owner
        as_id = _reflection.options[:foreign_key] || "#{_reflection_as}_id"
        as_type = _reflection.options[:foreign_type] || "#{_reflection_as}_type"
        _opts.merge!({ as_id => _owner.id, as_type => _owner.class.base_class.name })
      elsif _reflection && _owner
        case _reflection
        when ActiveRecord::Reflection::BelongsToReflection
          if _reflection.polymorphic?
            id = _owner.send(_reflection.foreign_key)
            type = _owner.send(_reflection.foreign_type)
            _opts[:params].merge!({'type' => type, 'id' => id})
          else
            id = _owner.send(_reflection.foreign_key)
            type = _reflection.foreign_type
            _opts[:params].merge!({'type' => type, 'id' => id})
          end
        when ActiveRecord::Reflection::HasManyReflection
          _opts.merge!({ "#{_owner.class.base_class.model_name.singular}_id" => _owner.id.to_i })
        else raise "undefined reflection: #{_reflection.class}"
        end
      end
      _opts
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

    # File activerecord/lib/active_record/relation.rb, line 644
    def reset
      self
    end

    def force_post
      options[:__post__] = true
      self
    end
  end
end
