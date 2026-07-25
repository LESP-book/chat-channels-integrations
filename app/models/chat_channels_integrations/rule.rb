# frozen_string_literal: true

module ChatChannelsIntegrations
  class Rule < ActiveRecord::Base
    self.table_name = "chat_channels_integrations_rules"

    belongs_to :chat_channel, class_name: "Chat::Channel"

    validates :chat_channel, presence: true
    validates :matrix_room_id,
              presence: true,
              format: {
                with: /\A![^\s:]+:[^\s:]+(?:\:\d+)?\z/,
              },
              uniqueness: {
                scope: :chat_channel_id,
              }
    validate :chat_channel_must_be_public

    scope :enabled, -> { where(enabled: true) }

    private

    def chat_channel_must_be_public
      return if chat_channel&.public_channel?

      errors.add(:chat_channel, :invalid)
    end
  end
end
