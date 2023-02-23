# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"
require "fixtures/project"
require "active_support/json"
require "active_support/core_ext/hash/conversions"
require "mocha/minitest"

class ExtraSchemaTest < ActiveSupport::TestCase
  setup do
    Object.send(:remove_const, :Project)
    load("fixtures/project.rb")
    setup_response # find me in abstract_unit
  end

  def test_extra
    Project.schema do
      string :desc, extra: true
    end
    p = Project.find(11)
    assert_equal p.desc, "make a nuke"
    p1 = Project.new(desc: 'bomb')
    assert_equal p1.desc, 'bomb'
    assert_equal p1.extra['desc'], 'bomb'
    p1.desc = 'dismantling'
    assert_equal p1.desc, 'dismantling'
    assert_equal p1.extra['desc'], 'dismantling'
  end

  def test_extra_without_default_request
    Project.schema do
      string :desc, extra: {default_request: false}
    end
    p = Project.find(11)
    assert p.extra.has_key?(:desc) == false
    assert p.desc == "make a nuke"
  end

  def test_reload
    Project.schema do
      string :desc, extra: {default_request: false}
    end
    p = Project.find(11)
    p.reload(extra: %w[desc])
    assert p.extra.has_key?(:desc)
    assert p.extra['desc'] == "make a nuke"
  end

  def test_load_extra
    Project.schema do
      string :desc, extra: true
      datetime :due, extra: {default_request: false}
    end
    p = Project.find(11)
    assert_equal p.desc, 'make a nuke'
    assert !p.extra.key?('due')
    p.load_extra
    assert_equal p.due, Time.parse('2023-02-23 02:40:00 +0000')
  end
end
