# frozen_string_literal: true

module ActiveResource
  class Error < StandardError
  end

  class InvalidValue < Error; end
  class NotPersisted < Error; end

  class ConnectionError < Error # :nodoc:
    attr_reader :response, :response_body
    attr_reader :request

    def initialize(response, message = nil, request_args: [])
      @response = response
      @message  = message
      @request = {}.with_indifferent_access
      @request[:method] = request_args[0]
      @request[:path] = request_args[1]
      request_opts = request_args.extract_options!
      @request[:headers] = request_opts[:headers] || {}
      @request[:body] = request_opts[:body]
      if @request[:path]
        uri = URI.parse(@request[:path])
        @request[:format] = uri.path.scan(/.*\.(json|xml)$/).flatten[0]
      end
      if @response && decoder && @response.body.present?
        begin
          @response_body = decoder.decode_as_it_is(@response.body)
          if @response_body.is_a?(Hash)
            @response_body = @response_body.with_indifferent_access
            @message ||= @response_body['message'] if @response_body['message'].present?
            @message ||= @response_body.dig('error', 'message') if @response_body['error'].is_a?(Hash) && @response_body.dig('error', 'message').present?
          end
        rescue StandardError => e
          if respond_to?(:attributes)
            attributes[:response_body] = @response.body.to_s
            attributes[:response_parse_error] = "#{e.class.name}: #{e.message}"
          end
          @response_body = { 'original_body' => @response.body.to_s }
          @message = "#{e.class.name} #{e.message}"
        end
      end
    end

    def decoder
      case @request[:format]
      when 'json' then ActiveResource::Formats::JsonFormat
      when 'xml' then ActiveResource::Formats::XmlFormat
      end
    end

    def to_s
      message = []
      message << @message if @message
      message << "Response code = #{response.code}" if response.respond_to?(:code)
      message << "Response message = #{response.message}" if response.respond_to?(:message)
      message.join("\n")
    end

    def to_hash
      res = {request: @request, message: @message}
      if @response.respond_to?(:to_hash)
        res[:response] = @response.to_hash
      else
        res[:response] = @response.inspect
      end
      res
    end
    alias_method :to_h, :to_hash

    def info
      return @info if @info
      @info = []
      @info << "Response code = #{response.code}" if response.respond_to?(:code)
      @info << "Response message = #{response.message}" if response.respond_to?(:message)
      @info << "Response body message = #{response_body&.dig(:message) || response_body&.dig('original_body')}"
      @info << "Error message = #{@message}"
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
    def self.http_status = Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_request]
  end

  # 401 Unauthorized
  class UnauthorizedAccess < ClientError # :nodoc:
    def self.http_status = Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
  end

  # 403 Forbidden
  class ForbiddenAccess < ClientError # :nodoc:
    def self.http_status = Rack::Utils::SYMBOL_TO_STATUS_CODE[:forbidden]
  end

  # 404 Not Found
  class ResourceNotFound < ClientError # :nodoc:
    def self.http_status = Rack::Utils::SYMBOL_TO_STATUS_CODE[:not_found]
  end

  # 409 Conflict
  class ResourceConflict < ClientError # :nodoc:
    def self.http_status = Rack::Utils::SYMBOL_TO_STATUS_CODE[:conflict]
  end

  # 410 Gone
  class ResourceGone < ClientError # :nodoc:
    def self.http_status = Rack::Utils::SYMBOL_TO_STATUS_CODE[:gone]
  end

  # 412 Precondition Failed
  class PreconditionFailed < ClientError # :nodoc:
    def self.http_status = Rack::Utils::SYMBOL_TO_STATUS_CODE[:precondition_failed]
  end

  # 429 Too Many Requests
  class TooManyRequests < ClientError # :nodoc:
    def self.http_status = Rack::Utils::SYMBOL_TO_STATUS_CODE[:too_many_requests]
  end

  # 5xx Server Error
  class ServerError < ConnectionError # :nodoc:
    def self.http_status = Rack::Utils::SYMBOL_TO_STATUS_CODE[:internal_server_error]
  end

  # 405 Method Not Allowed
  class MethodNotAllowed < ClientError # :nodoc:
    def self.http_status = Rack::Utils::SYMBOL_TO_STATUS_CODE[:method_not_allowed]

    def allowed_methods
      @response["Allow"].split(",").map { |verb| verb.strip.downcase.to_sym }
    end
  end
end
