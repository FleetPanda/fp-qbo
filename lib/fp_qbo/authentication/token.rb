# frozen_string_literal: true

module FpQbo
  module Authentication
    # Represents an OAuth2 token for QuickBooks Online, including access, refresh, and expiration logic.
    # Provides methods to check validity, expiration, and to build authorization headers.
    class Token
      attr_reader :access_token, :refresh_token, :expires_at, :realm_id

      # Initializes a new Token object.
      #
      # @param access_token [String] The OAuth2 access token.
      # @param refresh_token [String] The OAuth2 refresh token.
      # @param realm_id [String] The QuickBooks company ID.
      # @param expires_at [Time, String, nil] The expiration time as a Time or ISO8601 string.
      # @param expires_in [Integer, nil] The number of seconds until expiration.
      def initialize(access_token:, refresh_token:, realm_id:, expires_at: nil, expires_in: nil)
        @access_token = access_token
        @refresh_token = refresh_token
        @realm_id = realm_id
        @expires_at = calculate_expiry(expires_at, expires_in)
      end

      # Checks if the access token is present and not expired.
      #
      # @return [Boolean] True if the token is valid, false otherwise.
      def valid?
        return false if access_token.nil? || access_token.empty?
        return true if expires_at.nil?

        Time.now < expires_at
      end

      # Checks if the token is expired.
      #
      # @return [Boolean] True if the token is expired, false otherwise.
      def expired?
        !valid?
      end

      # Checks if the token will expire within the given threshold (default 5 minutes).
      #
      # @param threshold_seconds [Integer] The threshold in seconds.
      # @return [Boolean] True if the token expires soon, false otherwise.
      def expires_soon?(threshold_seconds = 300)
        return false if expires_at.nil?

        Time.now + threshold_seconds >= expires_at
      end

      # Returns the HTTP Authorization header value for this token.
      #
      # @return [String] The Authorization header value.
      def authorization_header
        "Bearer #{access_token}"
      end

      # Returns a hash representation of the token and its state.
      #
      # @return [Hash] The token attributes and state.
      def to_h
        {
          access_token: access_token,
          refresh_token: refresh_token,
          realm_id: realm_id,
          expires_at: expires_at,
          valid: valid?,
          expires_soon: expires_soon?
        }
      end

      private

      # Calculates the expiration time for the token.
      #
      # @param expires_at [Time, String, nil] The expiration time as a Time or ISO8601 string.
      # @param expires_in [Integer, nil] The number of seconds until expiration.
      # @return [Time, nil] The calculated expiration time, or nil if not provided.
      def calculate_expiry(expires_at, expires_in)
        return expires_at if expires_at.is_a?(Time)
        return Time.parse(expires_at) if expires_at.is_a?(String)
        return Time.now + expires_in if expires_in.is_a?(Integer)

        nil
      end
    end
  end
end
