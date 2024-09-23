require 'active_support/hash_with_indifferent_access'

module ActiveResource
  class TypeNotFound < ActiveResource::Error; end

  class << self
    def api_type_name_object_map
      ApiTypeNameObjectMap
    end

    def map_object(api_type_name)
      api_type_name_object_map.find_object(api_type_name)
    end

    def map_api_type_name(object)
      api_type_name_object_map.find_api_type_name(object)
    end
  end

  module ApiTypeNameObjectMap
    mattr_reader :object_map, default: {}.with_indifferent_access
    mattr_reader :api_type_name_map, default: {}
    mattr_reader :_object_fallback, default: proc { |api_type_name| api_type_name.constantize }
    mattr_reader :_api_type_name_fallback, default: proc { |object_name| object_name }

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

      def find_object(api_type_name)
        if object_map.key?(api_type_name)
          return object_map[api_type_name]&.constantize
        end
        begin
          _object_fallback.call(api_type_name)
        rescue NameError
          nil
        end
      end

      def find_object_namespace_fallback(api_type_name)
        if object_map.key?(api_type_name)
          object_map[api_type_name]&.constantize
        else
          ancestors = api_type_name.split('::')
          if ancestors.size > 1
            find_object_namespace_fallback(ancestors[0..-2].join('::'))
          else
            nil
          end
        end
      end

      def find_object!(api_type_name)
        object = find_object(api_type_name)
        raise TypeNotFound, "Object not found: api_type_name=#{api_type_name}" unless object
        object
      end

      def find_instance!(api_type_name, id)
        object = find_object!(api_type_name)
        object < ActiveRecord::Base ? object.find_by_id(id) : object.new(id: id, persisted: true)
      end

      def object_fallback(&block)
        @@object_fallback = block
      end

      def find_api_type_name(object)
        if object.is_a?(Class)
          object = object.respond_to?(:base_class) ? object.base_class.name : object.name
        elsif !object.is_a?(String)
          return find_api_type_name(object.class)
        end
        if api_type_name_map.key?(object)
          return api_type_name_map[object]
        end
        _api_type_name_fallback.call(object)
      end

      def api_type_name_fallback(&block)
        @@api_type_name_fallback = block
      end

      def api_type_name_of(object)
        if object.is_a?(Class)
          name = object.name
        else
          if object.is_a?(String)
            name = object
          else
            return api_type_name_of(object.class)
          end
        end
        if api_type_name_map.key?(name)
          return api_type_name_map[name]
        end
        if object.is_a?(Class) && object.superclass < ActiveRecord::Base
          api_type_name_of(object.superclass)
        else
          find_api_type_name(object)
        end
      end
    end
  end

  module ApiTypeName
    extend ActiveSupport::Concern

    class_methods do
      def api_type_name
        ActiveResource.api_type_name_object_map.find_api_type_name(self)
      end
    end

    def api_type_name
      self.class.api_type_name
    end
  end

  ActiveSupport.on_load(:active_record) do
    include ActiveResource::ApiTypeName
  end
end
