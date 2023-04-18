module ActiveResource
  class Current < ActiveSupport::CurrentAttributes
    attribute :warnings

    resets do
      self.warnings = []
    end

    def initialize
      @attributes = {warnings: []}
    end
  end
end
