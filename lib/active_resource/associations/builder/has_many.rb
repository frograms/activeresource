# frozen_string_literal: true

module ActiveResource::Associations::Builder
  class HasMany < Association
    self.valid_options += [:foreign_key, :foreign_type, :as, :params_opts, :getter]
    self.valid_options += [:extra, :schema]

    self.macro = :has_many

    def build
      validate_options
      model.create_reflection(self.class.macro, name, options).tap do |reflection|
        model.defines_has_many_finder_method(reflection)
      end
    end
  end
end
