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
          payload[:arguments] = arguments
        end
        result = OpenStruct.new
        result.body = self.class.mock_body
        result
      end
    end

    module Methods
      def resource_request_controller(payload)
        uri = URI.parse(payload[:request_uri])
        send(payload[:method], :index, params: Rack::Utils.parse_nested_query(uri.query))
      end

      def set_resource_mock_body(body)
        body = body.to_json unless body.is_a?(String)
        ActiveResource::TestHelper::CaptureConnection.mock_body = body
      end
    end
  end
end
