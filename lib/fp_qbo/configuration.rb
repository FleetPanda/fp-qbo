# frozen_string_literal: true

require "logger"

module FpQbo
  # Configuration for the fp_qbo gem, including API credentials, environment, timeouts, and logging.
  # Provides accessors for all configurable options and environment helpers.
  class Configuration
    attr_accessor :client_id, :client_secret, :environment, :base_url, :oauth_base_url, :timeout, :open_timeout,
                  :read_timeout, :retry_count, :retry_delay, :max_retry_delay, :rate_limit_enabled, :rate_limit_per_minute, :logger, :log_level, :pool_size, :pool_timeout, :auto_refresh_token, :validate_ssl

    ENVIRONMENTS = {
      production: "https://quickbooks.api.intuit.com",
      sandbox: "https://sandbox-quickbooks.api.intuit.com"
    }.freeze

    OAUTH_BASE_URL = "https://oauth.platform.intuit.com"

    # Initializes a new Configuration object with default values.
    def initialize
      @client_id = nil
      @client_secret = nil

      @environment = :sandbox
      @base_url = ENVIRONMENTS[:sandbox]
      @oauth_base_url = OAUTH_BASE_URL

      @timeout = 60
      @open_timeout = 30
      @read_timeout = 60

      @retry_count = 3
      @retry_delay = 1
      @max_retry_delay = 32

      @rate_limit_enabled = true
      @rate_limit_per_minute = 450

      @logger = ::Logger.new($stdout)
      @log_level = ::Logger::INFO

      @pool_size = 5
      @pool_timeout = 5

      @auto_refresh_token = true
      @validate_ssl = true
    end

    # Sets the environment and updates the base_url accordingly.
    #
    # @param env [Symbol, String] The environment (:production or :sandbox).
    # @raise [ConfigurationError] If the environment is invalid.
    def environment=(env)
      env = env.to_sym
      unless ENVIRONMENTS.key?(env)
        raise ConfigurationError, "Invalid environment: #{env}. Must be :production or :sandbox"
      end

      @environment = env
      @base_url = ENVIRONMENTS[env]
    end

    # Checks if the environment is production.
    #
    # @return [Boolean] True if production, false otherwise.
    def production?
      environment == :production
    end

    # Checks if the environment is sandbox.
    #
    # @return [Boolean] True if sandbox, false otherwise.
    def sandbox?
      environment == :sandbox
    end

    def validate!
      errors = []

      errors << "client_id is required" if client_id.nil? || client_id.empty?
      errors << "client_secret is required" if client_secret.nil? || client_secret.empty?
      errors << "timeout must be positive" if timeout && timeout <= 0
      errors << "retry_count must be non-negative" if retry_count && retry_count < 0
      errors << "pool_size must be positive" if pool_size && pool_size <= 0

      raise ConfigurationError, errors.join(", ") unless errors.empty?

      true
    end

    def to_h
      {
        client_id: client_id ? "#{client_id[0..5]}..." : nil,
        environment: environment,
        base_url: base_url,
        timeout: timeout,
        retry_count: retry_count,
        pool_size: pool_size,
        rate_limit_enabled: rate_limit_enabled
      }
    end
  end
end
