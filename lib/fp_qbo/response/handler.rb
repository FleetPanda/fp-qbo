# frozen_string_literal: true

require_relative "success_response"
require_relative "error_response"

module FpQbo
  module Response
    class Handler
      def initialize(logger: FpQbo.logger)
        @logger = logger
      end

      def handle(http_response, request)
        @logger.debug("Handling response", status: http_response.code, request: request.to_h)

        if success?(http_response)
          build_success_response(http_response, request)
        else
          build_error_response(http_response, request)
        end
      end

      private

      def success?(http_response)
        http_response.code.to_i >= 200 && http_response.code.to_i < 300
      end

      def build_success_response(http_response, request)
        data = parse_json(http_response.body)

        SuccessResponse.new(
          data: data,
          status_code: http_response.code.to_i,
          headers: http_response.to_hash,
          request: request
        )
      end

      def build_error_response(http_response, request)
        data = parse_json(http_response.body)

        ErrorResponse.new(
          data: data,
          status_code: http_response.code.to_i,
          headers: http_response.to_hash,
          request: request
        )
      end

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
