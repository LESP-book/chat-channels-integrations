# frozen_string_literal: true

RSpec.describe ChatChannelsIntegrations::MessageFormatter do
  subject(:content) do
    described_class.new(message: message, channel: channel, user: user, use_notice: use_notice).content
  end

  let(:use_notice) { true }
  let(:user) { Fabricate.build(:user, username: "alice", name: "Alice <Admin>") }
  let(:channel) { Fabricate.build(:chat_channel, name: "General & Help") }
  let(:upload) { Fabricate.build(:upload, original_filename: "<guide>.pdf") }
  let(:message) do
    Fabricate.build(
      :chat_message,
      message: "Hello <b>world</b>\nsecond line",
      uploads: [upload],
    ).tap do |chat_message|
      allow(chat_message).to receive(:full_url).and_return(
        "https://forum.example.com/chat/c/-/12/345?x=1&y=2",
      )
    end
  end

  it "builds notice text and escaped Matrix HTML with all required context" do
    expect(content["msgtype"]).to eq("m.notice")
    expect(content["body"]).to include(
      "Alice <Admin> (@alice)",
      "#General & Help",
      "Hello <b>world</b>\nsecond line",
      "<guide>.pdf",
      message.full_url,
    )
    expect(content["body"]).to include("> Hello <b>world</b>\n> second line")
    expect(content["body"]).not_to include("在 Discourse 中查看", "请在 Discourse 中查看")
    expect(content["format"]).to eq("org.matrix.custom.html")
    expect(content["formatted_body"]).to include(
      "Alice &lt;Admin&gt; (@alice)",
      "#General &amp; Help",
      "Hello &lt;b&gt;world&lt;/b&gt;<br>\nsecond line",
      "&lt;guide&gt;.pdf",
      "x=1&amp;y=2",
    )
    expect(content["formatted_body"]).to include(
      '<a href="https://forum.example.com/chat/c/-/12/345?x=1&amp;y=2">' \
        "<strong>#General &amp; Help 频道</strong></a>",
      "<blockquote>Hello &lt;b&gt;world&lt;/b&gt;<br>\nsecond line",
    )
    expect(content["formatted_body"]).not_to include("<b>world</b>")
    expect(content["formatted_body"]).not_to include(
      "在 Discourse 中查看",
      "请在 Discourse 中查看",
    )
  end

  it "uses m.text when notice messages are disabled" do
    use_notice = false

    result =
      described_class.new(
        message: message,
        channel: channel,
        user: user,
        use_notice: use_notice,
      ).content

    expect(result["msgtype"]).to eq("m.text")
  end

  it "formats an upload-only message without raising" do
    message.message = ""

    expect { content }.not_to raise_error
    expect(content["body"]).to include("<guide>.pdf", message.full_url)
    expect(content["formatted_body"]).to include(
      "<blockquote>附件：<br>\n- &lt;guide&gt;.pdf</blockquote>",
    )
  end
end
