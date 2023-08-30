# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/hash/conversions"

class Developer < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"

  class << self
    def callback_string(callback_method)
      "history << [#{callback_method.to_sym.inspect}, :string]"
    end

    def callback_proc(callback_method)
      Proc.new { |model| model.history << [callback_method, :proc] }
    end

    def define_callback_method(callback_method)
      define_method(callback_method) do
        self.history << [callback_method, :method]
      end
      send(callback_method, :"#{callback_method}")
    end

    def callback_object(callback_method)
      klass = Class.new
      klass.send(:define_method, callback_method) do |model|
        model.history << [callback_method, :object]
      end
      klass.new
    end
  end

  ActiveResource::Callbacks::CALLBACKS.each do |callback_method|
    next if callback_method.to_s =~ /^around_/
    define_callback_method(callback_method)
    send(callback_method, callback_proc(callback_method))
    send(callback_method, callback_object(callback_method))
    send(callback_method) { |model| model.history << [callback_method, :block] }
  end

  def history
    @history ||= []
  end
end

class CallbacksTest < ActiveSupport::TestCase
  def setup
    @developer_attrs = { id: 1, name: "Guillermo", salary: 100_000 }
    @developer = { "developer" => @developer_attrs }.to_json
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post   "/developers.json",   {}, @developer, 201, "Location" => "/developers/1.json"
      mock.get    "/developers/1.json", {}, @developer
      mock.put    "/developers/1.json", {}, nil, 204
      mock.delete "/developers/1.json", {}, nil, 200
    end
  end

  def test_valid?
    developer = Developer.new
    developer.valid?
    assert_equal [
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
    ], developer.history
  end

  def test_create
    developer = Developer.create(@developer_attrs.merge(persisted: false))
    assert developer.persisted?
    history = developer.history
    assert_equal [ :before_validation,           :method ], history[0]
    assert_equal [ :before_validation,           :proc   ], history[1]
    assert_equal [ :before_validation,           :object ], history[2]
    assert_equal [ :before_validation,           :block  ], history[3]
    assert_equal [ :after_validation,            :method ], history[4]
    assert_equal [ :after_validation,            :proc   ], history[5]
    assert_equal [ :after_validation,            :object ], history[6]
    assert_equal [ :after_validation,            :block  ], history[7]
    assert_equal [ :before_save,                 :method ], history[8]
    assert_equal [ :before_save,                 :proc   ], history[9]
    assert_equal [ :before_save,                 :object ], history[10]
    assert_equal [ :before_save,                 :block  ], history[11]
    assert_equal [ :before_create,               :method ], history[12]
    assert_equal [ :before_create,               :proc   ], history[13]
    assert_equal [ :before_create,               :object ], history[14]
    assert_equal [ :before_create,               :block  ], history[15]
    assert_equal [ :after_create,                :method ], history[16]
    assert_equal [ :after_create,                :proc   ], history[17]
    assert_equal [ :after_create,                :object ], history[18]
    assert_equal [ :after_create,                :block  ], history[19]
    assert_equal [ :after_save,                  :method ], history[20]
    assert_equal [ :after_save,                  :proc   ], history[21]
    assert_equal [ :after_save,                  :object ], history[22]
    assert_equal [ :after_save,                  :block  ], history[23]
  end

  def test_update
    developer = Developer.find(1)
    developer.save
    assert_equal [
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :before_save,                 :method ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_update,               :method ],
      [ :before_update,               :proc   ],
      [ :before_update,               :object ],
      [ :before_update,               :block  ],
      [ :after_update,                :method ],
      [ :after_update,                :proc   ],
      [ :after_update,                :object ],
      [ :after_update,                :block  ],
      [ :after_save,                  :method ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ]
    ], developer.history
  end

  def test_destroy
    developer = Developer.find(1)
    developer.destroy
    assert_equal [
      [ :before_destroy,              :method ],
      [ :before_destroy,              :proc   ],
      [ :before_destroy,              :object ],
      [ :before_destroy,              :block  ],
      [ :after_destroy,               :method ],
      [ :after_destroy,               :proc   ],
      [ :after_destroy,               :object ],
      [ :after_destroy,               :block  ]
    ], developer.history
  end

  def test_delete
    developer = Developer.find(1)
    Developer.delete(developer.id)
    assert_equal [], developer.history
  end
end
