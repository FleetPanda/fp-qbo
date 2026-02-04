# frozen_string_literal: true

module FpQbo
  module Connection
    # Executes HTTP requests for the QuickBooks Online API, handling retries, logging, and error management.
    class HttpExecutor
      # Initializes a new HttpExecutor.
      #
      # @param config [FpQbo::Configuration] The configuration object.
      # @param logger [Logger] The logger instance.
      def initialize(config: FpQbo.configuration, logger: FpQbo.logger)
        @config = config
        @logger = logger
      end

      # Executes an HTTP request, handling retries and logging.
      #
      # @param request [FpQbo::Request::Request] The request to execute.
      # @return [Net::HTTPResponse] The HTTP response.
      # @raise [NetworkError, ConnectionError] If the request fails after retries or encounters an unexpected error.
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

      # Sends the HTTP request using Net::HTTP.
      #
      # @param request [FpQbo::Request::Request] The request to send.
      # @return [Net::HTTPResponse] The HTTP response.
      def send_request(request)
        uri = URI(request.url)

        http = build_http_client(uri)
        http_request = build_http_request(request, uri)

        http.request(http_request)
      end

      # Builds a Net::HTTP client for the given URI, with SSL and timeout settings.
      #
      # @param uri [URI] The URI for the HTTP client.
      # @return [Net::HTTP] The configured HTTP client.
      def build_http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.verify_mode = @config.validate_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        http.open_timeout = @config.open_timeout
        http.read_timeout = @config.read_timeout

        http
      end

      # Builds a Net::HTTP request object for the given method and URI.
      #
      # @param request [FpQbo::Request::Request] The request to build from.
      # @param uri [URI] The URI for the request.
      # @return [Net::HTTPRequest] The HTTP request object.
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

      # Calculates the exponential backoff delay for retries.
      #
      # @param attempt [Integer] The current attempt number.
      # @return [Numeric] The delay in seconds.
      def calculate_backoff(attempt)
        delay = @config.retry_delay * (2**(attempt - 1))
        [delay, @config.max_retry_delay].min
      end
    end
  end
end
