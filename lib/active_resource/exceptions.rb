# frozen_string_literal: true

module ActiveResource
  class Error < StandardError
  end

  class InvalidValue < Error; end
  class NotPersisted < Error; end

  class ConnectionError < Error # :nodoc:
    attr_reader :response
    attr_reader :request

    def initialize(response, message = nil, request_args: [])
      @response = response
      @message  = message
      @request = {}
      @request[:method] = request_args[0]
      @request[:path] = request_args[1]
      @request[:arguments] = request_args[2..-1] || []
    end

    def to_s
      return @message if @message

      message = +"Failed."
      message << "  Response code = #{response.code}." if response.respond_to?(:code)
      message << "  Response message = #{response.message}." if response.respond_to?(:message)
      message
    end

    def info
      return @info if @info
      @info = []
      @info << "Response code = #{response.code}" if response.respond_to?(:code)
      @info << "Response message = #{response.message}" if response.respond_to?(:message)
      @info << "Request method = #{request[:method]}" if request[:method]
      @info << "Request path = #{request[:path]}" if request[:path]
      @info << "Request args = #{request[:arguments]}" if request[:arguments]
      @info
    end
  end

  # Raised when a Timeout::Error occurs.
  class TimeoutError < ConnectionError
    def initialize(message)
      @message = message
    end
    def to_s; @message ; end
  end

  # Raised when a OpenSSL::SSL::SSLError occurs.
  class SSLError < ConnectionError
    def initialize(message)
      @message = message
    end
    def to_s; @message ; end
  end

  # 3xx Redirection
  class Redirection < ConnectionError # :nodoc:
    def to_s
      response["Location"] ? "#{super} => #{response['Location']}" : super
    end
  end

  class MissingPrefixParam < ArgumentError # :nodoc:
  end

  # 4xx Client Error
  class ClientError < ConnectionError # :nodoc:
  end

  # 400 Bad Request
  class BadRequest < ClientError # :nodoc:
  end

  # 401 Unauthorized
  class UnauthorizedAccess < ClientError # :nodoc:
  end

  # 403 Forbidden
  class ForbiddenAccess < ClientError # :nodoc:
  end

  # 404 Not Found
  class ResourceNotFound < ClientError # :nodoc:
  end

  # 409 Conflict
  class ResourceConflict < ClientError # :nodoc:
  end

  # 410 Gone
  class ResourceGone < ClientError # :nodoc:
  end

  # 412 Precondition Failed
  class PreconditionFailed < ClientError # :nodoc:
  end

  # 429 Too Many Requests
  class TooManyRequests < ClientError # :nodoc:
  end

  # 5xx Server Error
  class ServerError < ConnectionError # :nodoc:
  end

  # 405 Method Not Allowed
  class MethodNotAllowed < ClientError # :nodoc:
    def allowed_methods
      @response["Allow"].split(",").map { |verb| verb.strip.downcase.to_sym }
    end
  end
end
