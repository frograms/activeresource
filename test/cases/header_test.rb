# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"
require "fixtures/animal"
require "active_support/json"
require "active_support/core_ext/hash/conversions"
require "mocha/minitest"

class HeaderTest < ActiveSupport::TestCase
  def setup
    setup_response # find me in abstract_unit
  end

  def teardown
  end

  def test_headers1
    assert_equal Animal.headers, {kingdom: 'animal'}.with_indifferent_access
  end

  def test_headers2
    assert_equal Mammal.headers, {kingdom: 'animal', phylum: 'mammal', class: 'unknown'}.with_indifferent_access
  end

  def test_headers3
    assert_equal Dog.headers, {kingdom: 'animal', phylum: 'mammal2', class: 'dog'}.with_indifferent_access
  end
end
