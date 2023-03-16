module ActiveResource
  class ResponseWrapper
    attr_reader :response

    def initialize(response)
      @response = response
    end

    def code
      @response.status
    end

    def message
      @response.env.reason_phrase
    end

    private
    def method_missing(symbol, *args, &block)
      @response.send(symbol, *args, &block)
    end
  end
end
