# frozen_string_literal: true

module FpQbo
  module Connection
    class HttpExecutor
      def initialize(config: FpQbo.configuration, logger: FpQbo.logger)
        @config = config
        @logger = logger
      end

      def execute(request)
        attempts = 0
        start_time = Time.now

        begin
          attempts += 1
          @logger.debug("Executing request", attempt: attempts, request: request.to_h)

          http_response = send_request(request)
          duration = Time.now - start_time

          @logger.info(
            "Request completed",
            status: http_response.code,
            duration: duration.round(3),
            attempts: attempts
          )

          http_response
        rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
          if attempts < @config.retry_count
            delay = calculate_backoff(attempts)
            @logger.warn(
              "Request failed, retrying",
              error: e.class.name,
              attempt: attempts,
              retry_in: delay
            )
            sleep(delay)
            retry
          else
            @logger.error("Request failed after retries", error: e.message, attempts: attempts)
            raise NetworkError.new("Network error after #{attempts} attempts: #{e.message}", original_error: e)
          end
        rescue StandardError => e
          @logger.error("Unexpected error during request", error: e.message, class: e.class.name)
          raise ConnectionError.new("Connection error: #{e.message}", original_error: e)
        end
      end

      private

      def send_request(request)
        uri = URI(request.url)

        http = build_http_client(uri)
        http_request = build_http_request(request, uri)

        http.request(http_request)
      end

      def build_http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.verify_mode = @config.validate_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        http.open_timeout = @config.open_timeout
        http.read_timeout = @config.read_timeout

        http
      end

      def build_http_request(request, uri)
        http_request_class = case request.method
                             when :get then Net::HTTP::Get
                             when :post then Net::HTTP::Post
                             when :put then Net::HTTP::Put
                             when :delete then Net::HTTP::Delete
                             else
                               raise ArgumentError, "Unsupported HTTP method: #{request.method}"
                             end

        http_request = http_request_class.new(uri.request_uri)

        request.headers.each { |key, value| http_request[key] = value }
        http_request.body = request.body if request.body

        http_request
      end

      def calculate_backoff(attempt)
        delay = @config.retry_delay * (2**(attempt - 1))
        [delay, @config.max_retry_delay].min
      end
    end
  end
end
