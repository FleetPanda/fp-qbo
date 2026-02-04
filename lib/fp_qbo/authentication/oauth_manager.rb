# frozen_string_literal: true

require_relative "token"

module FpQbo
  module Authentication
    # Manages OAuth2 tokens for QuickBooks Online, including validation and refresh logic.
    # Provides methods to check token validity, refresh tokens, and build authorization headers.
    class OAuthManager
      attr_reader :token

      # Initializes a new OAuthManager.
      #
      # @param token [FpQbo::Authentication::Token] The token to manage.
      def initialize(token)
        @token = token
        @config = FpQbo.configuration
        @logger = FpQbo.logger
      end

      # Checks if the managed token is valid.
      #
      # @return [Boolean] True if the token is valid, false otherwise.
      def valid?
        token.valid?
      end

      # Checks if the token needs to be refreshed (expired or expiring soon).
      #
      # @return [Boolean] True if refresh is needed, false otherwise.
      def refresh_needed?
        token.expired? || token.expires_soon?
      end

      # Refreshes the OAuth token using the refresh token.
      #
      # @return [FpQbo::Authentication::Token] The new token object.
      # @raise [AuthenticationError] If no refresh token is available.
      # @raise [RefreshTokenError] If the refresh fails.
      def refresh!
        raise AuthenticationError, "No refresh token available" if token.refresh_token.nil?

        @logger.info("Refreshing OAuth token", realm_id: token.realm_id)

        response = perform_refresh_request

        new_token = parse_refresh_response(response)
        @token = new_token

        @logger.info("OAuth token refreshed successfully", realm_id: token.realm_id)

        new_token
      rescue StandardError => e
        @logger.error("Token refresh failed", error: e.message, realm_id: token.realm_id)
        raise RefreshTokenError, "Failed to refresh token: #{e.message}"
      end

      # Returns the HTTP Authorization header for the managed token.
      #
      # @return [String] The Authorization header value.
      def authorization_header
        token.authorization_header
      end

      private

      # Performs the HTTP request to refresh the token.
      #
      # @return [Net::HTTPResponse] The HTTP response from the token endpoint.
      def perform_refresh_request
        uri = URI("#{@config.oauth_base_url}/oauth2/v1/tokens/bearer")

        request = Net::HTTP::Post.new(uri)
        request["Accept"] = "application/json"
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request["Authorization"] = basic_auth_header

        request.set_form_data(
          grant_type: "refresh_token",
          refresh_token: token.refresh_token
        )

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = @config.open_timeout
        http.read_timeout = @config.read_timeout

        http.request(request)
      end

      def basic_auth_header
        credentials = "#{@config.client_id}:#{@config.client_secret}"
        "Basic #{Base64.strict_encode64(credentials)}"
      end

      def parse_refresh_response(response)
        unless response.is_a?(Net::HTTPSuccess)
          error_message = extract_error_message(response)
          raise RefreshTokenError, "Token refresh failed: #{error_message}"
        end

        data = JSON.parse(response.body)

        Token.new(
          access_token: data["access_token"],
          refresh_token: data["refresh_token"],
          realm_id: token.realm_id,
          expires_in: data["expires_in"]
        )
      end

      def extract_error_message(response)
        return response.message unless response.body

        data = JSON.parse(response.body)
        data["error_description"] || data["error"] || response.message
      rescue JSON::ParserError
        response.message
      end
    end
  end
end
