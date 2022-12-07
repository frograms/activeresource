module ActiveResource
  class CustomTypeConfig
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def load_hash(attributes, key, value_hash, persisted)
      # implement
    end
  end
end
