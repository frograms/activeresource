require 'active_support/hash_with_indifferent_access'

module ActiveResource
  class TypeNotFound < ActiveResource::Error; end

  module ApiTypeNameObjectMap
    @object_map = {}.with_indifferent_access
    @api_type_name_map = {}

    @object_fallback = proc do |api_type_name|
      api_type_name.constantize
    end

    @api_type_name_fallback = proc do |object|
      object.class.name
    end

    @object_map.instance_eval do
      alias _set_ []=
      def []=(*, **)
        raise NoMethodError, 'use ApiTypeNameObjectMap.set'
      end
    end
    @api_type_name_map.instance_eval do
      alias _set_ []=
      def []=(*, **)
        raise NoMethodError, 'use ApiTypeNameObjectMap.set'
      end
    end

    class Duplicated < ActiveResource::Error; end

    class << self
      def set(api_type_name, object)
        if @object_map.key?(api_type_name)
          raise Duplicated, "#{api_type_name} already mapped on #{object.name}"
        end
        if !object.nil? && @api_type_name_map.key?(object)
          raise Duplicated, "#{object.name} already mapped on #{api_type_name}"
        end
        @object_map._set_(api_type_name, object)
        @api_type_name_map._set_(object, api_type_name.to_s)
      end

      def find_object(api_type_name)
        if @object_map.key?(api_type_name)
          return @object_map[api_type_name]
        end
        begin
          @object_fallback.call(api_type_name)
        rescue NameError
          nil
        end
      end

      def object_fallback(&block)
        @object_fallback = block
      end

      def find_api_type_name(object)
        if @api_type_name_map.key?(object)
          return @api_type_name_map[object]
        end
        @api_type_name_fallback.call(object)
      end

      def api_type_name_fallback(&block)
        @api_type_name_fallback = block
      end
    end
  end
end
