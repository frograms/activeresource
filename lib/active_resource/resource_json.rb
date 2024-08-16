module ActiveResource
  module ResourceJson
    extend ActiveSupport::Concern

    mattr_accessor :methods_prefix, default: '_r_'.freeze
    mattr_accessor :rescue_method, default: (
      proc do |obj, mtd, original_method, exception|
        ResourceJson.default_rescue_method(obj, mtd, original_method, exception)
      end
    )

    class << self
      def default_rescue_method(obj, method_name, original_method, exception)
        ret = {type: exception.class.name, message: exception.message}
        msg = "resource_json `method: #{method_name}` rejected. if you want allow, alias as `#{obj.resource_methods_prefix}#{method_name}` in `class: #{obj.class.name}`"
        ActiveResource::Base.logger.info(msg)
        ret.merge(message: msg)
      end
    end

    class_methods do
      def resource_methods_prefix
        ResourceJson.methods_prefix
      end

      def resource_method_name(mtd)
        :"#{resource_methods_prefix}#{mtd}"
      end

      def allow_resource_json(*mtds)
        mtds.each do |mtd|
          define_method(resource_method_name(mtd)) do
            send(mtd)
          end
        end
      end

      def allow_resource_json?(mtd)
        mtd2 = resource_method_name(mtd)
        instance_methods.include?(mtd2) ? mtd2 : nil
      end
    end

    def resource_methods_prefix
      self.class.resource_methods_prefix
    end

    def allow_resource_json?(mtd)
      self.class.allow_resource_json?(mtd)
    end

    def call_resource_json(mtd)
      send(self.class.resource_method_name(mtd))
    end

    def resource_json(options = nil)
      options = options&.dup || {}
      root = if options && options.key?(:root)
        options[:root]
      else
        include_root_in_json
      end

      hash = resource_hash(options).resource_json(options)
      if root
        root = self.class.try(:element_name) || model_name.element if root == true
        { root => hash }
      else
        hash
      end
    end

    def resource_hash(options = nil)
      options = options&.dup || {}
      methods = options.delete(:methods) || []
      includes = options.delete(:include) || []
      hash = serializable_hash(options)

      if self.class._has_attribute?(self.class.inheritance_column)
        hash.update(serializable_attributes([self.class.inheritance_column]))
        hash[self.class.inheritance_column] ||= self.class.name
      end

      resource_json_add_includes(include: includes) do |association, records, opts|
        hash[association.to_s] = if records.respond_to?(:to_ary)
          records.to_ary.map { |a| a.resource_hash(opts) }
        else
          records.resource_hash(opts)
        end
      end

      methods.each do |mtd|
        case mtd
        when :__type__, '__type__' then self.class.name
        when Symbol, String
          m_name = mtd
          prefixed = :"#{resource_methods_prefix}#{mtd}"
          begin
            hash[m_name.to_s] = send(prefixed)
          rescue NoMethodError => e
            if respond_to?(m_name)
              ::ActiveResource::Current.warnings << ResourceJson.rescue_method.call(self, m_name, mtd, e)
            else
              raise NoMethodError, "undefined method `#{m_name}' for #{self.class.name}"
            end
          end
        when Array
          if mtd[0].present?
            mtd_args = mtd.dup
            m_name = mtd_args.shift
            prefixed = :"#{resource_methods_prefix}#{m_name}"
            opts = mtd_args.extract_options!
            begin
              hash[m_name.to_s] = send(prefixed, *mtd_args, **opts)
            rescue NoMethodError => e
              if respond_to?(m_name)
                ::ActiveResource::Current.warnings << ResourceJson.rescue_method.call(self, m_name, mtd, e)
              else
                raise NoMethodError, "undefined method `#{m_name}' for #{self.class.name}"
              end
            end
          end
        end
      end
      hash
    end

    private
    def resource_json_add_includes(options = nil) # :nodoc:
      options = options&.dup || {}
      return unless (includes = options[:include])

      unless includes.is_a?(Hash)
        includes = Hash[Array(includes).flat_map { |n| n.is_a?(Hash) ? n.to_a : [[n, {}]] }]
      end

      includes.each do |association, opts|
        if (records = send(association))
          yield association, records, opts
        end
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include ActiveResource::ResourceJson
  def resource_hash(options = nil)
    hash = super
    hash['__persisted__'] = persisted?
    hash['__type__'] = self.class.name
    hash
  end
