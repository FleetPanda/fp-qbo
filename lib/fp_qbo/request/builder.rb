# frozen_string_literal: true

require_relative "request"

module FpQbo
  module Request
    # Builds HTTP requests for the QuickBooks Online API, handling URL construction, headers, and body serialization.
    class Builder
      # Initializes a new Request::Builder.
      #
      # @param oauth_manager [FpQbo::Authentication::OAuthManager] The OAuth manager for authorization.
      # @param config [FpQbo::Configuration] The configuration object.
      def initialize(oauth_manager, config: FpQbo.configuration)
        @oauth_manager = oauth_manager
        @config = config
      end

      # Builds a new Request object for the given parameters.
      #
      # @param method [Symbol] The HTTP method.
      # @param endpoint [String] The API endpoint.
      # @param query [Hash] Query parameters for the request.
      # @param body [Hash, String, nil] The request body.
      # @param headers [Hash] Additional HTTP headers.
      # @param minor_version [Integer, nil] Optional minor version for the API.
      # @return [FpQbo::Request::Request] The constructed request object.
      def build(method:, endpoint:, query: {}, body: nil, headers: {}, minor_version: nil)
        Request.new(
          method: method.to_sym,
          url: construct_url(endpoint, query, minor_version),
          headers: build_headers(headers),
          body: serialize_body(body),
          metadata: build_metadata
        )
      end

      private

      # Constructs the full request URL with query parameters and minor version.
      #
      # @param endpoint [String] The API endpoint.
      # @param query [Hash] Query parameters.
      # @param minor_version [Integer, nil] Optional minor version.
      # @return [String] The constructed URL.
      def construct_url(endpoint, query, minor_version)
        base = "#{@config.base_url}/v3/company/#{@oauth_manager.token.realm_id}"
        url = "#{base}/#{endpoint}"

        # Add minor version if specified
        query = query.merge(minorversion: minor_version) if minor_version

        return url if query.empty?

        query_string = URI.encode_www_form(query)
        "#{url}?#{query_string}"
      end

      # Merges default headers with custom headers for the request.
      #
      # @param custom_headers [Hash] Custom headers to merge.
      # @return [Hash] The merged headers.
      def build_headers(custom_headers)
        default_headers.merge(custom_headers)
      end

      # Returns the default HTTP headers for all requests.
      #
      # @return [Hash] The default headers.
      def default_headers
        {
          "Authorization" => @oauth_manager.authorization_header,
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "User-Agent" => "FpQbo/#{FpQbo::VERSION} Ruby/#{RUBY_VERSION}"
        }
      end

      # Serializes the request body to JSON if it is a Hash, or returns as-is if String.
      #
      # @param body [Hash, String, nil] The request body.
      # @return [String, nil] The serialized body or nil.
      def serialize_body(body)
        return nil if body.nil?
        return body if body.is_a?(String)

        JSON.generate(body)
      end

      # Builds metadata for the request, including realm_id, environment, and timestamp.
      #
      # @return [Hash] The metadata for the request.
      def build_metadata
        {
          realm_id: @oauth_manager.token.realm_id,
          environment: @config.environment,
          timestamp: Time.now
        }
      end
    end
  end
end
