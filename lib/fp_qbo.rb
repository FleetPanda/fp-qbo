# frozen_string_literal: true

require_relative "fp_qbo/version"
require_relative "fp_qbo/errors"
require_relative "fp_qbo/configuration"
require_relative "fp_qbo/logger"

require_relative "fp_qbo/authentication/token"
require_relative "fp_qbo/authentication/oauth_manager"
require_relative "fp_qbo/authentication/oauth_client"
require_relative "fp_qbo/request/builder"
require_relative "fp_qbo/request/request"
require_relative "fp_qbo/response/handler"
require_relative "fp_qbo/response/success_response"
require_relative "fp_qbo/response/error_response"
require_relative "fp_qbo/connection/http_executor"
require_relative "fp_qbo/connection/pool"
require_relative "fp_qbo/client"

# Optional: Resource abstractions
require_relative "fp_qbo/resources/base"
require_relative "fp_qbo/resources/customer"

# Standard library requirements
require "net/http"
require "uri"
require "json"
require "base64"
require "openssl"

module FpQbo
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def logger
      @logger ||= Logger.new
    end
  end
end
