# frozen_string_literal: true

module FpQbo
  module Authentication
    class Token
      attr_reader :access_token, :refresh_token, :expires_at, :realm_id

      def initialize(access_token:, refresh_token:, realm_id:, expires_at: nil, expires_in: nil)
        @access_token = access_token
        @refresh_token = refresh_token
        @realm_id = realm_id
        @expires_at = calculate_expiry(expires_at, expires_in)
      end

      def valid?
        return false if access_token.nil? || access_token.empty?
        return true if expires_at.nil?

        Time.now < expires_at
      end

      def expired?
        !valid?
      end

      def expires_soon?(threshold_seconds = 300)
        return false if expires_at.nil?

        Time.now + threshold_seconds >= expires_at
      end

      def authorization_header
        "Bearer #{access_token}"
      end

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

      def calculate_expiry(expires_at, expires_in)
        return expires_at if expires_at.is_a?(Time)
        return Time.parse(expires_at) if expires_at.is_a?(String)
        return Time.now + expires_in if expires_in.is_a?(Integer)

        nil
      end
    end
  end
end
