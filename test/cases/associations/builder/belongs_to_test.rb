# frozen_string_literal: true

require "abstract_unit"

require "fixtures/person"
require "fixtures/beast"
require "fixtures/customer"


class ActiveResource::Associations::Builder::BelongsToTest < ActiveSupport::TestCase
  def setup
    Object.send(:remove_const, :Person) rescue nil
    load 'fixtures/person.rb'
    @klass = ActiveResource::Associations::Builder::BelongsTo
  end


  def test_validations_for_instance
    object = @klass.new(Person, :customer, {})
    assert_equal({}, object.send(:validate_options))
  end

  def test_instance_build
    object = @klass.new(Person, :customer, {})
    Person.expects(:defines_belongs_to_finder_method).with(kind_of(ActiveResource::Reflection::AssociationReflection))

    reflection = object.build

    assert_kind_of ActiveResource::Reflection::AssociationReflection, reflection
    assert_equal :customer, reflection.name
    assert_equal Customer, reflection.klass
    assert_equal "customer_id", reflection.foreign_key
  end


  def test_valid_options
    assert @klass.build(Person, :customer, class_name: "Person")
    assert @klass.build(Person, :customer, foreign_key: "person_id")

    assert_raise ArgumentError do
      @klass.build(Person, :customer, soo_invalid: true)
    end
  end

  def test_polymorphic
    object = @klass.new(Person, :customer, polymorphic: true)
    reflection = object.build
    resource1 = Person.new(customer_type: 'Beast', customer_id: 111)
    assert_equal 'Beast', reflection.class_name(resource: resource1)
    resource2 = Person.new(customer_type: 'Person', customer_id: 112)
    assert_equal 'Person', reflection.class_name(resource: resource2)
  end
end
