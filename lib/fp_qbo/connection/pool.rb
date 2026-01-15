# frozen_string_literal: true

module FpQbo
  module Connection
    class Pool
      def initialize(size: FpQbo.configuration.pool_size, timeout: FpQbo.configuration.pool_timeout)
        @size = size
        @timeout = timeout
        @available = []
        @connections = {}
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @logger = FpQbo.logger
      end

      def with_connection(realm_id)
        connection = checkout(realm_id)

        begin
          yield connection
        ensure
          checkin(realm_id, connection)
        end
      end

      def checkout(realm_id)
        start_time = Time.now
        connection = nil

        @mutex.synchronize do
          loop do
            connection = find_available_connection(realm_id)
            break if connection

            if can_create_connection?(realm_id)
              connection = create_connection(realm_id)
              break
            end

            elapsed = Time.now - start_time
            raise ConnectionError, "Could not acquire connection within #{@timeout}s" if elapsed >= @timeout

            remaining_timeout = @timeout - elapsed
            @condition.wait(@mutex, remaining_timeout)
          end

          mark_as_in_use(realm_id, connection)
        end

        @logger.debug("Connection checked out", realm_id: realm_id, pool_size: @connections[realm_id]&.size || 0)
        connection
      end

      def checkin(realm_id, connection)
        @mutex.synchronize do
          mark_as_available(realm_id, connection)
          @condition.signal
        end

        @logger.debug("Connection checked in", realm_id: realm_id)
      end

      def clear
        @mutex.synchronize do
          @connections.clear
          @available.clear
        end

        @logger.info("Connection pool cleared")
      end

      def size(realm_id = nil)
        @mutex.synchronize do
          if realm_id
            @connections[realm_id]&.size || 0
          else
            @connections.values.flatten.size
          end
        end
      end

      private

      def find_available_connection(realm_id)
        @available.find { |conn| conn[:realm_id] == realm_id && !conn[:in_use] }
      end

      def can_create_connection?(realm_id)
        (@connections[realm_id]&.size || 0) < @size
      end

      def create_connection(realm_id)
        connection = {
          realm_id: realm_id,
          created_at: Time.now,
          in_use: false
        }

        @connections[realm_id] ||= []
        @connections[realm_id] << connection
        @available << connection

        @logger.debug("New connection created", realm_id: realm_id, total: @connections[realm_id].size)

        connection
      end

      def mark_as_in_use(_realm_id, connection)
        connection[:in_use] = true
        connection[:checked_out_at] = Time.now
      end

      def mark_as_available(_realm_id, connection)
        connection[:in_use] = false
        connection[:checked_in_at] = Time.now
      end
    end
  end
end
