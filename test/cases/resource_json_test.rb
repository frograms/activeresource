# frozen_string_literal: true

require "abstract_unit"
require "active_resource/resource_json"

class TestObject
  attr_accessor :name, :age, :child

  def <=>(other)
    k = name <=> other.name
    return k if k != 0
    age <=> other.age
  end
end

class ResourceBase < ActiveResource::Base
  schema do
    string :name
    integer :age
  end

  def <=>(other)
    k = name <=> other.name
    return k if k != 0
    age <=> other.age
  end
end

class ResourceJsonTest < ActiveSupport::TestCase
  def test_resource_json
    o = TestObject.new
    o.name = "John"
    o.age = 30
    assert_equal({ "name" => "John", "age" => 30 }, o.resource_json)
  end

  def test_resource_json_with_child
    o = TestObject.new
    o.name = "John"
    o.age = 30
    son = TestObject.new
    son.name = "Tom"
    son.age = 10
    o.child = son
    assert_equal({ "name" => "John", "age" => 30, "child" => { "name" => "Tom", "age" => 10 } }, o.resource_json)
  end

  def test_resource_json_with_recursive
    o = TestObject.new
    o.name = "John"
    o.age = 30
    son = TestObject.new
    son.name = "Tom"
    son.age = 10
    o.child = son
    grand_son = TestObject.new
    grand_son.name = "Jerry"
    grand_son.age = 5
    grand_son.child = o
    son.child = grand_son
    assert_equal(
      { "name" => "John", "age" => 30, "child" => {
        "name" => "Tom", "age" => 10, "child" => {
          "name" => "Jerry", "age" => 5, "child" => {
            "name" => "John", "age" => 30 } } } }, o.resource_json)
  end

  def test_resource_base
    o = ResourceBase.new
    o.name = "John"
    o.age = 30
    assert_equal({ "name" => "John", "age" => 30, "extra"=>{}, "__type__"=>"ResourceBase" }, o.resource_json(root: false))
  end

  def test_resource_base_with_child
    o = ResourceBase.new
    o.name = "John"
    o.age = 30
    son = ResourceBase.new
    son.name = "Tom"
    son.age = 10
    o.child = son
    assert_equal({ "name" => "John", "age" => 30, "extra"=>{}, "__type__"=>"ResourceBase", "child" => {
      "name" => "Tom", "age" => 10, "extra"=>{}, "__type__"=>"ResourceBase" } }, o.resource_json(root: false))
  end

  def test_resource_base_with_recursive
    o = ResourceBase.new
    o.name = "John"
    o.age = 30
    son = ResourceBase.new
    son.name = "Tom"
    son.age = 10
    o.child = son
    grand_son = ResourceBase.new
    grand_son.name = "Jerry"
    grand_son.age = 5
    grand_son.child = o
    son.child = grand_son
    assert_equal(
      { "name" => "John", "age" => 30, "extra"=>{}, "__type__"=>"ResourceBase", "child" => {
        "name" => "Tom", "age" => 10, "extra"=>{}, "__type__"=>"ResourceBase", "child" => {
          "name" => "Jerry", "age" => 5, "extra"=>{}, "__type__"=>"ResourceBase", "child" => {
            "name" => "John", "age" => 30, "__type__"=>"ResourceBase"
          }}}}, o.resource_json(root: false))
  end

  def test_resource_base_with_recursive_arr
    o = ResourceBase.new
    o.name = "John"
    o.age = 30
    son = ResourceBase.new
    son.name = "Tom"
    son.age = 10
    o.child = [son]
    grand_son = ResourceBase.new
    grand_son.name = "Jerry"
    grand_son.age = 5
    grand_son.child = [o]
    son.child = [grand_son]
    assert_equal(
      { "name" => "John", "age" => 30, "extra"=>{}, "__type__"=>"ResourceBase", "child" => [{
        "name" => "Tom", "age" => 10, "extra"=>{}, "__type__"=>"ResourceBase", "child" => [{
          "name" => "Jerry", "age" => 5, "extra"=>{}, "__type__"=>"ResourceBase", "child" => [{
            "name" => "John", "age" => 30, "__type__"=>"ResourceBase"
          }]}]}]}, o.resource_json(root: false))
  end
end
