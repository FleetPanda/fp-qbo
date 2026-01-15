# frozen_string_literal: true

module FpQbo
  # Base error class for all QBO integration errors
  class Error < StandardError; end

  # Configuration errors
  class ConfigurationError < Error; end

  # Authentication errors
  class AuthenticationError < Error
    attr_reader :error_code

    def initialize(message, error_code: nil)
      super(message)
      @error_code = error_code
    end
  end

  class TokenExpiredError < AuthenticationError; end
  class InvalidTokenError < AuthenticationError; end
  class RefreshTokenError < AuthenticationError; end

  # Connection errors
  class ConnectionError < Error
    attr_reader :original_error

    def initialize(message, original_error: nil)
      super(message)
      @original_error = original_error
    end
  end

  class TimeoutError < ConnectionError; end
  class NetworkError < ConnectionError; end

  # API errors
  class APIError < Error
    attr_reader :response, :status_code, :error_code, :error_detail

    def initialize(message, response: nil, status_code: nil, error_code: nil, error_detail: nil)
      super(message)
      @response = response
      @status_code = status_code
      @error_code = error_code
      @error_detail = error_detail
    end
  end

  class RateLimitError < APIError
    attr_reader :retry_after

    def initialize(message, retry_after: nil, **options)
      super(message, **options)
      @retry_after = retry_after
    end
  end

  class ValidationError < APIError; end
  class NotFoundError < APIError; end
  class ConflictError < APIError; end
  class ServiceUnavailableError < APIError; end
end
