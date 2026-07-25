# frozen_string_literal: true

Discourse::Application.routes.append do
  mount ChatChannelsIntegrations::AdminEngine,
        at: "/admin/plugins/chat-channels-integrations",
        constraints: AdminConstraint.new
end
