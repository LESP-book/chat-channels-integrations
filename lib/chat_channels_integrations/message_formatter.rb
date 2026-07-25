# frozen_string_literal: true

require "erb"

module ChatChannelsIntegrations
  class MessageFormatter
    MATRIX_HTML_FORMAT = "org.matrix.custom.html"

    def initialize(message:, channel:, user:, use_notice:)
      @message = message
      @channel = channel
      @user = user
      @use_notice = use_notice
    end

    def content
      {
        "msgtype" => @use_notice ? "m.notice" : "m.text",
        "body" => body,
        "format" => MATRIX_HTML_FORMAT,
        "formatted_body" => formatted_body,
      }
    end

    private

    def body
      [
        "#{sender_name} (#{username}) 在 ##{channel_name} 频道中发送了消息：",
        message_text,
        attachment_text,
        "在 Discourse 中查看：\n#{@message.full_url}",
      ].reject(&:empty?).join("\n\n")
    end

    def formatted_body
      [
        "<strong>#{escape(sender_name)} (#{escape(username)})</strong> 在 " \
          "<strong>##{escape(channel_name)}</strong> 频道中发送了消息：",
        html_message_text,
        escape(attachment_text).gsub("\n", "<br>\n"),
        "在 Discourse 中查看：<br>\n<a href=\"#{escape(@message.full_url)}\">#{escape(@message.full_url)}</a>",
      ].reject(&:empty?).join("<br>\n<br>\n")
    end

    def sender_name
      display_name =
        if @user.respond_to?(:display_name)
          @user.display_name
        elsif @user.respond_to?(:name)
          @user.name
        end

      display_name.to_s.empty? ? @user.username : display_name
    end

    def username
      "@#{@user.username}"
    end

    def channel_name
      name = @channel.respond_to?(:name) ? @channel.name : nil
      name.to_s.empty? ? @channel.title : name
    end

    def message_text
      @message.message.to_s
    end

    def html_message_text
      escape(message_text).gsub("\n", "<br>\n")
    end

    def attachment_text
      filenames = @message.uploads.filter_map(&:original_filename)
      return "" if filenames.empty?

      "附件：\n#{filenames.map { |filename| "- #{filename}" }.join("\n")}\n请在 Discourse 中查看。"
    end

    def escape(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end
