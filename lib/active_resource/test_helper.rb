module ActiveResource
  module TestHelper
    mattr_accessor :client_object_map

    module ConnectionReleaseRequest
      def release_request
        connection.release_request if site
        subclasses.map do |klass|
          klass.release_request
        end
      end
    end

    ::ActiveResource::Base.send(:extend, ConnectionReleaseRequest)

    class ResponseWrapper < ::ActiveResource::ResponseWrapper
      def code
        return @response.code if @response.respond_to?(:code)
        return @response.status if @response.respond_to?(:status)
        (@response.code rescue nil) || @response.status
      end

      def body
        super # ActiveResource::Base#parse_collection check this has body method
      end

      def message
        return @response.message if @response.respond_to?(:message)
        return @response.reason_phrase if @response.respond_to?(:reason_phrase)
        (@response.message rescue nil) || @response.reason_phrase
      end
    end

    class CaptureConnection < ::ActiveResource::Connection
      class << self
        def response_wrapper
          proc do |response|
            ::ActiveResource::TestHelper::ResponseWrapper.new(response)
          end
        end
      end

      def request(method, path, headers: {}, body: nil)
        if (grab = @grab_request.shift)
          result = ActiveSupport::Notifications.instrument("request.#{client_name}") do |payload|
            payload[:method]      = method
            payload[:request_uri] = "#{site.scheme}://#{site.host}:#{site.port}#{path}"
            payload[:request_headers] = headers.merge('User-Agent' => client_name)
            payload[:request_body] = body
            payload[:request_body_hash] = format.decode_as_it_is(body) if body.present?
            uri = URI.parse(payload[:request_uri])
            if payload[:request_body_hash]
              params = payload[:request_body_hash]
            else
              params = Rack::Utils.parse_nested_query(uri.query).with_indifferent_access
            end
            result = grab.call(method, uri.path, params, payload[:request_headers], payload)
            if result.is_a?(String)
              mock = OpenStruct.new
              mock.body = result
              mock.code = 200
              result = mock
            end
            result = self.class.response_wrapper.call(result)
            payload[:result] = result
          end
          @last_result = {request: [method, path, headers: headers, body: body], response: result}
          handle_response(result, request_args: [method, path, headers: headers, body: body])
        else
          super
        end
      rescue Timeout::Error => e
        raise TimeoutError.new(e.message)
      rescue OpenSSL::SSL::SSLError => e
        raise SSLError.new(e.message)
      end

      def grab_request(&block)
        @grab_request ||= []
        @grab_request << block
      end

      def release_request
        @grab_request = []
      end

      def grab_consumed?
        @grab_request.blank?
      end
    end

    module Methods
      def resource_capture_controller(connection)
        connection.grab_request do |method, path ,params, headers, payload|
          request.headers.merge(payload[:request_headers])
          ActiveResource.define_singleton_method(:api_type_name_object_map) { ApiTypeNameObjectMap }
          result = yield(method, params, payload)
          ActiveResource.define_singleton_method(:api_type_name_object_map) { TestHelper::TestClientMap }
          result
        end
      end

      def resource_capture_request(connection)
        connection.grab_request do |method, path, params, headers, payload|
          ActiveResource.define_singleton_method(:api_type_name_object_map) { ApiTypeNameObjectMap }
          result = if block_given?
            yield(method, path, params, headers, payload)
          elsif method == :post
            headers['CONTENT_TYPE'] = 'application/json'
            send(method, path, params: params.to_json, headers: headers)
          else
            send(method, path, params: params, headers: headers)
          end
          ActiveResource.define_singleton_method(:api_type_name_object_map) { TestHelper::TestClientMap }
          response
        end
      end

      def resource_capture_model(connection)
        connection.grab_request do |method, path, params, headers, payload|
          yield(method, path, params, headers, payload)
        end
      end

      def resource_client_object_map
        ActiveResource::TestHelper.send(:remove_const, :TestClientMap) rescue nil
        mod = ActiveResource::ApiTypeNameObjectMap.dup
        ActiveResource::TestHelper.const_set(:TestClientMap, mod)
        object_map = {}.with_indifferent_access
        object_map.instance_eval do
          alias _set_ []=
        end
        mod.define_singleton_method(:object_map) { object_map }
        api_type_name_map = {}
        api_type_name_map.instance_eval do
          alias _set_ []=
        end
        mod.define_singleton_method(:api_type_name_map) { api_type_name_map }
        object_fallback = proc { |api_type_name| api_type_name.constantize }
        mod.define_singleton_method(:_object_fallback) { object_fallback }
        api_type_name_fallback = proc { |object| (object.is_a?(String) ? object.constantize : object).base_class.name }
        mod.define_singleton_method(:_api_type_name_fallback) { api_type_name_fallback }
        ActiveResource.define_singleton_method(:api_type_name_object_map) { mod }
        yield(mod) if block_given?
        ActiveResource.define_singleton_method(:api_type_name_object_map) { ApiTypeNameObjectMap }
        ActiveResource::TestHelper.send(:remove_const, :TestClientMap) rescue nil
      end
    end
  end
end
