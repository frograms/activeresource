module ActiveResource
  module RuntimeRegistry
    extend self

    def warnings
      ActiveSupport::IsolatedExecutionState[:active_resource_warnings] ||= []
    end
  end
end
