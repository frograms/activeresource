require "abstract_unit"
require "fixtures/musician"
require "active_resource/test_helper"

class RecordTest < ActiveSupport::TestCase
  include ActiveResource::TestHelper::Methods

  def setup
    ActiveResource::Base.connection_class = ActiveResource::TestHelper::CaptureConnection
  end

  def teardown
    ActiveResource::Base.connection_class = ActiveResource::Connection
  end

  test "polymorphic" do
    song = Song.new
    musician = Client::Musician.new(id: 10)
    song.singer = musician
    assert_equal 'Musician', song.singer_type
    assert_equal 10, song.singer_id
    assert_equal musician, song.singer
    song.save
    song = Song.find(song.id)
    resource_capture_model(Client::Musician.connection) do |method, path, params, headers, payload|
      assert_equal :get, method
      assert_equal "/musicians.json", path
      assert_equal({'id'=>'10', 'type'=>'Musician'}, params)
      OpenStruct.new(status: 200, headers: {}, body:[{id: 10}].to_json)
    end
    assert_equal musician, song.singer
  end

  test 'base_class' do
    assert_equal Client::Musician.base_class, Client::Musician
    assert_equal Client::Composer.base_class, Client::Musician
  end
end
