module ActiveResource
  module TestHelper
    class CaptureConnection < Connection

      def request(method, path, *arguments)
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
            params = Rack::Utils.parse_nested_query(uri.query)
          end
          @grab_request.call(method, params, payload[:headers], payload)
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
        connection.grab_request do |method, params, headers, payload|
          request.headers.merge(payload[:headers])
          yield(method, params, payload)
        end
      end

      def resource_capture_request(connection)
        connection.grab_request do |method, params, headers, payload|
          result = yield(method, params, headers, payload)
          response
        end
      end
    end
  end
end
