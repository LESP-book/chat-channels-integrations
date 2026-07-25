# frozen_string_literal: true

# name: chat-channels-integrations
# about: Forwards public Discourse Chat channel messages to Matrix rooms
# version: 0.1.0
# authors: LESP-book
# url: https://github.com/LESP-book/chat-channels-integrations
# required_version: 3.5.0

enabled_site_setting :chat_channels_integrations_enabled
register_asset "stylesheets/chat-channels-integrations.scss"

module ::ChatChannelsIntegrations
  PLUGIN_NAME = "chat-channels-integrations"
end

after_initialize do
  require_relative "app/initializers/chat_channels_integrations"

  on(:chat_message_created) do |message, _channel, _user, _options|
    Jobs.enqueue(
      Jobs::ChatChannelsIntegrations::DeliverMessage,
      chat_message_id: message.id,
    )
  end

  add_admin_route "chat_channels_integrations.admin.title",
                  "chat-channels-integrations",
                  use_new_show_route: true
end
