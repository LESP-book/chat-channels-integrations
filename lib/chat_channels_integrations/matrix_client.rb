# frozen_string_literal: true

require "json"
require "socket"
require "timeout"
require "uri"

module ChatChannelsIntegrations
  class MatrixClient
    DEFAULT_TIMEOUT = 10
    NETWORK_ERRORS = [
      SocketError,
      Timeout::Error,
      EOFError,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH,
      Errno::ENETUNREACH,
      Errno::ETIMEDOUT,
    ].freeze

    class ConfigurationError < StandardError
    end

    class RequestError < StandardError
      attr_reader :status, :error_key

      def initialize(status: nil, error_key: "matrix_request_failed", transient: nil)
        @status = status
        @error_key = error_key
        @transient = transient.nil? ? status == 429 || status.to_i >= 500 : transient
        super("Matrix request failed: #{error_key} (HTTP #{status || "network"})")
      end

      def transient?
        @transient
      end
    end

    def initialize(
      homeserver:,
      access_token:,
      http_class: FinalDestination::HTTP,
      timeout: DEFAULT_TIMEOUT
    )
      @homeserver = parse_homeserver(homeserver)
      @access_token = access_token.to_s
      @http_class = http_class
      @timeout = timeout

      raise ConfigurationError, "Matrix access token is missing" if @access_token.empty?
    end

    def send_message(room_id:, transaction_id:, content:)
      request =
        @http_class::Put.new(
          request_path(room_id, transaction_id),
          {
            "Accept" => "application/json",
            "Authorization" => "Bearer #{@access_token}",
            "Content-Type" => "application/json",
          },
        )
      request.body = content.to_json

      response =
        @http_class.start(
          @homeserver.hostname,
          @homeserver.port,
          use_ssl: true,
          open_timeout: @timeout,
          read_timeout: @timeout,
        ) do |http|
          http.max_retries = 0
          http.request(request)
        end

      handle_response(response)
    rescue *NETWORK_ERRORS => error
      if error.class.name == "FinalDestination::SSRFError"
        raise ConfigurationError, "Matrix homeserver is not allowed"
      end

      raise RequestError.new(error_key: "matrix_network_error", transient: true)
    end

    private

    def parse_homeserver(value)
      uri = URI.parse(value.to_s)
      valid =
        uri.scheme == "https" && !uri.hostname.to_s.empty? && uri.user.nil? && uri.password.nil? &&
          uri.query.nil? && uri.fragment.nil?
      raise ConfigurationError, "Matrix homeserver must be an HTTPS origin or path" unless valid

      uri
    rescue URI::InvalidURIError
      raise ConfigurationError, "Matrix homeserver is invalid"
    end

    def request_path(room_id, transaction_id)
      base_path = @homeserver.path.to_s.sub(%r{/+\z}, "")
      encoded_room_id = URI.encode_www_form_component(room_id.to_s)
      encoded_transaction_id = URI.encode_www_form_component(transaction_id.to_s)

      "#{base_path}/_matrix/client/v3/rooms/#{encoded_room_id}/send/m.room.message/#{encoded_transaction_id}"
    end

    def handle_response(response)
      status = response.code.to_i
      return parse_json(response.body) if status.between?(200, 299)

      raise RequestError.new(status: status, error_key: response_error_key(response.body, status))
    end

    def response_error_key(body, status)
      errcode = parse_json(body)["errcode"]
      return "matrix_#{errcode.delete_prefix("M_").downcase}" if errcode && !errcode.empty?

      status == 429 ? "matrix_rate_limited" : "matrix_http_error"
    end

    def parse_json(body)
      return {} if body.to_s.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end
  end
end
