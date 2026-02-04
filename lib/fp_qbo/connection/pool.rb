# frozen_string_literal: true

module FpQbo
  module Connection
    # Manages a pool of HTTP connections for efficient reuse and concurrency.
    # Handles connection checkout, checkin, and pool size/timeouts.
    class Pool
      # Initializes a new connection pool.
      #
      # @param size [Integer] The maximum number of connections per realm.
      # @param timeout [Numeric] The maximum time to wait for a connection.
      def initialize(size: FpQbo.configuration.pool_size, timeout: FpQbo.configuration.pool_timeout)
        @size = size
        @timeout = timeout
        @available = []
        @connections = {}
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @logger = FpQbo.logger
      end

      # Yields a connection for the given realm_id, ensuring checkin after use.
      #
      # @param realm_id [String] The QuickBooks company ID.
      # @yield [connection] The acquired connection.
      def with_connection(realm_id)
        connection = checkout(realm_id)

        begin
          yield connection
        ensure
          checkin(realm_id, connection)
        end
      end

      # Checks out a connection for the given realm_id, waiting if necessary.
      #
      # @param realm_id [String] The QuickBooks company ID.
      # @return [Hash] The checked-out connection.
      # @raise [ConnectionError] If a connection cannot be acquired in time.
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

      # Checks a connection back into the pool for the given realm_id.
      #
      # @param realm_id [String] The QuickBooks company ID.
      # @param connection [Hash] The connection to check in.
      def checkin(realm_id, connection)
        @mutex.synchronize do
          mark_as_available(realm_id, connection)
          @condition.signal
        end

        @logger.debug("Connection checked in", realm_id: realm_id)
      end

      # Clears all connections from the pool.
      def clear
        @mutex.synchronize do
          @connections.clear
          @available.clear
        end

        @logger.info("Connection pool cleared")
      end

      # Returns the number of connections in the pool, optionally for a specific realm_id.
      #
      # @param realm_id [String, nil] The QuickBooks company ID (optional).
      # @return [Integer] The number of connections.
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

      # Finds an available connection for the given realm_id.
      #
      # @param realm_id [String] The QuickBooks company ID.
      # @return [Hash, nil] The available connection or nil.
      def find_available_connection(realm_id)
        @available.find { |conn| conn[:realm_id] == realm_id && !conn[:in_use] }
      end

      # Checks if a new connection can be created for the given realm_id.
      #
      # @param realm_id [String] The QuickBooks company ID.
      # @return [Boolean] True if a new connection can be created, false otherwise.
      def can_create_connection?(realm_id)
        (@connections[realm_id]&.size || 0) < @size
      end

      # Creates a new connection for the given realm_id.
      #
      # @param realm_id [String] The QuickBooks company ID.
      # @return [Hash] The new connection.
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

      # Marks a connection as in use.
      #
      # @param _realm_id [String] The QuickBooks company ID (unused).
      # @param connection [Hash] The connection to mark.
      def mark_as_in_use(_realm_id, connection)
        connection[:in_use] = true
        connection[:checked_out_at] = Time.now
      end

      # Marks a connection as available.
      #
      # @param _realm_id [String] The QuickBooks company ID (unused).
      # @param connection [Hash] The connection to mark.
      def mark_as_available(_realm_id, connection)
        connection[:in_use] = false
        connection[:checked_in_at] = Time.now
      end
    end
  end
end
