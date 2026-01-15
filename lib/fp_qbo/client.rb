# frozen_string_literal: true

require_relative "authentication/oauth_manager"
require_relative "request/builder"
require_relative "response/handler"
require_relative "connection/http_executor"

module FpQbo
  class Client
    attr_reader :oauth_manager, :realm_id

    def initialize(access_token:, refresh_token:, realm_id:, expires_at: nil, expires_in: nil, config: nil)
      @config = config || FpQbo.configuration
      @logger = FpQbo.logger

      token = Authentication::Token.new(
        access_token: access_token,
        refresh_token: refresh_token,
        realm_id: realm_id,
        expires_at: expires_at,
        expires_in: expires_in
      )

      @oauth_manager = Authentication::OAuthManager.new(token)
      @request_builder = Request::Builder.new(@oauth_manager, config: @config)
      @response_handler = Response::Handler.new(logger: @logger)
      @http_executor = Connection::HttpExecutor.new(config: @config, logger: @logger)

      @realm_id = realm_id
    end

    # Core CRUD operations

    def query(entity:, conditions: nil, select: "*", limit: 100, offset: 0)
      ensure_valid_token!

      query_string = build_query_string(entity, conditions, select, limit, offset)

      request = @request_builder.build(
        method: :get,
        endpoint: "query",
        query: { query: query_string }
      )

      execute_request(request)
    end

    def find(entity:, id:)
      ensure_valid_token!

      request = @request_builder.build(
        method: :get,
        endpoint: "#{entity.downcase}/#{id}"
      )

      execute_request(request)
    end

    def create(entity:, data:)
      ensure_valid_token!

      request = @request_builder.build(
        method: :post,
        endpoint: entity.downcase,
        body: data
      )

      execute_request(request)
    end

    def update(entity:, id:, data:, sparse: true)
      ensure_valid_token!

      # QBO requires the ID in the body for updates
      update_data = data.merge("Id" => id.to_s)
      update_data["sparse"] = sparse if sparse

      request = @request_builder.build(
        method: :post,
        endpoint: entity.downcase,
        body: update_data
      )

      execute_request(request)
    end

    def delete(entity:, id:, sync_token:)
      ensure_valid_token!

      request = @request_builder.build(
        method: :post,
        endpoint: entity.downcase,
        query: { operation: "delete" },
        body: {
          "Id" => id.to_s,
          "SyncToken" => sync_token.to_s
        }
      )

      execute_request(request)
    end

    # Token management

    def refresh_token!
      result = @oauth_manager.refresh!

      # Return new token data for persistence
      {
        access_token: result.access_token,
        refresh_token: result.refresh_token,
        expires_at: result.expires_at,
        realm_id: result.realm_id
      }
    end

    def valid_token?
      @oauth_manager.valid?
    end

    def token_expires_soon?
      @oauth_manager.refresh_needed?
    end

    # Company info

    def company_info
      ensure_valid_token!

      request = @request_builder.build(
        method: :get,
        endpoint: "companyinfo/#{realm_id}"
      )

      execute_request(request)
    end

    # Batch operations

    def batch(operations)
      ensure_valid_token!

      batch_request = {
        "BatchItemRequest" => operations.map.with_index do |op, index|
          {
            "bId" => "bid#{index}",
            "operation" => op[:operation],
            "#{op[:entity]}" => op[:data]
          }
        end
      }

      request = @request_builder.build(
        method: :post,
        endpoint: "batch",
        body: batch_request
      )

      execute_request(request)
    end

    def build_query_string(entity, conditions, select, limit, offset)
      query = "SELECT #{select} FROM #{entity}"
      query += " WHERE #{conditions}" if conditions
      query += " STARTPOSITION #{offset + 1}" if offset > 0
      query += " MAXRESULTS #{limit}"
      query
    end

    def ensure_valid_token!
      return if @oauth_manager.valid?

      unless @config.auto_refresh_token && @oauth_manager.token.refresh_token
        raise TokenExpiredError, "Access token has expired"
      end

      @logger.info("Token invalid, attempting auto-refresh", realm_id: realm_id)
      @oauth_manager.refresh!
    end

    def execute_request(request)
      http_response = @http_executor.execute(request)
      response = @response_handler.handle(http_response, request)

      # Raise exception if error and not in lenient mode
      response.raise_exception! if response.error?

      response
    rescue RateLimitError => e
      handle_rate_limit_error(e, request)
    end

    def handle_rate_limit_error(error, request)
      retry_after = error.retry_after || 60

      @logger.warn("Rate limit hit", retry_after: retry_after, realm_id: realm_id)

      raise error unless @config.retry_count > 0

      sleep(retry_after)
      http_response = @http_executor.execute(request)
      @response_handler.handle(http_response, request)
    end
  end
end
