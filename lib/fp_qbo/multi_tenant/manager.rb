# frozen_string_literal: true

module FpQbo
  module MultiTenant
    class Manager
      def initialize(config: FpQbo.configuration)
        @config = config
        @clients = {}
        @mutex = Mutex.new
        @logger = FpQbo.logger
      end

      def client_for(realm_id:, access_token:, refresh_token:, expires_at: nil)
        @mutex.synchronize do
          key = client_key(realm_id)

          # Return existing client if valid
          if @clients.key?(key)
            client = @clients[key]
            return client if client.valid_token?

            @logger.info("Existing client token invalid, creating new", realm_id: realm_id)
          end

          # Create new client
          client = FpQbo::Client.new(
            access_token: access_token,
            refresh_token: refresh_token,
            realm_id: realm_id,
            expires_at: expires_at,
            config: @config
          )

          @clients[key] = client
          @logger.info("New client created", realm_id: realm_id, total_clients: @clients.size)

          client
        end
      end

      def remove_client(realm_id)
        @mutex.synchronize do
          key = client_key(realm_id)
          @clients.delete(key)
          @logger.info("Client removed", realm_id: realm_id)
        end
      end

      def clear_all
        @mutex.synchronize do
          count = @clients.size
          @clients.clear
          @logger.info("All clients cleared", count: count)
        end
      end

      def refresh_all
        @mutex.synchronize do
          @clients.each do |_key, client|
            next unless client.token_expires_soon?

            begin
              client.refresh_token!
              @logger.info("Token refreshed", realm_id: client.realm_id)
            rescue StandardError => e
              @logger.error("Failed to refresh token", realm_id: client.realm_id, error: e.message)
            end
          end
        end
      end

      def client_count
        @mutex.synchronize { @clients.size }
      end

      def realm_ids
        @mutex.synchronize { @clients.keys.map { |k| k.split(":").last } }
      end

      private

      def client_key(realm_id)
        "qbo:#{realm_id}"
      end
    end
  end
end
