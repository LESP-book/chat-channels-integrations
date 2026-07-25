# frozen_string_literal: true

module Jobs
  module ChatChannelsIntegrations
    class DeliverMessage < ::Jobs::Base
      sidekiq_options retry: false

      MAX_ATTEMPTS = 3
      RETRY_DELAYS = [30.seconds, 2.minutes, 10.minutes].freeze

      def execute(args = {})
        return unless SiteSetting.chat_channels_integrations_enabled

        message = ::Chat::Message.includes(:user, :chat_channel, :uploads).find_by(
          id: args[:chat_message_id],
        )
        return unless message

        channel = message.chat_channel
        user = message.user
        return unless channel && user && channel.public_channel?
        return if ::Chat::WebhookEvent.exists?(chat_message_id: message.id)

        rules = ::ChatChannelsIntegrations::Rule.enabled.where(chat_channel_id: channel.id)
        return if rules.empty?
        return unless matrix_configured?

        content =
          ::ChatChannelsIntegrations::MessageFormatter.new(
            message: message,
            channel: channel,
            user: user,
            use_notice: SiteSetting.chat_channels_integrations_matrix_use_notice,
          ).content
        client = build_client(message, channel, rules)
        return unless client

        transient_failure = false
        rules.find_each do |rule|
          client.send_message(
            room_id: rule.matrix_room_id,
            transaction_id: "chat-#{message.id}-rule-#{rule.id}",
            content: content,
          )
        rescue ::ChatChannelsIntegrations::MatrixClient::RequestError => error
          transient_failure ||= error.transient?
          log_failure(message, channel, rule, error.status || "network", error.error_key)
        rescue ::ChatChannelsIntegrations::MatrixClient::ConfigurationError => error
          log_failure(message, channel, rule, "configuration", error.message)
        end

        schedule_retry(message.id, args[:attempt].to_i) if transient_failure
      end

      private

      def build_client(message, channel, rules)
        ::ChatChannelsIntegrations::MatrixClient.new(
          homeserver: SiteSetting.chat_channels_integrations_matrix_homeserver,
          access_token: SiteSetting.chat_channels_integrations_matrix_access_token,
        )
      rescue ::ChatChannelsIntegrations::MatrixClient::ConfigurationError => error
        rules.each do |rule|
          log_failure(message, channel, rule, "configuration", error.message)
        end
        nil
      end

      def matrix_configured?
        SiteSetting.chat_channels_integrations_matrix_homeserver.present? &&
          SiteSetting.chat_channels_integrations_matrix_access_token.present?
      end

      def schedule_retry(chat_message_id, attempt)
        return if attempt >= MAX_ATTEMPTS

        ::Jobs.enqueue_in(
          RETRY_DELAYS.fetch(attempt),
          self.class,
          chat_message_id: chat_message_id,
          attempt: attempt + 1,
        )
      end

      def log_failure(message, channel, rule, status, error_key)
        Rails.logger.error(
          "[chat-channels-integrations] Matrix delivery failed " \
            "chat_message_id=#{message.id} chat_channel_id=#{channel.id} " \
            "matrix_room_id=#{rule.matrix_room_id} http_status=#{status} " \
            "error_key=#{error_key}",
        )
      end
    end
  end
end