end

ActiveSupport.on_load(:active_resource) do
  include ActiveResource::ResourceJson

  def resource_hash(options = nil)
    if extra.present?
      attributes.merge('extra' => extra)
    else
      attributes.dup
    end
  end
end

class Module
  alias resource_json as_json
end

class Object
  def resource_json(options = nil) # :nodoc:
    if respond_to?(:to_hash)
      to_hash.resource_json(options)
    else
      instance_values.resource_json(options)
    end
  end
  def resource_primitive? = false
end

class Struct # :nodoc:
  def resource_json(options = nil)
    Hash[members.zip(values)].resource_json(options)
  end
end

class TrueClass
  alias resource_json as_json
  def resource_primitive? = true
end

class FalseClass
  alias resource_json as_json
  def resource_primitive? = true
end

class NilClass
  alias resource_json as_json
  def resource_primitive? = true
end

class String
  alias resource_json as_json
  def resource_primitive? = true
end

class Symbol
  alias resource_json as_json
  def resource_primitive? = true
end

class Numeric
  alias resource_json as_json
  def resource_primitive? = true
end

class Float
  alias resource_json as_json
  def resource_primitive? = true
end

class BigDecimal
  alias resource_json as_json
  def resource_primitive? = true
end

class Regexp
  alias resource_json as_json
  def resource_primitive? = true
end

module Enumerable
  def resource_json(options = nil) # :nodoc:
    to_a.resource_json(options)
  end
end

class IO
  alias resource_json as_json
end

class Range
  alias resource_json as_json
  def resource_primitive? = true
end

class Array
  def resource_json(options = nil) # :nodoc:
    options = options&.dup || {}
    super_vs = options.delete(:__super_values__) || []
    subset = reject{|v| !v.resource_primitive? && super_vs.include?(v) }
    super_vs += subset.select{|v| !v.resource_primitive? }.uniq
    options[:__super_values__] = super_vs
    subset.map { |v| v.resource_json(options) }
  end
end

class Hash
  def resource_json(options = nil) # :nodoc:
    options = options&.dup || {}

    # create a subset of the hash by applying :only or :except
    subset = if options
      if (attrs = options[:only])
        slice(*Array(attrs))
      elsif (attrs = options[:except])
        except(*Array(attrs))
      else
        self
      end
    else
      self
    end

    super_vs = options.delete(:__super_values__) || []
    subset = subset.reject{|k, v| !v.resource_primitive? && super_vs.include?(v) }
    super_vs += subset.values.select{|v| !v.resource_primitive? }.uniq
    options[:__super_values__] = super_vs

    result = {}
    subset.each do |k, v|
      result[k.to_s] = v.resource_json(options)
    end
    result
  end
end

class Time
  alias resource_json as_json
  def resource_primitive? = true
end

class Date
  alias resource_json as_json
  def resource_primitive? = true
end

class DateTime
  alias resource_json as_json
  def resource_primitive? = true
end

class URI::Generic # :nodoc:
  alias resource_json as_json
  def resource_primitive? = true
end

class Pathname # :nodoc:
  alias resource_json as_json
  def resource_primitive? = true
end

class IPAddr # :nodoc:
  alias resource_json as_json
  def resource_primitive? = true
end

class Process::Status # :nodoc:
  alias resource_json as_json
  def resource_primitive? = true
end

class Exception
  alias resource_json as_json
end

class ActiveSupport::TimeWithZone
  alias resource_json as_json
  def resource_primitive? = true
end
