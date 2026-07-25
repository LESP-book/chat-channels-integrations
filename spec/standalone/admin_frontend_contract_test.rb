# frozen_string_literal: true

require "minitest/autorun"

class AdminFrontendContractTest < Minitest::Test
  def setup
    @template =
      File.read(
        File.expand_path(
          "../../admin/assets/javascripts/discourse/templates/admin-plugins/show/chat-channels-integrations.gjs",
          __dir__,
        ),
      )
  end

  def test_admin_route_uses_the_rules_subpath
    route_map =
      File.read(
        File.expand_path(
          "../../assets/javascripts/discourse/admin-chat-channels-integrations-route-map.js",
          __dir__,
        ),
      )

    assert_includes route_map, '{ path: "rules" }'
    assert_includes @template, '@path="/admin/plugins/chat-channels-integrations/rules"'
  end

  def test_room_edits_use_a_draft_and_toggle_has_an_accessible_name
    assert_includes @template, "roomIdDraft"
    assert_match(/<DToggleSwitch.*?aria-label=/m, @template)
  end
end
