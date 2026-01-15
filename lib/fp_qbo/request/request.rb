# frozen_string_literal: true

module FpQbo
  module Request
    class Request
      attr_reader :method, :url, :headers, :body, :metadata, :created_at

      def initialize(method:, url:, headers:, body:, metadata: {})
        @method = method
        @url = url
        @headers = headers
        @body = body
        @metadata = metadata
        @created_at = Time.now
      end

      def get?
        method == :get
      end

      def post?
        method == :post
      end

      def put?
        method == :put
      end

      def delete?
        method == :delete
      end

      def to_h
        {
          method: method,
          url: sanitize_url,
          headers: sanitize_headers,
          body_present: !body.nil?,
          metadata: metadata
        }
      end

      private

      def sanitize_url
        # Remove query parameters that might contain sensitive data
        uri = URI(url)
        uri.query = nil if uri.query
        uri.to_s
      end

      def sanitize_headers
        headers.except("Authorization")
      end
    end
  end
end
