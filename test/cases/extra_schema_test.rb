# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"
require "fixtures/project"
require "active_support/json"
require "active_support/core_ext/hash/conversions"
require "mocha/minitest"

class ExtraSchemaTest < ActiveSupport::TestCase
  def setup
    setup_response # find me in abstract_unit
  end

  def teardown
    Object.send(:remove_const, :Project)
    load("fixtures/project.rb")
  end

  def test_extra
    Project.schema do
      string :desc, extra: true
    end
    p = Project.find(11)
    assert p.desc, "make a nuke"
  end

  def test_extra_without_default_request
    Project.schema do
      string :desc, extra: {default_request: false}
    end
    p = Project.find(11)
    assert p.extra.has_key?(:desc) == false
    assert p.desc == "make a nuke"
  end
end
