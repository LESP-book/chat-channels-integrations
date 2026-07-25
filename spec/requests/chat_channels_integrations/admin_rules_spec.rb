# frozen_string_literal: true

RSpec.describe "Chat Channels Integrations admin rules", type: :request do
  let(:admin) { Fabricate(:admin) }
  let(:category) { Fabricate(:category) }
  let(:channel) { Fabricate(:chat_channel, chatable: category) }

  before { SiteSetting.chat_channels_integrations_enabled = true }

  shared_examples "admin-only endpoint" do |method, path|
    it "returns 404 to anonymous and non-admin users" do
      public_send(method, path)
      expect(response.status).to eq(404)

      sign_in(Fabricate(:user))
      public_send(method, path)
      expect(response.status).to eq(404)
    end
  end

  include_examples "admin-only endpoint", :get, "/admin/plugins/chat-channels-integrations/rules.json"

  it "lets an administrator list public channels and manage mapping rules" do
    sign_in(admin)

    post "/admin/plugins/chat-channels-integrations/rules.json",
         params: {
           rule: {
             chat_channel_id: channel.id,
             matrix_room_id: "!room:matrix.example.com",
             enabled: true,
           },
         }

    expect(response.status).to eq(201)
    rule_id = response.parsed_body.dig("rule", "id")

    get "/admin/plugins/chat-channels-integrations/rules.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["channels"]).to include(
      hash_including("id" => channel.id, "name" => channel.title(admin)),
    )
    expect(response.parsed_body["rules"]).to include(
      hash_including(
        "id" => rule_id,
        "chat_channel_id" => channel.id,
        "matrix_room_id" => "!room:matrix.example.com",
      ),
    )

    put "/admin/plugins/chat-channels-integrations/rules/#{rule_id}.json",
        params: { rule: { enabled: false } }
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("rule", "enabled")).to eq(false)

    delete "/admin/plugins/chat-channels-integrations/rules/#{rule_id}.json"
    expect(response.status).to eq(200)
    expect(ChatChannelsIntegrations::Rule.exists?(rule_id)).to eq(false)
  end

  it "rejects direct-message mappings" do
    sign_in(admin)
    direct_channel = Fabricate(:direct_message_channel)

    post "/admin/plugins/chat-channels-integrations/rules.json",
         params: {
           rule: {
             chat_channel_id: direct_channel.id,
             matrix_room_id: "!room:matrix.example.com",
             enabled: true,
           },
         }

    expect(response.status).to eq(422)
  end
end
