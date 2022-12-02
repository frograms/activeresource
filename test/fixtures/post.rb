# frozen_string_literal: true

class Post < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"

  belongs_to :person
  belongs_to :project, polymorphic: true
end
