# frozen_string_literal: true

module FpQbo
  module Response
    # Represents an error response from the QuickBooks Online API.
    # Provides helpers to extract error details, raise exceptions, and convert to hash.
    class ErrorResponse
      attr_reader :data, :status_code, :headers, :request

      # Initializes a new ErrorResponse.
      #
      # @param data [Hash] The parsed response data.
      # @param status_code [Integer] The HTTP status code.
      # @param headers [Hash] The HTTP response headers.
      # @param request [FpQbo::Request::Request] The originating request.
      def initialize(data:, status_code:, headers:, request:)
        @data = data
        @status_code = status_code
        @headers = headers
        @request = request
      end

      # Returns false for an error response.
      #
      # @return [Boolean]
      def success?
        false
      end

      # Returns true for an error response.
      #
      # @return [Boolean]
      def error?
        true
      end

      # Returns an array of error details extracted from the response.
      #
      # @return [Array<Hash>] The error details.
      def errors
        @errors ||= extract_errors
      end

      # Returns a concatenated error message string for all errors.
      #
      # @return [String] The error message.
      def error_message
        errors.map { |e| "#{e[:code]}: #{e[:message]}" }.join("; ")
      end

      # Returns an array of error codes from the response.
      #
      # @return [Array<String>] The error codes.
      def error_codes
        errors.map { |e| e[:code] }
      end

      # Raises an appropriate exception based on the HTTP status code and error details.
      #
      # @raise [AuthenticationError, NotFoundError, ConflictError, RateLimitError, ServiceUnavailableError, APIError]
      def raise_exception!
        case status_code
        when 401
          raise AuthenticationError.new(error_message, error_code: error_codes.first)
        when 404
          raise NotFoundError.new(error_message, status_code: status_code, response: self)
        when 409
          raise ConflictError.new(error_message, status_code: status_code, response: self)
        when 429
          retry_after = extract_retry_after
          raise RateLimitError.new(error_message, status_code: status_code, retry_after: retry_after)
        when 500, 502, 503, 504
          raise ServiceUnavailableError.new(error_message, status_code: status_code)
        else
          raise APIError.new(error_message, status_code: status_code, response: self)
        end
      end

      # Returns a hash representation of the error response.
      #
      # @return [Hash] The response attributes and error details.
      def to_h
        {
          success: false,
          status_code: status_code,
          errors: errors,
          error_message: error_message
        }
      end

      private

      # Extracts error details from the response data.
      #
      # @return [Array<Hash>] The extracted errors.
      def extract_errors
        fault = data["Fault"]
        return [default_error] unless fault

        fault_errors = fault["Error"]
        return [default_error] unless fault_errors

        fault_errors = [fault_errors] unless fault_errors.is_a?(Array)

        fault_errors.map do |error|
          {
            code: error["code"] || "UNKNOWN",
            message: error["Message"] || error["message"] || "Unknown error",
            detail: error["Detail"] || error["detail"],
            element: error["element"]
          }
        end
      end

      # Returns a default error hash if no error details are found.
      #
      # @return [Hash] The default error.
      def default_error
        {
          code: status_code.to_s,
          message: "HTTP Error #{status_code}",
          detail: data["message"] || data["error"]
        }
      end

      # Extracts the retry-after value from the response headers, if present.
      #
      # @return [Integer, nil] The retry-after value in seconds, or nil if not present.
      def extract_retry_after
        retry_after = headers["retry-after"] || headers["Retry-After"]
        return nil unless retry_after

        retry_after.first.to_i if retry_after.is_a?(Array)
      end
    end
  end
end
