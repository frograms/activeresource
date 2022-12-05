module ActiveResource
  module ResourceJson
    extend ActiveSupport::Concern

    def resource_json(options = nil)
      root = if options && options.key?(:root)
        options[:root]
      else
        include_root_in_json
      end

      hash = resource_hash(options).resource_json
      if root
        root = model_name.element if root == true
        { root => hash }
      else
        hash
      end
    end

    def resource_hash(options = nil)
      hash = serializable_hash(options)
      if self.class._has_attribute?(self.class.inheritance_column)
        hash.update(serializable_attributes([self.class.inheritance_column]))
      end
      hash
    end

    def resource_extra_methods
      []
    end

    def resource_filter_extra(*args)
      resource_extra_methods & args.reject(&blank?).map(&:to_sym)
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include ActiveResource::ResourceJson
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
end

class Struct # :nodoc:
  def resource_json(options = nil)
    Hash[members.zip(values)].resource_json(options)
  end
end

class TrueClass
  alias resource_json as_json
end

class FalseClass
  alias resource_json as_json
end

class NilClass
  alias resource_json as_json
end

class String
  alias resource_json as_json
end

class Symbol
  alias resource_json as_json
end

class Numeric
  alias resource_json as_json
end

class Float
  alias resource_json as_json
end

class BigDecimal
  alias resource_json as_json
end

class Regexp
  alias resource_json as_json
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
end

class Array
  def resource_json(options = nil) # :nodoc:
    map { |v| options ? v.resource_json(options.dup) : v.resource_json }
  end
end

class Hash
  def resource_json(options = nil) # :nodoc:
    # create a subset of the hash by applying :only or :except
    subset = if options
      if attrs = options[:only]
        slice(*Array(attrs))
      elsif attrs = options[:except]
        except(*Array(attrs))
      else
        self
      end
    else
      self
    end

    result = {}
    subset.each do |k, v|
      result[k.to_s] = options ? v.resource_json(options.dup) : v.resource_json
    end
    result
  end
end

class Time
  alias resource_json as_json
end

class Date
  alias resource_json as_json
end

class DateTime
  alias resource_json as_json
end

class URI::Generic # :nodoc:
  alias resource_json as_json
end

class Pathname # :nodoc:
  alias resource_json as_json
end

class IPAddr # :nodoc:
  alias resource_json as_json
end

class Process::Status # :nodoc:
  alias resource_json as_json
end

class Exception
  alias resource_json as_json
end

class ActiveSupport::TimeWithZone
  alias resource_json as_json
end
