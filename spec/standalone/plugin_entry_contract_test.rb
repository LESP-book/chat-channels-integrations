# frozen_string_literal: true

require "minitest/autorun"

class PluginEntryContractTest < Minitest::Test
  def test_plugin_entry_uses_supported_dsl
    plugin_source = File.read(File.expand_path("../../plugin.rb", __dir__))

    assert_includes plugin_source, "enabled_site_setting :chat_channels_integrations_enabled"
    assert_includes plugin_source, 'register_asset "stylesheets/chat-channels-integrations.scss"'
    production_sources =
      [plugin_source, *Dir[File.expand_path("../../app/**/*.rb", __dir__)].map { |path| File.read(path) }]
    assert_equal 1, production_sources.join("\n").scan(/PLUGIN_NAME\s*=/).size
    refute_match(/^required_plugin\b/, plugin_source)
  end
end
