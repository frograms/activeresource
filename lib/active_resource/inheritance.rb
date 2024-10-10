module ActiveResource
  module Inheritance
    extend ActiveSupport::Concern

    class_methods do
      def polymorphic_name
        RecordMap.record_base_name(self)
      end
    end
  end
end
