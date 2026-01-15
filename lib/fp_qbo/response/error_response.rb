# frozen_string_literal: true

module FpQbo
  module Response
    class ErrorResponse
      attr_reader :data, :status_code, :headers, :request

      def initialize(data:, status_code:, headers:, request:)
        @data = data
        @status_code = status_code
        @headers = headers
        @request = request
      end

      def success?
        false
      end

      def error?
        true
      end

      def errors
        @errors ||= extract_errors
      end

      def error_message
        errors.map { |e| "#{e[:code]}: #{e[:message]}" }.join("; ")
      end

      def error_codes
        errors.map { |e| e[:code] }
      end

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

      def to_h
        {
          success: false,
          status_code: status_code,
          errors: errors,
          error_message: error_message
        }
      end

      private

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

      def default_error
        {
          code: status_code.to_s,
          message: "HTTP Error #{status_code}",
          detail: data["message"] || data["error"]
        }
      end

      def extract_retry_after
        retry_after = headers["retry-after"] || headers["Retry-After"]
        return nil unless retry_after

        retry_after.first.to_i if retry_after.is_a?(Array)
      end
    end
  end
end
