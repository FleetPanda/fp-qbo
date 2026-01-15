# frozen_string_literal: true

module FpQbo
  class CircuitBreaker
    STATES = %i[closed open half_open].freeze

    attr_reader :state, :failure_count, :last_failure_time

    def initialize(
      failure_threshold: 5,
      timeout: 60,
      half_open_attempts: 3
    )
      @failure_threshold = failure_threshold
      @timeout = timeout
      @half_open_attempts = half_open_attempts

      @state = :closed
      @failure_count = 0
      @success_count = 0
      @last_failure_time = nil
      @mutex = Mutex.new
      @logger = FpQbo.logger
    end

    def call(&block)
      case state
      when :open
        raise CircuitBreakerOpenError, "Circuit breaker is open" unless should_attempt_reset?

        attempt_half_open(&block)

      when :half_open
        attempt_half_open(&block)
      else
        execute_closed(&block)
      end
    end

    def closed?
      @state == :closed
    end

    def open?
      @state == :open
    end

    def half_open?
      @state == :half_open
    end

    def reset!
      @mutex.synchronize do
        @state = :closed
        @failure_count = 0
        @success_count = 0
        @last_failure_time = nil
        @logger.info("Circuit breaker reset")
      end
    end

    private

    def should_attempt_reset?
      @last_failure_time && (Time.now - @last_failure_time) >= @timeout
    end

    def execute_closed
      result = yield

      @mutex.synchronize do
        @failure_count = 0
      end

      result
    rescue StandardError => e
      handle_failure
      raise e
    end

    def attempt_half_open
      @mutex.synchronize { @state = :half_open }

      result = yield

      @mutex.synchronize do
        @success_count += 1

        if @success_count >= @half_open_attempts
          @state = :closed
          @failure_count = 0
          @success_count = 0
          @logger.info("Circuit breaker closed after successful attempts")
        end
      end

      result
    rescue StandardError => e
      handle_failure
      raise e
    end

    def handle_failure
      @mutex.synchronize do
        @failure_count += 1
        @last_failure_time = Time.now
        @success_count = 0

        if @failure_count >= @failure_threshold
          @state = :open
          @logger.warn("Circuit breaker opened", failures: @failure_count)
        end
      end
    end

    class CircuitBreakerOpenError < Error; end
  end
end
