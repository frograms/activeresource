# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"
require "fixtures/project"
require "active_support/json"
require "active_support/core_ext/hash/conversions"
require "mocha/minitest"

class SchemaTest < ActiveSupport::TestCase
  setup do
    Object.send(:remove_const, :Project)
    load("fixtures/project.rb")
    setup_response # find me in abstract_unit
  end

  def test_schema
    Project.schema do
      string :desc
    end

    Person.schema do
      string :name
    end

    Object.const_set(:ProjectSub, Class.new(Project))

    ProjectSub.schema do
      string :desc_sub
    end

    assert_equal %w[id email name desc], Project.schema.attrs.keys
    assert_equal %w[id name], Person.schema.attrs.keys
    assert_equal %w[id email name desc desc_sub], ProjectSub.schema.attrs.keys

    Project.schema do
      string :added_attr
    end

    assert_equal %w[id email name desc added_attr], Project.schema.attrs.keys
    assert_equal %w[id email name desc desc_sub added_attr], ProjectSub.schema.attrs.keys

    p = Project.new(added_attr: '123')
    ps = ProjectSub.new(added_attr: '234')
    assert_equal '123', p.added_attr
    assert_equal '234', ps.added_attr

    Object.send(:remove_const, :ProjectSub)
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

  def test_include_association_extra
    Person.has_many :projects
    Project.schema do
      string :desc, extra: true
      datetime :due, extra: {default_request: false}
    end

    person = Person.where(id: 2).includes(:projects).first
    assert_kind_of Person, person
    assert_equal person.attributes.keys, %w[id name projects]
    assert_kind_of Project, person.attributes['projects'].first # preloaded

    p = person.projects.first
    assert_equal p.extra.keys, %w[desc]
    assert !p.extra.key?('due')
    p.load_extra
    assert_equal p.due, Time.parse('2023-02-23 02:40:00 +0000')
  ensure
    Person.reflections = {}.with_indifferent_access
  end
end
