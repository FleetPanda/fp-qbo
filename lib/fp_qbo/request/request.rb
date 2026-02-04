# frozen_string_literal: true

module FpQbo
  module Request
    # Represents an HTTP request for the QuickBooks Online API, including method, URL, headers, and metadata.
    # Provides helpers for method checks and sanitization for logging/debugging.
    class Request
      attr_reader :method, :url, :headers, :body, :metadata, :created_at

      # Initializes a new Request object.
      #
      # @param method [Symbol] The HTTP method (:get, :post, etc.).
      # @param url [String] The request URL.
      # @param headers [Hash] The HTTP headers.
      # @param body [String, nil] The request body.
      # @param metadata [Hash] Additional metadata for the request.
      def initialize(method:, url:, headers:, body:, metadata: {})
        @method = method
        @url = url
        @headers = headers
        @body = body
        @metadata = metadata
        @created_at = Time.now
      end

      # Checks if the request method is GET.
      #
      # @return [Boolean] True if GET, false otherwise.
      def get?
        method == :get
      end

      # Checks if the request method is POST.
      #
      # @return [Boolean] True if POST, false otherwise.
      def post?
        method == :post
      end

      # Checks if the request method is PUT.
      #
      # @return [Boolean] True if PUT, false otherwise.
      def put?
        method == :put
      end

      # Checks if the request method is DELETE.
      #
      # @return [Boolean] True if DELETE, false otherwise.
      def delete?
        method == :delete
      end

      # Returns a hash representation of the request, with sensitive data sanitized.
      #
      # @return [Hash] The request attributes and metadata.
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

      # Removes query parameters from the URL to avoid leaking sensitive data.
      #
      # @return [String] The sanitized URL.
      def sanitize_url
        # Remove query parameters that might contain sensitive data
        uri = URI(url)
        uri.query = nil if uri.query
        uri.to_s
      end

      # Removes the Authorization header from the headers hash.
      #
      # @return [Hash] The sanitized headers.
      def sanitize_headers
        headers.except("Authorization")
      end
    end
  end
end
