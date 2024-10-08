# frozen_string_literal: true

require "active_support/core_ext/hash/conversions"

module ActiveResource
  module Formats
    module XmlFormat
      extend self

      def extension
        "xml"
      end

      def mime_type
        "application/xml"
      end

      def encode(hash, options = {})
        hash.to_xml(options)
      end

      def decode(xml)
        Formats.remove_root(decode_as_it_is(xml))
      end

      def decode_as_it_is(xml)
        Hash.from_xml(xml)
      end
    end
  end
end
