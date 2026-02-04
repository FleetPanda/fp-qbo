# frozen_string_literal: true

module FpQbo
  module Retry
    # Implements a retry strategy with exponential backoff for network and API errors.
    class Strategy
      DEFAULT_RETRYABLE_ERRORS = [
        Timeout::Error,
        Errno::ECONNREFUSED,
        Errno::EHOSTUNREACH,
        Errno::ETIMEDOUT,
        SocketError,
        NetworkError,
        ServiceUnavailableError
      ].freeze

      # Initializes a new retry strategy.
      #
      # @param max_attempts [Integer] Maximum number of retry attempts.
      # @param base_delay [Numeric] Base delay in seconds for backoff.
      # @param max_delay [Numeric] Maximum delay in seconds.
      # @param retryable_errors [Array<Class>] Errors that should trigger a retry.
      def initialize(max_attempts: 3, base_delay: 1, max_delay: 32, retryable_errors: DEFAULT_RETRYABLE_ERRORS)
        @max_attempts = max_attempts
        @base_delay = base_delay
        @max_delay = max_delay
        @retryable_errors = retryable_errors
        @logger = FpQbo.logger
      end

      # Executes the given block with retry logic for retryable errors.
      #
      # @yield The block to execute with retries.
      # @return [Object] The result of the block if successful.
      # @raise [Exception] The last error if retries are exhausted.
      def execute
        attempt = 0

        begin
          attempt += 1
          yield
        rescue *@retryable_errors => e
          if attempt < @max_attempts
            delay = calculate_delay(attempt)
            @logger.warn("Retrying after error", error: e.class.name, attempt: attempt, delay: delay)
            sleep(delay)
            retry
          else
            @logger.error("Max retry attempts reached", error: e.class.name, attempts: attempt)
            raise
          end
        end
      end

      # Class-level helper to execute a block with retry logic.
      #
      # @param max_attempts [Integer] Maximum number of retry attempts.
      # @param base_delay [Numeric] Base delay in seconds for backoff.
      # @yield The block to execute with retries.
      # @return [Object] The result of the block if successful.
      def self.with_retry(max_attempts: 3, base_delay: 1, &block)
        new(max_attempts: max_attempts, base_delay: base_delay).execute(&block)
      end

      private

      # Calculates the exponential backoff delay for the given attempt.
      #
      # @param attempt [Integer] The current attempt number.
      # @return [Numeric] The delay in seconds.
      def calculate_delay(attempt)
        delay = @base_delay * (2**(attempt - 1))
        [delay, @max_delay].min
      end
    end
  end
end
