# frozen_string_literal: true

module FpQbo
  class Logger
    def initialize(logger = nil)
      @logger = logger || FpQbo.configuration.logger
    end

    def debug(message, context = {})
      log(:debug, message, context)
    end

    def info(message, context = {})
      log(:info, message, context)
    end

    def warn(message, context = {})
      log(:warn, message, context)
    end

    def error(message, context = {})
      log(:error, message, context)
    end

    def fatal(message, context = {})
      log(:fatal, message, context)
    end

    private

    def log(level, message, context)
      return unless @logger

      formatted_message = format_message(message, context)
      @logger.public_send(level, formatted_message)
    end

    def format_message(message, context)
      return message if context.empty?

      context_str = context.map { |k, v| "#{k}=#{sanitize_value(v)}" }.join(" ")
      "#{message} | #{context_str}"
    end

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
