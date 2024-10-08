# frozen_string_literal: true

class SubscriptionPlan < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  self.element_name = "plan"
  self.primary_key = :code

  schema do
    string :code
  end
end
