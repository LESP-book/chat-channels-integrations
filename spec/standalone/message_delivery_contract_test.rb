# frozen_string_literal: true

require "minitest/autorun"
require "ostruct"

require_relative "../../lib/chat_channels_integrations/message_formatter"
require_relative "../../lib/chat_channels_integrations/matrix_client"

class FakeHTTP
  Response = Struct.new(:code, :body, keyword_init: true)

  class Put
    attr_accessor :body
    attr_reader :path, :headers

    def initialize(path, headers)
      @path = path
      @headers = headers
    end
  end

  attr_accessor :max_retries

  class << self
    attr_accessor :response
    attr_reader :last_request, :start_options, :max_retries

    def start(host, port, **options)
      @start_options = { host: host, port: port, **options }
      @instance = new
      result = yield @instance
      @max_retries = @instance.max_retries
      result
    end

    def reset!
      @response = Response.new(code: "200", body: '{"event_id":"$event"}')
      @last_request = nil
      @start_options = nil
      @max_retries = nil
    end

    def capture(request)
      @last_request = request
      response
    end
  end

  def request(request)
    self.class.capture(request)
  end
end

class MessageFormatterContractTest < Minitest::Test
  def test_escapes_html_and_preserves_plain_text_context
    message =
      OpenStruct.new(
        message: "hello <b>world</b>\nsecond line",
        uploads: [OpenStruct.new(original_filename: "<guide>.pdf")],
        full_url: "https://forum.example.com/chat/c/-/12/345?x=1&y=2",
      )
    channel = OpenStruct.new(id: 12, name: "General & Help", title: "General & Help")
    user = OpenStruct.new(username: "alice", display_name: "Alice <Admin>")

    content =
      ChatChannelsIntegrations::MessageFormatter.new(
        message: message,
        channel: channel,
        user: user,
        use_notice: true,
      ).content

    assert_equal "m.notice", content["msgtype"]
    assert_includes content["body"], "Alice <Admin> (@alice)"
    assert_includes content["body"], "#General & Help"
    refute_includes content["body"], "##General & Help"
    assert_includes content["body"], "hello <b>world</b>\nsecond line"
    assert_includes content["body"], "<guide>.pdf"
    assert_includes content["body"], "> hello <b>world</b>\n> second line"
    refute_includes content["body"], "在 Discourse 中查看"
    refute_includes content["body"], "请在 Discourse 中查看"
    assert_includes content["formatted_body"], "Alice &lt;Admin&gt; (@alice)"
    assert_includes content["formatted_body"], "#General &amp; Help"
    refute_includes content["formatted_body"], "##General &amp; Help"
    assert_includes content["formatted_body"], "hello &lt;b&gt;world&lt;/b&gt;<br>\nsecond line"
    assert_includes content["formatted_body"], "&lt;guide&gt;.pdf"
    assert_includes content["formatted_body"], "x=1&amp;y=2"
    assert_includes(
      content["formatted_body"],
      '<a href="https://forum.example.com/chat/c/-/12/345?x=1&amp;y=2">' \
        "<strong>#General &amp; Help 频道</strong></a>",
    )
    assert_includes(
      content["formatted_body"],
      "<blockquote>hello &lt;b&gt;world&lt;/b&gt;<br>\nsecond line",
    )
    refute_includes content["formatted_body"], "hello <b>world</b>"
    refute_includes content["formatted_body"], "在 Discourse 中查看"
    refute_includes content["formatted_body"], "请在 Discourse 中查看"
  end

  def test_upload_only_message_and_text_message_type
    message =
      OpenStruct.new(
        message: "",
        uploads: [OpenStruct.new(original_filename: "guide.pdf")],
        full_url: "https://forum.example.com/chat/c/-/12/345",
      )

    content =
      ChatChannelsIntegrations::MessageFormatter.new(
        message: message,
        channel: OpenStruct.new(id: 12, name: "General", title: "General"),
        user: OpenStruct.new(username: "alice", display_name: "Alice"),
        use_notice: false,
      ).content

    assert_equal "m.text", content["msgtype"]
    assert_includes content["body"], "guide.pdf"
    assert_includes content["body"], message.full_url
    assert_includes content["formatted_body"], "<blockquote>附件：<br>\n- guide.pdf</blockquote>"
  end
end

class MatrixClientContractTest < Minitest::Test
  def setup
    FakeHTTP.reset!
  end

  def client
    ChatChannelsIntegrations::MatrixClient.new(
      homeserver: "https://matrix.example.com/base",
      access_token: "secret-token",
      http_class: FakeHTTP,
    )
  end

  def test_uses_v3_put_and_bearer_header
    client.send_message(
      room_id: "!room:matrix.example.com",
      transaction_id: "txn-1",
      content: { "msgtype" => "m.notice", "body" => "hello" },
    )

    assert_equal "matrix.example.com", FakeHTTP.start_options[:host]
    assert_equal true, FakeHTTP.start_options[:use_ssl]
    assert_equal 0, FakeHTTP.max_retries
    assert_equal "/base/_matrix/client/v3/rooms/%21room%3Amatrix.example.com/send/m.room.message/txn-1",
                 FakeHTTP.last_request.path
    assert_equal "Bearer secret-token", FakeHTTP.last_request.headers["Authorization"]
    assert_equal "application/json", FakeHTTP.last_request.headers["Content-Type"]
    assert_equal '{"msgtype":"m.notice","body":"hello"}', FakeHTTP.last_request.body
    refute_includes FakeHTTP.last_request.path, "secret-token"
  end

  def test_classifies_transient_and_permanent_errors
    FakeHTTP.response = FakeHTTP::Response.new(code: "503", body: "")
    error = assert_raises(ChatChannelsIntegrations::MatrixClient::RequestError) do
      client.send_message(
        room_id: "!room:example.com",
        transaction_id: "one",
        content: { "body" => "hello" },
      )
    end
    assert error.transient?
    assert_equal 503, error.status

    FakeHTTP.response =
      FakeHTTP::Response.new(code: "403", body: '{"errcode":"M_FORBIDDEN"}')
    error = assert_raises(ChatChannelsIntegrations::MatrixClient::RequestError) do
      client.send_message(
        room_id: "!room:example.com",
        transaction_id: "two",
        content: { "body" => "hello" },
      )
    end
    refute error.transient?
    assert_equal "matrix_forbidden", error.error_key
  end

  def test_rejects_insecure_or_credentialed_homeservers
    assert_raises(ChatChannelsIntegrations::MatrixClient::ConfigurationError) do
      ChatChannelsIntegrations::MatrixClient.new(
        homeserver: "http://matrix.example.com",
        access_token: "token",
        http_class: FakeHTTP,
      )
    end

    assert_raises(ChatChannelsIntegrations::MatrixClient::ConfigurationError) do
      ChatChannelsIntegrations::MatrixClient.new(
        homeserver: "https://user:pass@matrix.example.com",
        access_token: "token",
        http_class: FakeHTTP,
      )
    end
  end
end
