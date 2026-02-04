# frozen_string_literal: true

module FpQbo
  # Provides structured logging for the fp_qbo gem, with context and sensitive data sanitization.
  class Logger
    # Initializes a new Logger.
    #
    # @param logger [Logger, nil] The logger instance to use (defaults to FpQbo.configuration.logger).
    def initialize(logger = nil)
      @logger = logger || FpQbo.configuration.logger
    end

    # Logs a debug message with optional context.
    #
    # @param message [String] The log message.
    # @param context [Hash] Additional context for the log.
    def debug(message, context = {})
      log(:debug, message, context)
    end

    # Logs an info message with optional context.
    #
    # @param message [String] The log message.
    # @param context [Hash] Additional context for the log.
    def info(message, context = {})
      log(:info, message, context)
    end

    # Logs a warning message with optional context.
    #
    # @param message [String] The log message.
    # @param context [Hash] Additional context for the log.
    def warn(message, context = {})
      log(:warn, message, context)
    end

    # Logs an error message with optional context.
    #
    # @param message [String] The log message.
    # @param context [Hash] Additional context for the log.
    def error(message, context = {})
      log(:error, message, context)
    end

    # Logs a fatal message with optional context.
    #
    # @param message [String] The log message.
    # @param context [Hash] Additional context for the log.
    def fatal(message, context = {})
      log(:fatal, message, context)
    end

    private

    # Internal: Logs a message at the given level with context, after formatting and sanitization.
    #
    # @param level [Symbol] The log level (:debug, :info, :warn, :error, :fatal).
    # @param message [String] The log message.
    # @param context [Hash] Additional context for the log.
    def log(level, message, context)
      return unless @logger

      formatted_message = format_message(message, context)
      @logger.public_send(level, formatted_message)
    end

    # Internal: Formats a log message with context as a string.
    #
    # @param message [String] The log message.
    # @param context [Hash] Additional context for the log.
    # @return [String] The formatted message.
    def format_message(message, context)
      return message if context.empty?

      context_str = context.map { |k, v| "#{k}=#{sanitize_value(v)}" }.join(" ")
      "#{message} | #{context_str}"
    end

    # Internal: Sanitizes sensitive values in log context.
    #
    # @param value [Object] The value to sanitize.
    # @return [Object] The sanitized value.
    def sanitize_value(value)
      # Sanitize sensitive information
      case value
      when String
        sanitize_string(value)
      when Hash
        value.transform_values { |v| sanitize_value(v) }
      else
        value
      end
    end

    # Internal: Sanitizes sensitive strings (e.g., tokens) in log messages.
    #
    # @param str [String] The string to sanitize.
    # @return [String] The sanitized string.
    def sanitize_string(str)
      # Mask tokens and sensitive data
      patterns = [
        /Bearer\s+([a-zA-Z0-9._-]+)/i,
        /"access_token"\s*:\s*"([^"]+)"/,
        /"refresh_token"\s*:\s*"([^"]+)"/
      ]

      sanitized = str.dup
      patterns.each do |pattern|
        sanitized.gsub!(pattern) do |match|
          match.gsub(Regexp.last_match(1), "[REDACTED]")
        end
      end

      sanitized
    end
  end
end
