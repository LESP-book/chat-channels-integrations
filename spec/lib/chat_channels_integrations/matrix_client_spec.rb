# frozen_string_literal: true

RSpec.describe ChatChannelsIntegrations::MatrixClient do
  subject(:client) do
    described_class.new(homeserver: homeserver, access_token: "secret-token")
  end

  let(:homeserver) { "https://matrix.example.com/base" }
  let(:content) { { "msgtype" => "m.notice", "body" => "hello" } }

  it "sends a v3 PUT with Bearer authentication and no token in the URL" do
    stub =
      stub_request(
        :put,
        "https://matrix.example.com/base/_matrix/client/v3/rooms/%21room%3Amatrix.example.com/send/m.room.message/txn-1",
      ).with(
        headers: {
          "Authorization" => "Bearer secret-token",
          "Content-Type" => "application/json",
        },
        body: content.to_json,
      ).to_return(status: 200, body: '{"event_id":"$event"}')

    client.send_message(
      room_id: "!room:matrix.example.com",
      transaction_id: "txn-1",
      content: content,
    )

    expect(stub).to have_been_requested.once
    expect(stub.request_pattern.uri_pattern.to_s).not_to include("secret-token")
  end

  it "marks HTTP 429 and 5xx as transient but authentication and room errors as permanent" do
    stub_request(:put, %r{matrix\.example\.com}).to_return(status: 429)
    expect { client.send_message(room_id: "!room:example.com", transaction_id: "one", content: content) }
      .to raise_error(described_class::RequestError) { |error| expect(error).to be_transient }

    stub_request(:put, %r{matrix\.example\.com}).to_return(status: 503)
    expect { client.send_message(room_id: "!room:example.com", transaction_id: "two", content: content) }
      .to raise_error(described_class::RequestError) { |error| expect(error).to be_transient }

    stub_request(:put, %r{matrix\.example\.com}).to_return(
      status: 403,
      body: '{"errcode":"M_FORBIDDEN"}',
    )
    expect { client.send_message(room_id: "!room:example.com", transaction_id: "three", content: content) }
      .to raise_error(described_class::RequestError) do |error|
        expect(error).not_to be_transient
        expect(error.status).to eq(403)
        expect(error.error_key).to eq("matrix_forbidden")
      end
  end

  it "rejects non-HTTPS homeservers and embedded credentials" do
    expect do
      described_class.new(homeserver: "http://matrix.example.com", access_token: "token")
    end.to raise_error(described_class::ConfigurationError)

    expect do
      described_class.new(homeserver: "https://user:pass@matrix.example.com", access_token: "token")
    end.to raise_error(described_class::ConfigurationError)
  end
end
