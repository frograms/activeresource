module ActiveResource
  module TestHelper
    class CaptureConnection < Connection
      class << self
        attr_writer :mock_body

        def mock_body
          @mock_body ||= '{}'
        end
      end

      def request(method, path, *arguments)
        ActiveSupport::Notifications.instrument("request.active_resource") do |payload|
          payload[:method]      = method
          payload[:request_uri] = "#{site.scheme}://#{site.host}:#{site.port}#{path}"
          payload[:connection]  = http
          payload[:method] = method
          payload[:path] = path
          case method
          when :get, :delete, :head
            payload[:headers] = arguments[0]
          else
            payload[:body] = format.decode_as_it_is(arguments[0])
            payload[:headers] = arguments[1]
          end
        end
        result = OpenStruct.new
        result.body = self.class.mock_body
        result
      end
    end

    module Methods
      def resource_request_controller(payload, action: :index)
        uri = URI.parse(payload[:request_uri])
        if payload[:body]
          params = payload[:body]
        else
          params = Rack::Utils.parse_nested_query(uri.query)
        end
        send(payload[:method], action, params: params)
      end

      def set_resource_mock_body(body)
        body = body.to_json unless body.is_a?(String)
        ActiveResource::TestHelper::CaptureConnection.mock_body = body
      end
    end
  end
end
