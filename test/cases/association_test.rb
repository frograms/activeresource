# frozen_string_literal: true

require "abstract_unit"

require "fixtures/person"
require "fixtures/beast"
require "fixtures/customer"
require "fixtures/post"


class AssociationTest < ActiveSupport::TestCase
  def setup
    Object.send(:remove_const, :Person) rescue nil
    External.send(:remove_const, :Person) rescue nil if defined?(External)
    load 'fixtures/person.rb'
    @klass = ActiveResource::Associations::Builder::Association
    @reflection = ActiveResource::Reflection::AssociationReflection.new Person, :belongs_to, :customer, {}
    @reflection_polymorphic = ActiveResource::Reflection::AssociationReflection.new Person, :belongs_to, :customer, {polymorphic: true}
  end


  def test_validations_for_instance
    object = @klass.new(Person, :customers, {})
    assert_equal({}, object.send(:validate_options))
  end

  def test_instance_build
    object = @klass.new(Person, :customers, {})
    assert_kind_of ActiveResource::Reflection::AssociationReflection, object.build
  end

  def test_valid_options
    assert @klass.build(Person, :customers, class_name: "Client")

    assert_raise ArgumentError do
      @klass.build(Person, :customers, soo_invalid: true)
    end
  end

  def test_association_class_build
    assert_kind_of ActiveResource::Reflection::AssociationReflection, @klass.build(Person, :customers, {})
  end

  def test_has_many
    External::Person.send(:has_many, :people)
    assert_equal 1, External::Person.reflections.select { |name, reflection| reflection.macro.eql?(:has_many) }.count
  end

  def test_has_many_on_new_record
    Post.send(:has_many, :topics)
    Topic.stubs(:find).returns([:unexpected_response])
    assert_equal [], Post.new.topics.to_a
  end

  def test_has_one
    External::Person.send(:has_one, :customer)
    assert_equal 1, External::Person.reflections.select { |name, reflection| reflection.macro.eql?(:has_one) }.count
  end

  def test_belongs_to
    External::Person.belongs_to(:customer)
    assert_equal 1, External::Person.reflections.select { |name, reflection| reflection.macro.eql?(:belongs_to) }.count
    assert External::Person.schema.attrs.key?(:customer_id)
    person = External::Person.new
    assert person.respond_to?(:customer_id)
    assert person.respond_to?(:customer_id=)
    customer = External::Person.new(id: 10)
    assert person.respond_to?(:customer=)
    person.customer = customer
    assert person.instance_variable_defined?(:@customer)
    assert person.respond_to?(:customer)
    assert_equal customer, person.customer
    assert_equal 10, person.customer_id
  end

  def test_belongs_to_polymorphic
    External::Person.belongs_to(:customer, polymorphic: true)
    assert External::Person.schema.attrs.key?(:customer_id)
    assert External::Person.schema.attrs.key?(:customer_type)
    person = External::Person.new
    assert person.respond_to?(:customer_type)
    assert person.respond_to?(:customer_type=)
    customer = External::Person.new(id: 10)
    person.customer = customer
    assert_equal 10, person.customer_id
    assert_equal 'External::Person', person.customer_type
  end

  def test_defines_belongs_to_finder_method_with_instance_variable_cache
    Person.defines_belongs_to_finder_method(@reflection)

    person = Person.new
    assert_not person.instance_variable_defined?(:@customer)
    person.stubs(:customer_id).returns(2)
    Customer.expects(:find).with(:first, {params: {'id' => 2}}.with_indifferent_access).once()
    2.times { person.customer }
    assert person.instance_variable_defined?(:@customer)
  end

  def test_belongs_to_writer
    Person.defines_belongs_to_finder_method(@reflection)
    person = Person.new
    customer = Person.new(id: 10)
    person.customer = customer
    assert_equal 10, person.customer_id
  end

  def test_defines_belongs_to_polymorphic_finder_method_with_instance_variable_cache
    Person.defines_belongs_to_finder_method(@reflection_polymorphic)

    person = Person.new
    assert_not person.instance_variable_defined?(:@customer)
    person.stubs(:customer_id).returns(2)
    person.stubs(:customer_type).returns('Customer')
    Customer.expects(:find).with(:first, {params: {'id' => 2}}.with_indifferent_access).once()
    2.times { person.customer }
    assert person.instance_variable_defined?(:@customer)
  end

  def test_belongs_to_with_finder_key
    Person.defines_belongs_to_finder_method(@reflection)

    person = Person.new
    person.stubs(:customer_id).returns(1)
    Customer.expects(:find).with(:first, {params: {'id' => 1}}.with_indifferent_access).once()
    person.customer
  end

  def test_belongs_to_with_nil_finder_key
    Person.defines_belongs_to_finder_method(@reflection)

    person = Person.new
    person.stubs(:customer_id).returns(nil)
    Customer.expects(:find).with(nil).never()
    person.customer
  end

  def test_inverse_associations_do_not_create_circular_dependencies
    code = <<-CODE
      class Park < ActiveResource::Base
        has_many :trails
      end

      class Trail < ActiveResource::Base
        belongs_to :park
      end
    CODE

    assert_nothing_raised do
      eval code
    end
  end
end
