module ActiveResource
  module TestHelper
    mattr_accessor :client_object_map

    class CaptureConnection < Connection

      def request(method, path, *arguments)
        if @grab_request
          result = ActiveSupport::Notifications.instrument("request.active_resource") do |payload|
            payload[:method]      = method
            payload[:request_uri] = "#{site.scheme}://#{site.host}:#{site.port}#{path}"
            payload[:connection]  = http
            payload[:method] = method
            payload[:path] = path
            case method
            when :get, :delete, :head
              payload[:headers] = arguments[0]
            else
              payload[:body_s] = arguments[0]
              payload[:body] = format.decode_as_it_is(arguments[0]) if arguments[0].present?
              payload[:headers] = arguments[1]
            end
            uri = URI.parse(payload[:request_uri])
            if payload[:body]
              params = payload[:body]
            else
              params = Rack::Utils.parse_nested_query(uri.query).with_indifferent_access
            end
            @grab_request.call(method, uri.path, params, payload[:headers], payload)
          end
          @grab_request = nil
        else
          result = super
        end
        @last_result = {request: [method, path, *arguments], response: result}
        if result.is_a?(String)
          mock = OpenStruct.new
          mock.body = result
          mock.code = 200
          result = mock
        end
        handle_response(result, request_args: [method, path, *arguments])
      rescue Timeout::Error => e
        raise TimeoutError.new(e.message)
      rescue OpenSSL::SSL::SSLError => e
        raise SSLError.new(e.message)
      end

      def grab_request(&block)
        @grab_request = block
      end
    end

    module Methods
      def resource_capture_controller(connection)
        connection.grab_request do |method, path ,params, headers, payload|
          request.headers.merge(payload[:headers])
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
