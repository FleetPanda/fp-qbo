# frozen_string_literal: true

module FpQbo
  # Base error class for all QBO integration errors.
  # All custom errors inherit from this class.
  class Error < StandardError; end

  # Raised for configuration errors in the fp_qbo gem.
  class ConfigurationError < Error; end

  # Raised for authentication errors (invalid/expired tokens, etc.).
  class AuthenticationError < Error
    # @return [String, nil] The error code, if provided.
    attr_reader :error_code

    # Initializes an AuthenticationError.
    # @param message [String] The error message.
    # @param error_code [String, nil] The error code.
    def initialize(message, error_code: nil)
      super(message)
      @error_code = error_code
    end
  end

  # Raised when the access token is expired.
  class TokenExpiredError < AuthenticationError; end
  # Raised when the token is invalid.
  class InvalidTokenError < AuthenticationError; end
  # Raised when the refresh token operation fails.
  class RefreshTokenError < AuthenticationError; end

  # Raised for connection errors (network, timeouts, etc.).
  class ConnectionError < Error
    # @return [Exception, nil] The original error, if available.
    attr_reader :original_error

    # Initializes a ConnectionError.
    # @param message [String] The error message.
    # @param original_error [Exception, nil] The original error.
    def initialize(message, original_error: nil)
      super(message)
      @original_error = original_error
    end
  end

  # Raised for timeout errors.
  class TimeoutError < ConnectionError; end
  # Raised for network errors.
  class NetworkError < ConnectionError; end

  # Raised for API errors (non-2xx responses, etc.).
  class APIError < Error
    # @return [Object, nil] The API response object.
    # @return [Integer, nil] The HTTP status code.
    # @return [String, nil] The error code.
    # @return [String, nil] The error detail.
    attr_reader :response, :status_code, :error_code, :error_detail

    # Initializes an APIError.
    # @param message [String] The error message.
    # @param response [Object, nil] The API response.
    # @param status_code [Integer, nil] The HTTP status code.
    # @param error_code [String, nil] The error code.
    # @param error_detail [String, nil] The error detail.
    def initialize(message, response: nil, status_code: nil, error_code: nil, error_detail: nil)
      super(message)
      @response = response
      @status_code = status_code
      @error_code = error_code
      @error_detail = error_detail
    end
  end

  # Raised for rate limit errors (HTTP 429).
  class RateLimitError < APIError
    # @return [Integer, nil] The retry-after value in seconds.
    attr_reader :retry_after

    # Initializes a RateLimitError.
    # @param message [String] The error message.
    # @param retry_after [Integer, nil] The retry-after value in seconds.
    # @param options [Hash] Additional options for APIError.
    def initialize(message, retry_after: nil, **options)
      super(message, **options)
      @retry_after = retry_after
    end
  end

  # Raised for validation errors (HTTP 400, etc.).
  class ValidationError < APIError; end
  # Raised when a resource is not found (HTTP 404).
  class NotFoundError < APIError; end
  class ConflictError < APIError; end
  class ServiceUnavailableError < APIError; end
end
