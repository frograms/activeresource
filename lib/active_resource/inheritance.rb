module ActiveResource
  module Inheritance
    extend ActiveSupport::Concern

    class_methods do
      def polymorphic_name
        ApiTypeNameObjectMap.find_api_type_name(self)
      end
    end
  end
end
