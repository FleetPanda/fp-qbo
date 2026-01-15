# frozen_string_literal: true

module FpQbo
  module Resources
    class Base
      attr_reader :client

      def initialize(client)
        @client = client
        @logger = FpQbo.logger
      end

      # Abstract method - must be implemented by subclasses
      def entity_name
        raise NotImplementedError, "Subclasses must implement entity_name"
      end

      # Abstract method - must be implemented by subclasses
      def required_fields
        raise NotImplementedError, "Subclasses must implement required_fields"
      end

      # Create a new entity
      def create(attributes)
        @logger.info("Creating #{entity_name}", attributes: sanitize_log_data(attributes))

        validate_required_fields!(attributes)
        payload = build_payload(attributes)

        response = client.post(
          endpoint: entity_name,
          payload: payload
        )

        handle_response(response, :create)
      end

      # Fetch an entity by ID
      def find(id)
        @logger.info("Fetching #{entity_name}", id: id)

        response = client.get(
          endpoint: "#{entity_name}/#{id}"
        )

        handle_response(response, :fetch)
      end

      # Update an entity
      def update(id, attributes)
        @logger.info("Updating #{entity_name}", id: id, attributes: sanitize_log_data(attributes))

        # First fetch to get sparse: false and SyncToken
        existing = find(id)
        return existing unless existing.success?

        current_data = existing.entity
        payload = build_update_payload(current_data, attributes)

        response = client.post(
          endpoint: entity_name,
          payload: payload,
          params: { operation: "update" }
        )

        handle_response(response, :update)
      end

      # Delete an entity (soft delete in QBO)
      def delete(id)
        @logger.info("Deleting #{entity_name}", id: id)

        # Fetch current entity to get SyncToken
        existing = find(id)
        return existing unless existing.success?

        current_data = existing.entity

        response = client.post(
          endpoint: entity_name,
          payload: {
            "Id" => id,
            "SyncToken" => current_data["SyncToken"]
          },
          params: { operation: "delete" }
        )

        handle_response(response, :delete)
      end

      # Query entities with filters
      def query(sql_query)
        @logger.info("Querying #{entity_name}", query: sql_query)

        response = client.get(
          endpoint: "query",
          params: { query: sql_query }
        )

        handle_query_response(response)
      end

      # List all entities with optional filters
      def list(filters = {})
        sql = build_list_query(filters)
        query(sql)
      end

      private

      # Validate that required fields are present
      def validate_required_fields!(attributes)
        missing_fields = required_fields.select do |field|
          attributes[field].nil? || attributes[field].to_s.strip.empty?
        end

        return unless missing_fields.any?

        raise FpQbo::ValidationError, "Missing required fields: #{missing_fields.join(", ")}"
      end

      # Build payload for create - to be customized by subclasses
      def build_payload(attributes)
        attributes
      end

      # Build payload for update - merge with existing data
      def build_update_payload(current_data, attributes)
        current_data.merge(attributes).merge({
                                               "Id" => current_data["Id"],
                                               "SyncToken" => current_data["SyncToken"]
                                             })
      end

      # Build SQL query for list
      def build_list_query(filters)
        query_parts = ["SELECT * FROM #{entity_name}"]

        query_parts << "WHERE #{filters[:where]}" if filters[:where]

        query_parts << "ORDERBY #{filters[:order_by]}" if filters[:order_by]

        query_parts << "MAXRESULTS #{filters[:limit]}" if filters[:limit]

        query_parts << "STARTPOSITION #{filters[:offset]}" if filters[:offset]

        query_parts.join(" ")
      end

      # Handle API response
      def handle_response(response, operation)
        if response.success?
          entity = response.data.dig(entity_name)

          FpQbo::Response::SuccessResponse.new(
            entity: entity,
            operation: operation,
            entity_type: entity_name
          )
        else
          FpQbo::Response::ErrorResponse.new(
            error: response.error,
            operation: operation,
            entity_type: entity_name
          )
        end
      end

      # Handle query response (returns array)
      def handle_query_response(response)
        if response.success?
          entities = response.data.dig("QueryResponse", entity_name) || []

          FpQbo::Response::SuccessResponse.new(
            entity: entities,
            operation: :query,
            entity_type: entity_name,
            metadata: {
              count: entities.size,
              max_results: response.data.dig("QueryResponse", "maxResults"),
              start_position: response.data.dig("QueryResponse", "startPosition")
            }
          )
        else
          FpQbo::Response::ErrorResponse.new(
            error: response.error,
            operation: :query,
            entity_type: entity_name
          )
        end
      end

      # Sanitize sensitive data for logging
      def sanitize_log_data(data)
        return data unless data.is_a?(Hash)

        sensitive_fields = %w[SSN CreditCardNumber AccountNumber]
        data.transform_values do |value|
          if value.is_a?(Hash)
            sanitize_log_data(value)
          elsif sensitive_fields.any? { |field| data.to_s.include?(field) }
            "[REDACTED]"
          else
            value
          end
        end
      end
    end
  end
end
