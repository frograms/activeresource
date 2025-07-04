require 'active_record/scoping'

module ActiveResource
  module ActAsActiveRecord
    class ArelTable
      def name; 'activeresource' end
    end

    extend ActiveSupport::Concern

    include ActiveRecord::Scoping

    class_methods do
      def current_scope
        self
      end

      def relation_delegate_class(klass)
        ActiveResource::Delegation
      end

      def scope_for_association
        ActiveResource::Delegation
      end

      # AssociationScope#scope
      def unscoped
        self
      end

      # AssociationScope#scope
      def alias_tracker
        nil
      end

      # AssociationScope#scope
      def extending!(arg)
        nil
      end

      # active_record/reflection
      def arel_table
        ArelTable.new
      end

      # Association#scope
      def table
        nil
      end

      def table_name
        @table_name ||= 'activeresources'
      end

      # Association#apply_scope
      def where!(opts, *rest)
        self
      end

      # Association#scope
      def limit!(value)
        self
      end

      def has_query_constraints?
        false
      end

      def composite_primary_key?
        false
      end
    end

    def strict_loading?
      false
    end
  end
end