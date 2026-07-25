# frozen_string_literal: true

module ChatChannelsIntegrations
  class AdminEngine < ::Rails::Engine
    engine_name "#{PLUGIN_NAME}-admin"
    isolate_namespace ChatChannelsIntegrations
  end
end

require_relative "../models/chat_channels_integrations/rule"
require_relative "../../lib/chat_channels_integrations/message_formatter"
require_relative "../../lib/chat_channels_integrations/matrix_client"
require_relative "../jobs/regular/chat_channels_integrations/deliver_message"
require_relative "../serializers/chat_channels_integrations/rule_serializer"
require_relative "../controllers/chat_channels_integrations/admin/rules_controller"
require_relative "../routes/chat_channels_integrations"
require_relative "../routes/discourse"
