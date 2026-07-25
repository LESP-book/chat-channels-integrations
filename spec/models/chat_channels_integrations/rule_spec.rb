# frozen_string_literal: true

RSpec.describe ChatChannelsIntegrations::Rule do
  let(:category) { Fabricate(:category) }
  let(:public_channel) { Fabricate(:chat_channel, chatable: category) }

  it "accepts multiple Matrix rooms for one public channel and rejects duplicate targets" do
    described_class.create!(
      chat_channel: public_channel,
      matrix_room_id: "!first:matrix.example.com",
    )
    described_class.create!(
      chat_channel: public_channel,
      matrix_room_id: "!second:matrix.example.com",
    )

    duplicate =
      described_class.new(
        chat_channel: public_channel,
        matrix_room_id: "!first:matrix.example.com",
      )

    expect(duplicate).not_to be_valid
  end

  it "rejects direct-message channels and malformed room IDs" do
    direct_channel = Fabricate(:direct_message_channel)

    direct_rule =
      described_class.new(
        chat_channel: direct_channel,
        matrix_room_id: "!room:matrix.example.com",
      )
    malformed_rule =
      described_class.new(chat_channel: public_channel, matrix_room_id: "room name")

    expect(direct_rule).not_to be_valid
    expect(malformed_rule).not_to be_valid
  end
end
