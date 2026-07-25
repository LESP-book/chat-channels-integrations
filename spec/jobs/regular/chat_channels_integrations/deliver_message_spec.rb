# frozen_string_literal: true

RSpec.describe Jobs::ChatChannelsIntegrations::DeliverMessage do
  subject(:job) { described_class.new }

  let(:user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }
  let(:channel) { Fabricate(:chat_channel, chatable: category) }
  let(:message) do
    Fabricate(
      :chat_message,
      chat_channel: channel,
      user: user,
      message: "hello",
      cooked: "<p>hello</p>",
    )
  end
  let!(:first_rule) do
    ChatChannelsIntegrations::Rule.create!(
      chat_channel: channel,
      matrix_room_id: "!first:matrix.example.com",
    )
  end
  let!(:second_rule) do
    ChatChannelsIntegrations::Rule.create!(
      chat_channel: channel,
      matrix_room_id: "!second:matrix.example.com",
    )
  end
  let(:client) { instance_double(ChatChannelsIntegrations::MatrixClient, send_message: nil) }

  before do
    SiteSetting.chat_channels_integrations_enabled = true
    SiteSetting.chat_channels_integrations_matrix_homeserver = "https://matrix.example.com"
    SiteSetting.chat_channels_integrations_matrix_access_token = "token"
    SiteSetting.chat_channels_integrations_matrix_use_notice = true
    allow(ChatChannelsIntegrations::MatrixClient).to receive(:new).and_return(client)
  end

  it "reloads records and delivers to every enabled rule with stable transaction IDs" do
    job.execute(chat_message_id: message.id)

    expect(client).to have_received(:send_message).with(
      room_id: first_rule.matrix_room_id,
      transaction_id: "chat-#{message.id}-rule-#{first_rule.id}",
      content: hash_including("msgtype" => "m.notice", "body" => include("hello")),
    )
    expect(client).to have_received(:send_message).with(
      room_id: second_rule.matrix_room_id,
      transaction_id: "chat-#{message.id}-rule-#{second_rule.id}",
      content: hash_including("msgtype" => "m.notice", "body" => include("hello")),
    )
  end

  it "skips incoming webhook and direct-message records" do
    allow(Chat::WebhookEvent).to receive(:exists?).with(chat_message_id: message.id).and_return(true)
    job.execute(chat_message_id: message.id)
    expect(client).not_to have_received(:send_message)

    allow(Chat::WebhookEvent).to receive(:exists?).and_return(false)
    allow_any_instance_of(Chat::Channel).to receive(:public_channel?).and_return(false)
    job.execute(chat_message_id: message.id)
    expect(client).not_to have_received(:send_message)
  end

  it "re-enqueues transient failures a finite number of times and leaves permanent failures terminal" do
    transient =
      ChatChannelsIntegrations::MatrixClient::RequestError.new(
        status: 503,
        error_key: "matrix_server_error",
      )
    allow(client).to receive(:send_message).and_raise(transient)

    expect { job.execute(chat_message_id: message.id, attempt: 0) }.to change {
      Jobs::ChatChannelsIntegrations::DeliverMessage.jobs.size
    }.by(1)

    Jobs::ChatChannelsIntegrations::DeliverMessage.jobs.clear
    permanent =
      ChatChannelsIntegrations::MatrixClient::RequestError.new(
        status: 403,
        error_key: "matrix_forbidden",
      )
    allow(client).to receive(:send_message).and_raise(permanent)

    expect { job.execute(chat_message_id: message.id, attempt: 0) }.not_to change {
      Jobs::ChatChannelsIntegrations::DeliverMessage.jobs.size
    }
  end
end
