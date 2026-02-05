# frozen_string_literal: true

require_relative "authentication/oauth_manager"
require_relative "request/builder"
require_relative "response/handler"
require_relative "connection/http_executor"

module FpQbo
  # Main API client for QuickBooks Online, providing CRUD, batch, and token management operations.
  # Handles authentication, request building, response handling, and error management.
  class Client
    attr_reader :oauth_manager, :realm_id

    # Initializes a new FpQbo::Client.
    #
    # @param access_token [String] The OAuth2 access token.
    # @param refresh_token [String] The OAuth2 refresh token.
    # @param realm_id [String] The QuickBooks company ID.
    # @param expires_at [Time, String, nil] The expiration time as a Time or ISO8601 string.
    # @param expires_in [Integer, nil] The number of seconds until expiration.
    # @param config [FpQbo::Configuration, nil] The configuration object (optional).
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

    # Runs a query against the QuickBooks Online API for the given entity.
    #
    # @param entity [String] The entity to query (e.g., "Customer").
    # @param conditions [String, nil] Optional WHERE conditions.
    # @param select [String] Fields to select (default: "*").
    # @param limit [Integer] Maximum number of results (default: 100).
    # @param offset [Integer] Offset for pagination (default: 0).
    # @param params [Hash] Additional query parameters.
    # @return [Object] The API response.
    def query(entity:, conditions: nil, select: "*", limit: 100, offset: 0, params: {})
      ensure_valid_token!
      query_string = build_query_string(entity, conditions, select, limit, offset)

      query_params = { query: query_string }.merge(params)

      request = @request_builder.build(
        method: :get,
        endpoint: "query",
        query: query_params
      )
      execute_request(request)
    end

    # Finds a single entity by ID.
    #
    # @param entity [String] The entity type (e.g., "Customer").
    # @param id [String, Integer] The entity ID.
    # @return [Object] The API response.
    def find(entity:, id:)
      ensure_valid_token!

      request = @request_builder.build(
        method: :get,
        endpoint: "#{entity.downcase}/#{id}"
      )

      execute_request(request)
    end

    # Creates a new entity in QuickBooks Online.
    #
    # @param entity [String] The entity type (e.g., "Customer").
    # @param data [Hash] The data for the new entity.
    # @return [Object] The API response.
    def create(entity:, data:)
      ensure_valid_token!

      request = @request_builder.build(
        method: :post,
        endpoint: entity.downcase,
        body: data
      )

      execute_request(request)
    end

    # Updates an existing entity in QuickBooks Online.
    #
    # @param entity [String] The entity type (e.g., "Customer").
    # @param id [String, Integer] The entity ID.
    # @param data [Hash] The updated data.
    # @param sparse [Boolean] Whether to use sparse update (default: true).
    # @return [Object] The API response.
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

    # Deletes an entity in QuickBooks Online.
    #
    # @param entity [String] The entity type (e.g., "Customer").
    # @param id [String, Integer] The entity ID.
    # @param sync_token [String, Integer] The sync token for the entity.
    # @return [Object] The API response.
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

    # Refreshes the OAuth2 token and returns the new token data.
    #
    # @return [Hash] The new token data for persistence.
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

    # Checks if the current token is valid.
    #
    # @return [Boolean] True if the token is valid, false otherwise.
    def valid_token?
      @oauth_manager.valid?
    end

    # Checks if the token is about to expire and needs refresh.
    #
    # @return [Boolean] True if the token expires soon, false otherwise.
    def token_expires_soon?
      @oauth_manager.refresh_needed?
    end

    # Company info

    # Retrieves company information for the current realm.
    #
    # @return [Object] The API response.
    def company_info
      ensure_valid_token!

      request = @request_builder.build(
        method: :get,
        endpoint: "companyinfo/#{realm_id}"
      )

      execute_request(request)
    end

    # Batch operations

    # Executes a batch of operations in a single API call.
    #
    # @param operations [Array<Hash>] The operations to batch.
    # @return [Object] The API response.
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

    # Builds a SQL-like query string for QuickBooks Online.
    #
    # @param entity [String] The entity type.
    # @param conditions [String, nil] Optional WHERE conditions.
    # @param select [String] Fields to select.
    # @param limit [Integer] Maximum number of results.
    # @param offset [Integer] Offset for pagination.
    # @return [String] The constructed query string.
    def build_query_string(entity, conditions, select, limit, offset)
      query = "SELECT #{select} FROM #{entity}"
      query += " WHERE #{conditions}" if conditions
      query += " STARTPOSITION #{offset + 1}" if offset > 0
      query += " MAXRESULTS #{limit}"
      query
    end

    # Ensures the current token is valid, refreshing if necessary or raising if not possible.
    #
    # @raise [TokenExpiredError] If the token is expired and cannot be refreshed.
    def ensure_valid_token!
      return if @oauth_manager.valid?

      raise TokenExpiredError, "Access token has expired" unless @config.auto_refresh_token && @oauth_manager.token.refresh_token

      @logger.info("Token invalid, attempting auto-refresh", realm_id: realm_id)
      @oauth_manager.refresh!
    end

    # Executes the given request and handles errors, including rate limiting.
    #
    # @param request [FpQbo::Request::Request] The request to execute.
    # @return [Object] The API response.
    def execute_request(request)
      http_response = @http_executor.execute(request)
      response = @response_handler.handle(http_response, request)

      # Raise exception if error and not in lenient mode
      response.raise_exception! if response.error?

      response
    rescue RateLimitError => e
      handle_rate_limit_error(e, request)
    end

    # Handles a rate limit error by retrying the request after a delay, if configured.
    #
    # @param error [RateLimitError] The rate limit error.
    # @param request [FpQbo::Request::Request] The request to retry.
    # @return [Object] The API response after retrying.
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
