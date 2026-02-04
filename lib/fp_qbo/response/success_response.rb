# frozen_string_literal: true

module FpQbo
  module Response
    # Represents a successful API response from QuickBooks Online.
    # Provides helpers to access entities, metadata, and pagination info.
    class SuccessResponse
      attr_reader :data, :status_code, :headers, :request

      # Initializes a new SuccessResponse.
      #
      # @param data [Hash] The parsed response data.
      # @param status_code [Integer] The HTTP status code.
      # @param headers [Hash] The HTTP response headers.
      # @param request [FpQbo::Request::Request] The originating request.
      def initialize(data:, status_code:, headers:, request:)
        @data = data
        @status_code = status_code
        @headers = headers
        @request = request
      end

      # Returns true for a successful response.
      #
      # @return [Boolean]
      def success?
        true
      end

      # Returns false for a successful response.
      #
      # @return [Boolean]
      def error?
        false
      end

      # Get the main entity from the response
      # Returns the main entity from the response data, if present.
      #
      # @return [Object, nil] The main entity or nil.
      def entity
        # QBO Query responses
        if data.key?("QueryResponse")
          query_response = data["QueryResponse"]
          # Get the first entity type found
          entity_key = query_response.keys.find { |k| k != "startPosition" && k != "maxResults" && k != "totalCount" }
          return query_response[entity_key] if entity_key
        end

        # Single entity responses (Customer, Invoice, etc.)
        entity_key = data.keys.find { |k| k != "time" }
        data[entity_key] if entity_key
      end

      # Get metadata from query responses
      # Returns metadata from a query response, such as pagination info.
      #
      # @return [Hash] The metadata hash.
      def metadata
        return {} unless data.key?("QueryResponse")

        query_response = data["QueryResponse"]
        {
          start_position: query_response["startPosition"],
          max_results: query_response["maxResults"],
          total_count: query_response["totalCount"]
        }
      end

      # Check if there are more results
      # Checks if there are more results available in the query response.
      #
      # @return [Boolean] True if more results are available, false otherwise.
      def has_more?
        meta = metadata
        return false if meta.empty?

        start = meta[:start_position].to_i
        max = meta[:max_results].to_i
        total = meta[:total_count].to_i

        (start + max) < total
      end

      # Returns a hash representation of the success response.
      #
      # @return [Hash] The response attributes and metadata.
      def to_h
        {
          success: true,
          status_code: status_code,
          entity: entity,
          metadata: metadata,
          has_more: has_more?
        }
      end
    end
  end
end
