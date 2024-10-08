# frozen_string_literal: true

require "active_support/json"

module ActiveResource
  module Formats
    module JsonFormat
      extend self

      def extension
        "json"
      end

      def mime_type
        "application/json"
      end

      def encode(hash, options = nil)
        ActiveSupport::JSON.encode(hash, options)
      end

      def decode(json)
        return nil if json.nil?
        Formats.remove_root(decode_as_it_is(json))
      end

      def decode_as_it_is(json)
        ActiveSupport::JSON.decode(json)
      end
    end
  end
end
