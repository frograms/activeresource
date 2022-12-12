module ActiveResource
  module TestHelper
    class CaptureConnection < Connection
      cattr_accessor :capture_id
      class << self
        attr_writer :mock_body

        def mock_body
          @mock_body ||= '{}'
        end
      end

      def request(method, path, *arguments)
        if capture_id
          ActiveSupport::Notifications.instrument("capture.active_resource.#{capture_id}") do |capture_payload|
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
                payload[:body_s] = arguments[0]
                payload[:body] = format.decode_as_it_is(arguments[0]) if arguments[0].present?
                payload[:headers] = arguments[1]
              end
              capture_payload.update(payload)
            end
          end
          result = OpenStruct.new
          result.body = self.class.mock_body
          result
        else
          super
        end
      end
    end

    module Methods
      def resource_request_controller(id: SecureRandom.base64(10))
        CaptureConnection.capture_id = id
        ActiveSupport::Notifications.subscribe("capture.active_resource.#{id}") do |name, start_time, end_time, _, payload|
          uri = URI.parse(payload[:request_uri])
          if payload[:body]
            params = payload[:body]
          else
            params = Rack::Utils.parse_nested_query(uri.query)
          end
          request.headers.merge(payload[:headers])
          yield(payload[:method], params, payload)
          CaptureConnection.capture_id = nil
          ActiveSupport::Notifications.unsubscribe("capture.active_resource.#{id}")
        end
      end

      def set_resource_mock_body(body)
        body = body.to_json unless body.is_a?(String)
        ActiveResource::TestHelper::CaptureConnection.mock_body = body
      end
    end
  end
end
