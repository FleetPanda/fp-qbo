# frozen_string_literal: true

require_relative "request"

module FpQbo
  module Request
    class Builder
      def initialize(oauth_manager, config: FpQbo.configuration)
        @oauth_manager = oauth_manager
        @config = config
      end

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

      def construct_url(endpoint, query, minor_version)
        base = "#{@config.base_url}/v3/company/#{@oauth_manager.token.realm_id}"
        url = "#{base}/#{endpoint}"

        # Add minor version if specified
        query = query.merge(minorversion: minor_version) if minor_version

        return url if query.empty?

        query_string = URI.encode_www_form(query)
        "#{url}?#{query_string}"
      end

      def build_headers(custom_headers)
        default_headers.merge(custom_headers)
      end

      def default_headers
        {
          "Authorization" => @oauth_manager.authorization_header,
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "User-Agent" => "FpQbo/#{FpQbo::VERSION} Ruby/#{RUBY_VERSION}"
        }
      end

      def serialize_body(body)
        return nil if body.nil?
        return body if body.is_a?(String)

        JSON.generate(body)
      end

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
