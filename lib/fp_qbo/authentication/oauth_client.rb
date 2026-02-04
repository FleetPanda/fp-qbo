# frozen_string_literal: true

module FpQbo
  module Authentication
    # Handles OAuth2 authorization and token exchange for QuickBooks Online.
    # Provides methods to generate authorization URLs and exchange codes for tokens.
    class OAuthClient
      AUTHORIZATION_URL = "https://appcenter.intuit.com/connect/oauth2"
      TOKEN_URL = "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"

      # Initializes a new OAuthClient.
      #
      # @param config [FpQbo::Configuration] The configuration object to use.
      def initialize(config: FpQbo.configuration)
        @config = config
        @logger = FpQbo.logger
      end

      # Generates the OAuth2 authorization URL for user consent.
      #
      # @param redirect_uri [String] The redirect URI after authorization.
      # @param state [String, nil] Optional state parameter for CSRF protection.
      # @param scope [String] The OAuth2 scope to request.
      # @return [String] The full authorization URL.
      def authorization_url(redirect_uri:, state: nil, scope: default_scope)
        params = {
          client_id: @config.client_id,
          scope: scope,
          redirect_uri: redirect_uri,
          response_type: "code",
          state: state || SecureRandom.hex(16)
        }

        uri = URI(AUTHORIZATION_URL)
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      # Exchanges an authorization code for an access token.
      #
      # @param code [String] The authorization code received from the callback.
      # @param redirect_uri [String] The redirect URI used in the authorization request.
      # @param realm_id [String] The QuickBooks company ID.
      # @return [FpQbo::Authentication::Token] The resulting token object.
      # @raise [AuthenticationError] If the token exchange fails.
      def exchange_code_for_token(code:, redirect_uri:, realm_id:)
        @logger.info("Exchanging authorization code for token", realm_id: realm_id)

        response = perform_token_exchange(code, redirect_uri)
        token = parse_token_response(response, realm_id)

        @logger.info("Token exchange successful", realm_id: realm_id)

        token
      rescue StandardError => e
        @logger.error("Token exchange failed", error: e.message, realm_id: realm_id)
        raise AuthenticationError, "Failed to exchange code: #{e.message}"
      end

      private

      # Returns the default OAuth2 scope for QuickBooks Online.
      #
      # @return [String] The default scope string.
      def default_scope
        "com.intuit.quickbooks.accounting"
      end

      # Performs the HTTP request to exchange the authorization code for a token.
      #
      # @param code [String] The authorization code.
      # @param redirect_uri [String] The redirect URI.
      # @return [Net::HTTPResponse] The HTTP response from the token endpoint.
      def perform_token_exchange(code, redirect_uri)
        uri = URI(TOKEN_URL)

        request = Net::HTTP::Post.new(uri)
        request["Accept"] = "application/json"
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request["Authorization"] = basic_auth_header

        request.set_form_data(
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri
        )

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = @config.open_timeout
        http.read_timeout = @config.read_timeout

        http.request(request)
      end

      # Builds the HTTP Basic Authorization header for client authentication.
      #
      # @return [String] The value for the Authorization header.
      def basic_auth_header
        credentials = "#{@config.client_id}:#{@config.client_secret}"
        "Basic #{Base64.strict_encode64(credentials)}"
      end

      # Parses the token endpoint response and returns a Token object.
      #
      # @param response [Net::HTTPResponse] The HTTP response from the token endpoint.
      # @param realm_id [String] The QuickBooks company ID.
      # @return [FpQbo::Authentication::Token] The resulting token object.
      # @raise [AuthenticationError] If the response is not successful.
      def parse_token_response(response, realm_id)
        unless response.is_a?(Net::HTTPSuccess)
          error_message = extract_error_message(response)
          raise AuthenticationError, "Token exchange failed: #{error_message}"
        end

        data = JSON.parse(response.body)

        Token.new(
          access_token: data["access_token"],
          refresh_token: data["refresh_token"],
          realm_id: realm_id,
          expires_in: data["expires_in"]
        )
      end

      # Extracts an error message from a failed token endpoint response.
      #
      # @param response [Net::HTTPResponse] The HTTP response.
      # @return [String] The extracted error message.
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
