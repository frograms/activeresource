# frozen_string_literal: true

require "active_support/core_ext/benchmark"
require "active_support/core_ext/object/inclusion"
require "net/https"
require "date"
require "time"
require "uri"
require "faraday"
require "active_resource/response_wrapper"

module ActiveResource
  # Class to handle connections to remote web services.
  # This class is used by ActiveResource::Base to interface with REST
  # services.
  class Connection
    HTTP_FORMAT_HEADER_NAMES = {  get: "Accept",
      put: "Content-Type",
      post: "Content-Type",
      patch: "Content-Type",
      delete: "Accept",
      head: "Accept"
    }

    attr_reader :site, :user, :password, :bearer_token, :auth_type, :timeout, :open_timeout, :read_timeout, :proxy, :ssl_options
    attr_accessor :format, :logger

    cattr_accessor :response_wrapper, default: proc{|response| ResponseWrapper.new(response)}

    class << self
      def requests
        @@requests ||= []
      end
    end

    # The +site+ parameter is required and will set the +site+
    # attribute to the URI for the remote resource service.
    def initialize(site, format = ActiveResource::Formats::JsonFormat, logger: nil)
      raise ArgumentError, "Missing site URI" unless site
      @proxy = @user = @password = @bearer_token = nil
      self.site = site
      self.format = format
      self.logger = logger
    end

    # Set URI for remote service.
    def site=(site)
      @site = site.is_a?(URI) ? site : URI.parse(site)
      @ssl_options ||= {} if @site.is_a?(URI::HTTPS)
      @user = URI::DEFAULT_PARSER.unescape(@site.user) if @site.user
      @password = URI::DEFAULT_PARSER.unescape(@site.password) if @site.password
    end

    # Set the proxy for remote service.
    def proxy=(proxy)
      @proxy = proxy.is_a?(URI) ? proxy : URI.parse(proxy)
    end

    # Sets the user for remote service.
    attr_writer :user

    # Sets the password for remote service.
    attr_writer :password

    # Sets the bearer token for remote service.
    attr_writer :bearer_token

    # Sets the auth type for remote service.
    def auth_type=(auth_type)
      @auth_type = legitimize_auth_type(auth_type)
    end

    # Sets the number of seconds after which HTTP requests to the remote service should time out.
    attr_writer :timeout

    # Sets the number of seconds after which HTTP connects to the remote service should time out.
    attr_writer :open_timeout

    # Sets the number of seconds after which HTTP read requests to the remote service should time out.
    attr_writer :read_timeout

    # Hash of options applied to Net::HTTP instance when +site+ protocol is 'https'.
    attr_writer :ssl_options

    # Executes a GET request.
    # Used to get (find) resources.
    def get(path, headers = {})
      with_auth { request(:get, path, headers: build_request_headers(headers, :get, self.site.merge(path))) }
    end

    # Executes a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(path, headers = {})
      with_auth { request(:delete, path, headers: build_request_headers(headers, :delete, self.site.merge(path))) }
    end

    # Executes a PATCH request (see HTTP protocol documentation if unfamiliar).
    # Used to update resources.
    def patch(path, body = "", headers = {})
      with_auth { request(:patch, path, body: body.to_s, headers: build_request_headers(headers, :patch, self.site.merge(path))) }
    end

    # Executes a PUT request (see HTTP protocol documentation if unfamiliar).
    # Used to update resources.
    def put(path, body = "", headers = {})
      with_auth { request(:put, path, body: body.to_s, headers: build_request_headers(headers, :put, self.site.merge(path))) }
    end

    # Executes a POST request.
    # Used to create new resources.
    def post(path, body = "", headers = {})
      with_auth { request(:post, path, body: body.to_s, headers: build_request_headers(headers, :post, self.site.merge(path))) }
    end

    # Executes a HEAD request.
    # Used to obtain meta-information about resources, such as whether they exist and their size (via response headers).
    def head(path, headers = {})
      with_auth { request(:head, path, headers: build_request_headers(headers, :head, self.site.merge(path))) }
    end

    attr_reader :last_result

    private
      # Makes a request to the remote service.
      def request(method, path, headers: {}, body: nil)
        result = ActiveSupport::Notifications.instrument("request.active_resource") do |payload|
          payload[:method]      = method
          payload[:request_uri] = "#{site.scheme}://#{site.host}:#{site.port}#{path}"
          payload[:result]      = http.send(method, path) do |req|
            req.headers = headers
            req.body = body
          end
        end
        result = self.class.response_wrapper.call(result)
        @last_result = {request: [method, path, headers: headers, body: body], response: result}
        handle_response(result, request_args: [method, path, headers: headers, body: body])
      rescue Timeout::Error => e
        raise TimeoutError.new(e.message)
      rescue OpenSSL::SSL::SSLError => e
        raise SSLError.new(e.message)
      end

      # Handles response and error codes from the remote service.
      def handle_response(response, request_args: [])
        case response.code.to_i
        when 301, 302, 303, 307
          raise(Redirection.new(response, request_args: request_args))
        when 200...400
          response
        when 400
          raise(BadRequest.new(response, request_args: request_args))
        when 401
          raise(UnauthorizedAccess.new(response, request_args: request_args))
        when 403
          raise(ForbiddenAccess.new(response, request_args: request_args))
        when 404
          raise(ResourceNotFound.new(response, request_args: request_args))
        when 405
          raise(MethodNotAllowed.new(response, request_args: request_args))
        when 409
          raise(ResourceConflict.new(response, request_args: request_args))
        when 410
          raise(ResourceGone.new(response, request_args: request_args))
        when 412
          raise(PreconditionFailed.new(response, request_args: request_args))
        when 422
          raise(ResourceInvalid.new(response, request_args: request_args))
        when 429
          raise(TooManyRequests.new(response, request_args: request_args))
        when 401...500
          raise(ClientError.new(response, request_args: request_args))
        when 500...600
          raise(ServerError.new(response, request_args: request_args))
        else
          raise(ConnectionError.new(response, "Unknown response code: #{response.code}", request_args: request_args))
        end
      end

      # Creates new Net::HTTP instance for communication with the
      # remote service and resources.
      def http
        configure_http(new_http)
      end

      def new_http
        Faraday.new(url: @site) do |con|
          con.request :url_encoded # default middleware
          con.proxy = @proxy if @proxy
        end
      end

      def configure_http(http)
        apply_ssl_options(http).tap do |https|
          # Net::HTTP timeouts default to 60 seconds.
          if defined? @timeout
            https.options[:open_timeout] = @timeout
            https.options[:read_timeout] = @timeout
          end
          https.options[:open_timeout] = @open_timeout if defined?(@open_timeout)
          https.options[:read_timeout] = @read_timeout if defined?(@read_timeout)
        end
      end

      def apply_ssl_options(http)
        http.tap do |https|
          # Skip config if site is already a https:// URI.
          if defined? @ssl_options
            http.ssl.verify = true

            # All the SSL options have corresponding http settings.
            @ssl_options.each { |key, value| http.ssl[key] = value }
          end
        end
      end

      def default_header
        @default_header ||= {}
      end

      # Builds headers for request to remote service.
      def build_request_headers(headers, http_method, uri)
        authorization_header(http_method, uri).update(default_header).update(http_format_header(http_method)).update(headers.to_h)
      end

      def response_auth_header
        @response_auth_header ||= ""
      end

      def with_auth
        retried ||= false
        yield
      rescue UnauthorizedAccess => e
        raise if retried || auth_type != :digest
        @response_auth_header = e.response["WWW-Authenticate"]
        retried = true
        retry
      end

      def authorization_header(http_method, uri)
        if @user || @password
          if auth_type == :digest
            { "Authorization" => digest_auth_header(http_method, uri) }
          else
            { "Authorization" => "Basic " + ["#{@user}:#{@password}"].pack("m").delete("\r\n") }
          end
        elsif @bearer_token
          { "Authorization" => "Bearer #{@bearer_token}" }
        else
          {}
        end
      end

      def digest_auth_header(http_method, uri)
        params = extract_params_from_response

        request_uri = uri.path
        request_uri << "?#{uri.query}" if uri.query

        ha1 = Digest::MD5.hexdigest("#{@user}:#{params['realm']}:#{@password}")
        ha2 = Digest::MD5.hexdigest("#{http_method.to_s.upcase}:#{request_uri}")

        params["cnonce"] = client_nonce
        request_digest = Digest::MD5.hexdigest([ha1, params["nonce"], "0", params["cnonce"], params["qop"], ha2].join(":"))
        "Digest #{auth_attributes_for(uri, request_digest, params)}"
      end

      def client_nonce
        Digest::MD5.hexdigest("%x" % (Time.now.to_i + rand(65535)))
      end

      def extract_params_from_response
        params = {}
        if response_auth_header =~ /^(\w+) (.*)/
          $2.gsub(/(\w+)="(.*?)"/) { params[$1] = $2 }
        end
        params
      end

      def auth_attributes_for(uri, request_digest, params)
        auth_attrs =
          [
            %Q(username="#{@user}"),
            %Q(realm="#{params['realm']}"),
            %Q(qop="#{params['qop']}"),
            %Q(uri="#{uri.path}"),
            %Q(nonce="#{params['nonce']}"),
            'nc="0"',
            %Q(cnonce="#{params['cnonce']}"),
            %Q(response="#{request_digest}")]

        auth_attrs << %Q(opaque="#{params['opaque']}") unless params["opaque"].blank?
        auth_attrs.join(", ")
      end

      def http_format_header(http_method)
        { HTTP_FORMAT_HEADER_NAMES[http_method] => format.mime_type }
      end

      def legitimize_auth_type(auth_type)
        return :basic if auth_type.nil?
        auth_type = auth_type.to_sym
        auth_type.in?([:basic, :digest, :bearer]) ? auth_type : :basic
      end
  end
end
