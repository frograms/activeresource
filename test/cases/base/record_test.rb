require "abstract_unit"
require "fixtures/musician"

class RecordTest < ActiveSupport::TestCase
  def setup
    
  end

  def teardown
    
  end

  test "polymorphic" do
    song = Song.new
    musician = Client::Musician.new(id: 10)
    song.singer = musician
    assert_equal 'Musician', song.singer_type
    assert_equal 10, song.singer_id
  end
end