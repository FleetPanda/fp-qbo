# frozen_string_literal: true

module FpQbo
  module Retry
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

      def initialize(max_attempts: 3, base_delay: 1, max_delay: 32, retryable_errors: DEFAULT_RETRYABLE_ERRORS)
        @max_attempts = max_attempts
        @base_delay = base_delay
        @max_delay = max_delay
        @retryable_errors = retryable_errors
        @logger = FpQbo.logger
      end

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

      def self.with_retry(max_attempts: 3, base_delay: 1, &block)
        new(max_attempts: max_attempts, base_delay: base_delay).execute(&block)
      end

      private

      def calculate_delay(attempt)
        delay = @base_delay * (2**(attempt - 1))
        [delay, @max_delay].min
      end
    end
  end
end
