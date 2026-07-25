# frozen_string_literal: true

class CreateChatChannelsIntegrationsRules < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_channels_integrations_rules do |t|
      t.bigint :chat_channel_id, null: false
      t.string :matrix_room_id, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    add_index :chat_channels_integrations_rules,
              %i[chat_channel_id matrix_room_id],
              unique: true,
              name: "idx_chat_channels_integrations_rules_target"
    add_foreign_key :chat_channels_integrations_rules,
                    :chat_channels,
                    column: :chat_channel_id,
                    on_delete: :cascade
  end
end
