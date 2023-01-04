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

    object_map.instance_eval do
      alias _set_ []=
      def []=(*, **)
        raise NoMethodError, 'use ApiTypeNameObjectMap.set'
      end
    end
    api_type_name_map.instance_eval do
      alias _set_ []=
      def []=(*, **)
        raise NoMethodError, 'use ApiTypeNameObjectMap.set'
      end
    end

    class Duplicated < ActiveResource::Error; end

    class << self
      def set(api_type_name, object)
        if object_map.key?(api_type_name)
          raise Duplicated, "#{api_type_name} already mapped on #{object}"
        end
        if !object.nil? && api_type_name_map.key?(object)
          raise Duplicated, "#{object} already mapped on #{api_type_name}"
        end
        object_map._set_(api_type_name, object)
        api_type_name_map._set_(object, api_type_name.to_s)
      end

      def multi_set(hash)
        hash.each_pair do |api_type_name, object|
          set(api_type_name, object)
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
    end
  end
end
