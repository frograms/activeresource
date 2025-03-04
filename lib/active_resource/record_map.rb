require 'active_support/hash_with_indifferent_access'

module ActiveResource
  class TypeNotFound < ActiveResource::Error; end

  class << self
    def api_type_name_object_map
      ActiveSupport.deprecator.warn("api_type_name_object_map is deprecated. Use record_map instead.")
      record_map
    end

    def record_map
      RecordMap
    end

    def map_object(api_type_name)
      ActiveSupport.deprecator.warn("map_object is deprecated. Use record_map.resource_class instead.")
      record_map.resource_class(api_type_name)
    end

    def map_api_type_name(object)
      ActiveSupport.deprecator.warn("map_api_type_name is deprecated. Use record_map.record_base_name instead.")
      record_map.record_base_name(object)
    end

    def to_record(resource)
      return resource if resource.is_a?(ActiveRecord::Base) || (resource.is_a?(Class) && resource < ActiveRecord::Base)
      record_base_name = record_map.record_base_name(resource)
      if resource.is_a?(ActiveResource::Base)
        record_base_name&.constantize&.find_by(id: resource.id)
      else
        record_base_name
      end
    end

    def to_resource(record)
      return record if record.is_a?(ActiveResource::Base) || (record.is_a?(Class) && record < ActiveResource::Base)
      resource_class = record_map.resource_class(record)
      if record.is_a?(ActiveRecord::Base)
        resource_class&.new(**record.attributes)
      else
        resource_class
      end
    end
    alias_method :[], :to_resource
  end

  module RecordMap
    mattr_reader :object_map, default: {}.with_indifferent_access
    mattr_reader :api_type_name_map, default: {}
    mattr_accessor :_object_fallback, default: proc { |api_type_name| api_type_name.constantize }
    mattr_accessor :_api_type_name_fallback, default: proc { |object_name| object_name }

    def self.makeup_map_hash(hash)
      hash.instance_eval do
        alias _set_ []=
        def []=(*, **)
          raise NoMethodError, 'use ApiTypeNameObjectMap.set'
        end
      end
    end

    makeup_map_hash(object_map)
    makeup_map_hash(api_type_name_map)

    class Duplicated < ActiveResource::Error; end

    class << self
      def set(api_type_name, object)
        if object_map.key?(api_type_name)
          unless object_map[api_type_name].instance_variable_get(:@__armap_default__)
            raise Duplicated, "#{api_type_name} already mapped on #{object}"
          end
        end
        if !object.nil? && api_type_name_map.key?(object)
          unless api_type_name_map[object].instance_variable_get(:@__armap_default__)
            raise Duplicated, "#{object} already mapped on #{api_type_name}"
          end
        end
        object_map._set_(api_type_name, object)
        api_type_name_map._set_(object, api_type_name.to_s)
      end

      def multi_set(hash)
        hash.each_pair do |api_type_name, object|
          set(api_type_name, object)
        end
      end

      def default_multi_set(hash)
        hash.each_pair do |api_type_name, object|
          atn = api_type_name.dup
          atn.instance_variable_set(:@__armap_default__, true)
          obj = object.dup
          obj.instance_variable_set(:@__armap_default__, true)
          set(atn, obj)
        end
      end

      def class_base_name(some)
        if some.is_a?(Class)
          some = (some < ActiveRecord::Base || some < ActiveResource::Base) ? some.base_class.name : some.name
        elsif some.is_a?(ActiveRecord) || some.is_a?(ActiveResource)
          some = some.class.base_class.name
        elsif !some.is_a?(String)
          return class_base_name(some.class)
        end
        some
      end

      def class_name(some)
        if some.is_a?(Class)
          some = some.name
        elsif some.is_a?(ActiveRecord) || some.is_a?(ActiveResource)
          some = some.class.name
        elsif !some.is_a?(String)
          return class_name(some.class)
        end
        some
      end

      def find_object(api_type_name)
        ActiveSupport.deprecator.warn("find_object is deprecated. Use resource_class(record) instead.")
        resource_class(api_type_name)
      end

      def resource_class(record_name)
        record_name = class_base_name(record_name)
        if object_map.key?(record_name)
          return object_map[record_name]&.constantize rescue nil
        end
        begin
          _object_fallback.call(record_name)
        rescue NameError
          nil
        end
      end

      def find_object_namespace_fallback(api_type_name)
        ActiveSupport.deprecator.warn("find_object is deprecated. Use resource_class_namespace_fallback instead.")
        resource_class_namespace_fallback(api_type_name)
      end

      def resource_class_namespace_fallback(record_name)
        record_name = class_base_name(record_name)
        if object_map.key?(record_name)
          object_map[record_name]&.constantize rescue nil
        else
          ancestors = record_name.split('::')
          if ancestors.size > 1
            resource_class_namespace_fallback(ancestors[0..-2].join('::'))
          else
            nil
          end
        end
      end

      def find_object!(api_type_name)
        ActiveSupport.deprecator.warn("find_object! is deprecated. Use resource_class!(record) instead.")
        resource_class!(api_type_name)
      end

      def resource_class!(record_name)
        resource_class = resource_class(record_name)
        raise TypeNotFound, "Object not found: record_name=#{record_name}" unless resource_class
        resource_class
      end

      def find_instance!(api_type_name, id)
        resource_class = resource_class!(api_type_name)
        resource_class < ActiveRecord::Base ? resource_class.find_by_id(id) : resource_class.new(id: id, persisted: true)
      end

      def object_fallback(&block)
        ActiveSupport.deprecator.warn("object_fallback is deprecated. Use _object_fallback instead.")
        @@object_fallback = block
      end

      def find_api_type_name(object)
        ActiveSupport.deprecator.warn("find_api_type_name is deprecated. Use find_record_base_name(record) instead.")
        record_base_name(object)
      end


      def record_base_name(resource)
        name = class_base_name(resource)
        if api_type_name_map.key?(name)
          return api_type_name_map[name]
        end
        _api_type_name_fallback.call(name)
      end

      def api_type_name_fallback(&block)
        ActiveSupport.deprecator.warn("api_type_name_fallback is deprecated. Use _api_type_name_fallback instead.")
        @@api_type_name_fallback = block
      end

      def api_type_name_of(object)
        ActiveSupport.deprecator.warn("api_type_name_of is deprecated. Use record_name(record) instead.")
        record_name(object)
      end

      def record_name(resource)
        name = class_name(resource)
        if api_type_name_map.key?(name)
          return api_type_name_map[name]
        end
        resource_class = resource.is_a?(Class) ? resource : resource.class
        if resource_class.superclass < ActiveResource::Base
          record_name(resource_class.superclass)
        end
      end
    end

    module RecordHelper
      extend ActiveSupport::Concern

      class_methods do
        def api_type_name
          ActiveSupport.deprecator.warn("api_type_name is deprecated. use record_base_name")
          record_base_name
        end

        def record_base_name
          base_class.name
        end

        def to_resource
          ActiveResource[self]
        end
      end

      def api_type_name
        self.class.api_type_name
      end

      def record_base_name
        self.class.record_base_name
      end

      def to_resource
        ActiveResource[self]
      end
    end

    module ResourceHelper
      extend ActiveSupport::Concern

      class_methods do
        def api_type_name
          ActiveSupport.deprecator.warn("api_type_name is deprecated. Use record_base_name")
          record_base_name
        end

        def record_base_name
          ActiveResource.record_map.record_base_name(self)
        end

        def to_record
          ActiveResource.to_record(self)
        end
      end

      def api_type_name
        ActiveSupport.deprecator.warn("api_type_name is deprecated. Use record_base_name")
        record_base_name
      end

      def record_base_name
        self.class.record_base_name
      end

      def to_record
        ActiveResource.to_record(self)
      end
    end
  end

  ActiveSupport.on_load(:active_record) do
    include ActiveResource::RecordMap::RecordHelper
  end

  ApiTypeNameObjectMap = RecordMap
  ApiTypeName = RecordMap::ResourceHelper
end
