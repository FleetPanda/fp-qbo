# frozen_string_literal: true

require_relative "success_response"
require_relative "error_response"

module FpQbo
  module Response
    # Handles HTTP responses from the QuickBooks Online API, building success or error response objects.
    class Handler
      # Initializes a new Handler.
      #
      # @param logger [Logger] The logger instance.
      def initialize(logger: FpQbo.logger)
        @logger = logger
      end

      # Handles an HTTP response, returning a SuccessResponse or ErrorResponse.
      #
      # @param http_response [Net::HTTPResponse] The HTTP response.
      # @param request [FpQbo::Request::Request] The originating request.
      # @return [SuccessResponse, ErrorResponse] The wrapped response object.
      def handle(http_response, request)
        @logger.debug("Handling response", status: http_response.code, request: request.to_h)

        if success?(http_response)
          build_success_response(http_response, request)
        else
          build_error_response(http_response, request)
        end
      end

      private

      # Checks if the HTTP response is a success (2xx).
      #
      # @param http_response [Net::HTTPResponse] The HTTP response.
      # @return [Boolean] True if success, false otherwise.
      def success?(http_response)
        http_response.code.to_i >= 200 && http_response.code.to_i < 300
      end

      # Builds a SuccessResponse from the HTTP response and request.
      #
      # @param http_response [Net::HTTPResponse] The HTTP response.
      # @param request [FpQbo::Request::Request] The originating request.
      # @return [SuccessResponse]
      def build_success_response(http_response, request)
        data = parse_json(http_response.body)

        SuccessResponse.new(
          data: data,
          status_code: http_response.code.to_i,
          headers: http_response.to_hash,
          request: request
        )
      end

      # Builds an ErrorResponse from the HTTP response and request.
      #
      # @param http_response [Net::HTTPResponse] The HTTP response.
      # @param request [FpQbo::Request::Request] The originating request.
      # @return [ErrorResponse]
      def build_error_response(http_response, request)
        data = parse_json(http_response.body)

        ErrorResponse.new(
          data: data,
          status_code: http_response.code.to_i,
          headers: http_response.to_hash,
          request: request
        )
      end

      # Parses a JSON response body, returning a hash or error info.
      #
      # @param body [String, nil] The response body.
      # @return [Hash] The parsed JSON or error info.
      def parse_json(body)
        return {} if body.nil? || body.empty?

        JSON.parse(body)
      rescue JSON::ParserError => e
        @logger.warn("Failed to parse JSON response", error: e.message)
        { "raw_response" => body, "parse_error" => e.message }
      end
    end
  end
end
