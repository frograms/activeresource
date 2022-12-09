# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/hash/conversions"
require "fixtures/person"
require "fixtures/street_address"

########################################################################
# Testing the schema of your Active Resource models
########################################################################
class SchemaTest < ActiveSupport::TestCase
  def setup
    Object.send(:remove_const, :Person) rescue nil
    load 'fixtures/person.rb'
    setup_response # find me in abstract_unit
  end

  def teardown
    Person.schema = nil # hack to stop test bleedthrough...
  end


  #####################################################
  # Passing in a schema directly and returning it
  ####

  test "schema on a new model should be empty" do
    assert_equal({'id' => 'integer'}, Person.schema.attrs_type_name)
    assert_equal({'id' => 'integer'}, Person.new.schema.attrs_type_name)
  end

  test "schema should only accept a hash" do
    ["blahblah", ["one", "two"],  [:age, :name], Person.new].each do |bad_schema|
      assert_raises(ArgumentError, "should only accept a hash (or nil), but accepted: #{bad_schema.inspect}") do
        Person.schema = bad_schema
      end
    end
  end

  test "schema should accept a simple hash" do
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised { Person.schema = new_schema }
    assert_equal new_schema.merge('id' => 'integer'), Person.schema.attrs_type_name
  end

  test "schema should accept a hash with simple values" do
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised { Person.schema = new_schema }
    assert_equal new_schema.merge({'id' => 'integer'}), Person.schema.attrs_type_name
  end

  test "schema should accept all known attribute types as values" do
    ActiveResource::Schema.known_attribute_types.each_with_index do |the_type, ix|
      assert_nothing_raised { Person.schema = { "my_key#{ix}" => the_type } }
    end
  end

  test "schema should not accept unknown values" do
    bad_values = [ :oogle, :blob, "thing"]

    bad_values.each do |bad_value|
      assert_raises(ArgumentError, "should only accept a known attribute type, but accepted: #{bad_value.inspect}") do
        Person.schema = { "key" => bad_value }
      end
    end
  end

  test "schema should accept nil and remove the schema" do
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised { Person.schema = new_schema }
    assert_equal new_schema.merge('id' => 'integer'), Person.schema.attrs_type_name # sanity check

    assert_nothing_raised { Person.schema = nil }
    assert_equal({'id' => 'integer'}, Person.schema.attrs_type_name)
  end

  test "schema should be with indifferent access" do
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    new_schema_syms = new_schema.keys

    assert_nothing_raised { Person.schema = new_schema }
    new_schema_syms.each do |col|
      assert Person.new.respond_to?(col.to_s), "should respond to the schema's string key, but failed on: #{col}"
      assert Person.new.respond_to?(col.to_sym), "should respond to the schema's symbol key, but failed on: #{col.to_sym}"
    end
  end

  test "schema on a fetched resource should return all the attributes of that model instance" do
    Person.schema do
      string 'name'
    end
    p = Person.find(1)
    s = p.schema

    assert s.present?, "should have found a non-empty schema!"

    p.attributes.each do |the_attr, val|
      assert s.has_key?(the_attr), "should have found attr: #{the_attr} in schema, but only had: #{s.inspect}"
    end
  end

  test "with two instances, default schema should match the attributes of the individual instances - even if they differ" do
    skip 'different schema?'
    matz = Person.find(1)
    rick = Person.find(6)

    m_attrs = matz.attributes.keys.sort
    r_attrs = rick.attributes.keys.sort

    assert_not_equal m_attrs, r_attrs, "should have different attributes on each model"

    assert_not_equal matz.schema, rick.schema, "should have had different schemas too"
  end

  test "defining a schema should return it when asked" do
    # assert Person.schema.blank?, "should have a blank class schema"
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised {
      Person.schema = new_schema
      assert_equal new_schema.merge('id' => 'integer'), Person.schema.attrs_type_name, "should have saved the schema on the class"
      assert_equal new_schema.merge('id' => 'integer'), Person.new.schema.attrs_type_name, "should have made the schema available to every instance"
    }
  end

  test "defining a schema, then fetching a model should still match the defined schema" do
    skip "class-level schema, instance-level attributes"
    # sanity checks
    assert Person.schema.blank?, "should have a blank class schema"
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    matz = Person.find(1)
    assert_not matz.schema.blank?, "should have some sort of schema on an instance variable"
    assert_not_equal new_schema, matz.schema, "should not have the class-level schema until it's been added to the class!"

    assert_nothing_raised {
      Person.schema = new_schema
      assert_equal new_schema, matz.schema, "class-level schema should override instance-level schema"
    }
  end


  #####################################################
  # Using the schema syntax
  ####

  test "should be able to use schema" do
    assert_respond_to Person, :schema, "should at least respond to the schema method"

    assert_nothing_raised do
      Person.schema { }
    end
  end

  test "schema definition should store and return attribute set" do
    assert_nothing_raised do
      s = nil
      Person.schema do
        s = self
        attribute :foo, :string
      end
      assert_respond_to s, :attrs, "should return attributes in theory"
      assert_equal({ "foo" => "string", 'id' => 'integer' }, s.attrs_type_name, "should return attributes in practice")
    end
  end

  test "should be able to add attributes through schema" do
    assert_nothing_raised do
      s = nil
      Person.schema do
        s = self
        attribute("foo", "string")
      end
      assert s.attrs.has_key?("foo"), "should have saved the attribute name"
      assert_equal "string", s.attrs["foo"].name.to_s, "should have saved the attribute type"
    end
  end

  test "should convert symbol attributes to strings" do
    assert_nothing_raised do
      s = nil
      Person.schema do
        s = self
        attribute(:foo, :integer)
      end

      assert s.attrs.has_key?("foo"), "should have saved the attribute name as a string"
      assert_equal "integer", s.attrs["foo"].name.to_s, "should have saved the attribute type as a string"
    end
  end

  test "should be able to add all known attribute types" do
    assert_nothing_raised do
      ActiveResource::Schema.known_attribute_types.each_with_index do |the_type, ix|
        s = nil
        Person.schema do
          s = self
          attribute("foo#{ix}", the_type)
        end
        assert s.attrs.has_key?("foo#{ix}"), "should have saved the attribute name"
        assert_equal the_type.to_s, s.attrs["foo#{ix}"].name.to_s, "should have saved the attribute type of: #{the_type}"
      end
    end
  end

  test "attributes should not accept unknown values" do
    bad_values = [ :oogle, :blob, "thing"]

    bad_values.each do |bad_value|
      assert_raises(ArgumentError, "should only accept a known attribute type, but accepted: #{bad_value.inspect}") do
        Person.schema do
          attribute "key", bad_value
        end
      end
      assert_not self.respond_to?(bad_value), "should only respond to a known attribute type, but accepted: #{bad_value.inspect}"
      assert_raises(NoMethodError, "should only have methods for known attribute types, but accepted: #{bad_value.inspect}") do
        Person.schema do
          send bad_value, "key"
        end
      end
    end
  end

  test "should accept attribute types as the type's name as the method" do
    ActiveResource::Schema.known_attribute_types.each_with_index do |the_type, ix|
      s = nil
      Person.schema do
        s = self
        send(the_type, "foo#{ix}")
      end
      assert s.attrs.has_key?("foo#{ix}"), "should now have saved the attribute name"
      assert_equal the_type.to_s, s.attrs_type_name["foo#{ix}"], "should have saved the attribute type of: #{the_type}"
    end
  end

  test "should accept multiple attribute names for an attribute method" do
    names = ["foo", "bar", "baz"]
    s = nil
    Person.schema do
      s = self
      string(*names)
    end
    names.each do |the_name|
      assert s.attrs.has_key?(the_name), "should now have saved the attribute name: #{the_name}"
      assert_equal "string", s.attrs[the_name].name.to_s, "should have saved the attribute as a string"
    end
  end


  #####################################################
  # What a schema does for us
  ####

  # respond_to_missing?

  test "should respond positively to attributes that are only in the schema" do
    skip "attributes are not a schema"
    new_attr_name = :my_new_schema_attribute1
    new_attr_name_two = :another_new_schema_attribute1
    assert Person.schema.blank?, "sanity check - should have a blank class schema"

    assert_not Person.new.respond_to?(new_attr_name), "sanity check - should not respond to the brand-new attribute yet"
    assert_not Person.new.respond_to?(new_attr_name_two), "sanity check - should not respond to the brand-new attribute yet"

    assert_nothing_raised do
      Person.schema = { new_attr_name.to_s => "string" }
      Person.schema { string new_attr_name_two }
    end

    assert_respond_to Person.new, new_attr_name, "should respond to the attribute in a passed-in schema, but failed on: #{new_attr_name}"
    assert_respond_to Person.new, new_attr_name_two, "should respond to the attribute from the schema, but failed on: #{new_attr_name_two}"
  end

  test "should not care about ordering of schema definitions" do
    new_attr_name = :my_new_schema_attribute2
    new_attr_name_two = :another_new_schema_attribute2

    # assert Person.schema.blank?, "sanity check - should have a blank class schema"

    assert_not Person.new.respond_to?(new_attr_name), "sanity check - should not respond to the brand-new attribute yet"
    assert_not Person.new.respond_to?(new_attr_name_two), "sanity check - should not respond to the brand-new attribute yet"

    assert_nothing_raised do
      Person.schema { string new_attr_name_two }
      Person.schema = { new_attr_name.to_s => "string" }
    end

    assert_respond_to Person.new, new_attr_name, "should respond to the attribute in a passed-in schema, but failed on: #{new_attr_name}"
    assert_respond_to Person.new, new_attr_name_two, "should respond to the attribute from the schema, but failed on: #{new_attr_name_two}"
  end

  test "should retrieve the `Method` object" do
    new_attr_name = :my_new_schema_attribute3
    new_attr_name_two = :another_new_schema_attribute3
    # assert Person.schema.blank?, "sanity check - should have a blank class schema"

    assert_not Person.new.respond_to?(new_attr_name), "sanity check - should not respond to the brand-new attribute yet"
    assert_not Person.new.respond_to?(new_attr_name_two), "sanity check - should not respond to the brand-new attribute yet"

    assert_nothing_raised do
      Person.schema = { new_attr_name.to_s => "string" }
      Person.schema { string new_attr_name_two }
    end

    assert_instance_of Method, Person.new.method(new_attr_name)
    assert_instance_of Method, Person.new.method(new_attr_name_two)
  end

  # method_missing effects

  test "should not give method_missing for attribute only in schema" do
    new_attr_name = :my_new_schema_attribute4
    new_attr_name_two = :another_new_schema_attribute4

    # assert Person.schema.blank?, "sanity check - should have a blank class schema"

    assert_raises(NoMethodError, "should not have found the attribute: #{new_attr_name} as a method") do
      Person.new.send(new_attr_name)
    end
    assert_raises(NoMethodError, "should not have found the attribute: #{new_attr_name_two} as a method") do
      Person.new.send(new_attr_name_two)
    end

    Person.schema = { new_attr_name.to_s => :float }
    Person.schema { string new_attr_name_two }

    assert_nothing_raised do
      Person.new.send(new_attr_name)
      Person.new.send(new_attr_name_two)
    end
  end


  ########
  # Known attributes
  #
  # Attributes can be known to be attributes even if they aren't actually
  # 'set' on a particular instance.
  # This will only differ from 'attributes' if a schema has been set.

  test "new model should have no known attributes" do
    assert_equal ['id'], Person.known_attributes
    assert_equal ['id'], Person.new.known_attributes
  end

  test "setting schema should set known attributes on class and instance" do
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised { Person.schema = new_schema }

    assert_equal (new_schema.keys + ['id']).sort, Person.known_attributes.sort
    assert_equal (new_schema.keys + ['id']).sort, Person.new.known_attributes.sort
  end

  test "known attributes on a fetched resource should return all the attributes of the instance" do
    p = Person.find(1)
    attrs = p.known_attributes

    assert attrs.present?, "should have found some attributes!"

    p.attributes.each do |the_attr, val|
      assert attrs.include?(the_attr), "should have found attr: #{the_attr} in known attributes, but only had: #{attrs.inspect}"
    end
  end

  test "with two instances, known attributes should match the attributes of the individual instances - even if they differ" do
    matz = Person.find(1)
    rick = Person.find(6)

    m_attrs = matz.attributes.keys.sort
    r_attrs = rick.attributes.keys.sort

    assert_not_equal m_attrs, r_attrs, "should have different attributes on each model"

    assert_not_equal matz.known_attributes, rick.known_attributes, "should have had different known attributes too"
  end

  test "setting schema then fetching should add schema attributes to the instance attributes" do
    # an attribute in common with fetched instance and one that isn't
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised { Person.schema = new_schema }

    matz = Person.find(1)
    known_attrs = matz.known_attributes

    matz.attributes.keys.each do |the_attr|
      assert known_attrs.include?(the_attr), "should have found instance attr: #{the_attr} in known attributes, but only had: #{known_attrs.inspect}"
    end
    new_schema.keys.each do |the_attr|
      assert known_attrs.include?(the_attr), "should have found schema attr: #{the_attr} in known attributes, but only had: #{known_attrs.inspect}"
    end
  end

  test "known attributes should be unique" do
    Object.send(:remove_const, :Person) rescue nil
    load 'fixtures/person.rb'
    new_schema = { "age" => "integer", "name" => "string" }
    Person.schema = new_schema
    assert_equal Person.new(age: 20, name: "Matz").known_attributes.sort, ["id", "age", "name"].sort
  end
end
