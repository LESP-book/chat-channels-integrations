# frozen_string_literal: true

module ChatChannelsIntegrations
  class RuleSerializer < ApplicationSerializer
    attributes :id, :chat_channel_id, :matrix_room_id, :enabled, :created_at, :updated_at

    attribute :chat_channel_name

    def chat_channel_name
      object.chat_channel.title(scope&.user)
    end
  end
end
