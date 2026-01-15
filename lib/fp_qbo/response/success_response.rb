# frozen_string_literal: true

module FpQbo
  module Response
    class SuccessResponse
      attr_reader :data, :status_code, :headers, :request

      def initialize(data:, status_code:, headers:, request:)
        @data = data
        @status_code = status_code
        @headers = headers
        @request = request
      end

      def success?
        true
      end

      def error?
        false
      end

      # Get the main entity from the response
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
      def has_more?
        meta = metadata
        return false if meta.empty?

        start = meta[:start_position].to_i
        max = meta[:max_results].to_i
        total = meta[:total_count].to_i

        (start + max) < total
      end

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
