# frozen_string_literal: true

require "active_support/core_ext/class/attribute"
require "active_support/core_ext/module/deprecation"

module ActiveResource
  # = Active Resource reflection
  #
  # Associations in ActiveResource would be used to resolve nested attributes
  # in a response with correct classes.
  # Now they could be specified over Associations with the options :class_name
  module Reflection # :nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :reflections
      self.reflections = {}.with_indifferent_access
    end

    module ClassMethods
      def create_reflection(macro, name, options)
        reflection = AssociationReflection.new(self, macro, name, options)
        self.reflections = self.reflections.merge(name => reflection)
        reflection
      end

      def reflections_of(macro: nil)
        ref = reflections
        ref = ref.select{|k, v| v.macro == macro} if macro
        ref
      end
    end


    class AssociationReflection
      def initialize(resource_class, macro, name, options)
        @resource_class, @macro, @name, @options = resource_class, macro, name, options
      end

      attr_reader :resource_class

      # Returns the name of the macro.
      #
      # <tt>has_many :clients</tt> returns <tt>:clients</tt>
      attr_reader :name

      # Returns the macro type.
      #
      # <tt>has_many :clients</tt> returns <tt>:has_many</tt>
      attr_reader :macro

      # Returns the hash of options used for the macro.
      #
      # <tt>has_many :clients</tt> returns +{}+
      attr_reader :options

      # Returns the class for the macro.
      #
      # <tt>has_many :clients</tt> returns the Client class
      def klass(resource: nil)
        c_name = class_name(resource: resource)
        @klass = ActiveResource.api_type_name_object_map.find_object(c_name)
        @klass ||= c_name.constantize
      end

      # Returns the class name for the macro.
      #
      # <tt>has_many :clients</tt> returns <tt>'Client'</tt>
      def class_name(resource: nil)
        if options[:polymorphic] == true && resource.respond_to?(foreign_type)
          resource.send(foreign_type)
        else
          @class_name ||= derive_class_name(resource: resource)
        end
      end

      # Returns the foreign_key for the macro.
      def foreign_key
        @foreign_key ||= derive_foreign_key
      end

      def foreign_type
        @foreign_type ||= derive_foreign_type
      end

      def join_foreign_key
        @join_foreign_key ||= klass.primary_key
      end

      private
        def derive_class_name(resource: nil)
          if options[:class_name]
            options[:class_name].to_s.camelize
          else
            name.to_s.classify
          end
        end

        def derive_foreign_key
          return options[:foreign_key] if options[:foreign_key]
          case macro
          when :has_many
            if options[:as]
              "#{options[:as]}_id"
            else
              "#{resource_class.model_name.element}_id"
            end
          else
            "#{name.to_s.downcase}_id"
          end
        end

        def derive_foreign_type
          return options[:foreign_type] if options[:foreign_type]
          case macro
          when :has_many
            if options[:as]
              "#{options[:as]}_type"
            else
              "#{resource_class.model_name.element}_type"
            end
          else
            "#{name.to_s.downcase}_type"
          end
        end
    end
  end
end
