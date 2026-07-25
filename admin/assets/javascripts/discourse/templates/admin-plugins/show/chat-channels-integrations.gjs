import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import { not } from "discourse/truth-helpers";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

const RULES_URL = "/admin/plugins/chat-channels-integrations/rules";

export default class ChatChannelsIntegrations extends Component {
  @service dialog;
  @service toasts;

  @tracked rules;
  @tracked channelId;
  @tracked roomId = "";
  @tracked saving = false;

  constructor() {
    super(...arguments);
    this.rules = (this.args.controller.model.rules || []).map((rule) => ({
      ...rule,
      roomIdDraft: rule.matrix_room_id,
    }));
    this.channelId = this.channels[0]?.id;
  }

  get channels() {
    return this.args.controller.model.channels || [];
  }

  get canCreate() {
    return Boolean(this.channelId && this.roomId.trim() && !this.saving);
  }

  replaceRule(updatedRule) {
    this.rules = this.rules.map((rule) =>
      rule.id === updatedRule.id
        ? {
            ...updatedRule,
            roomIdDraft: rule.roomIdDraft,
          }
        : rule
    );
  }

  async updateRule(rule, attributes) {
    try {
      const result = await ajax(`${RULES_URL}/${rule.id}.json`, {
        type: "PUT",
        data: { rule: attributes },
      });
      this.replaceRule(result.rule);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  selectChannel(channelId) {
    this.channelId = channelId;
  }

  @action
  updateRoomId(event) {
    this.roomId = event.target.value;
  }

  @action
  async createRule() {
    if (!this.canCreate) {
      return;
    }

    this.saving = true;
    try {
      const result = await ajax(`${RULES_URL}.json`, {
        type: "POST",
        data: {
          rule: {
            chat_channel_id: this.channelId,
            matrix_room_id: this.roomId.trim(),
            enabled: true,
          },
        },
      });
      this.rules = [
        ...this.rules,
        { ...result.rule, roomIdDraft: result.rule.matrix_room_id },
      ];
      this.roomId = "";
      this.toasts.success({
        data: { message: i18n("chat_channels_integrations.admin.created") },
        duration: "short",
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  changeChannel(rule, channelId) {
    this.updateRule(rule, { chat_channel_id: channelId });
  }

  @action
  changeRoomId(rule, event) {
    rule.roomIdDraft = event.target.value;
  }

  @action
  saveRoomId(rule) {
    const matrixRoomId = rule.roomIdDraft.trim();
    rule.roomIdDraft = matrixRoomId;
    this.updateRule(rule, { matrix_room_id: matrixRoomId });
  }

  @action
  toggleRule(rule) {
    this.updateRule(rule, { enabled: !rule.enabled });
  }

  @action
  deleteRule(rule) {
    this.dialog.confirm({
      message: i18n("chat_channels_integrations.admin.confirm_delete", {
        room: rule.matrix_room_id,
      }),
      didConfirm: async () => {
        try {
          await ajax(`${RULES_URL}/${rule.id}.json`, { type: "DELETE" });
          this.rules = this.rules.filter(
            (candidate) => candidate.id !== rule.id
          );
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/chat-channels-integrations/rules"
      @label={{i18n "chat_channels_integrations.admin.title"}}
    />

    <div class="chat-channels-integrations admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "chat_channels_integrations.admin.title"}}
        @descriptionLabel={{i18n
          "chat_channels_integrations.admin.description"
        }}
      />

      <section class="chat-channels-integrations__new-rule">
        <h3>{{i18n "chat_channels_integrations.admin.new_rule"}}</h3>
        <div class="chat-channels-integrations__form">
          <div class="control-group">
            <label>{{i18n
                "chat_channels_integrations.admin.chat_channel"
              }}</label>
            <ComboBox
              @value={{this.channelId}}
              @content={{this.channels}}
              @onChange={{this.selectChannel}}
              @options={{hash filterable=true}}
            />
          </div>
          <div class="control-group chat-channels-integrations__room-field">
            <label for="chat-channels-integrations-new-room-id">{{i18n
                "chat_channels_integrations.admin.matrix_room_id"
              }}</label>
            <input
              id="chat-channels-integrations-new-room-id"
              type="text"
              value={{this.roomId}}
              placeholder="!room:matrix.example.com"
              {{on "input" this.updateRoomId}}
            />
          </div>
          <DButton
            @label="chat_channels_integrations.admin.create"
            @icon="plus"
            @action={{this.createRule}}
            @disabled={{not this.canCreate}}
            class="btn-primary"
          />
        </div>
      </section>

      <section class="chat-channels-integrations__rules">
        <h3>{{i18n "chat_channels_integrations.admin.rules"}}</h3>
        {{#if this.rules.length}}
          <table class="table">
            <thead>
              <tr>
                <th>{{i18n
                    "chat_channels_integrations.admin.chat_channel"
                  }}</th>
                <th>{{i18n
                    "chat_channels_integrations.admin.matrix_room_id"
                  }}</th>
                <th>{{i18n "chat_channels_integrations.admin.enabled"}}</th>
                <th>{{i18n "chat_channels_integrations.admin.actions"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each this.rules as |rule|}}
                <tr>
                  <td>
                    <ComboBox
                      @value={{rule.chat_channel_id}}
                      @content={{this.channels}}
                      @onChange={{fn this.changeChannel rule}}
                      @options={{hash filterable=true}}
                    />
                  </td>
                  <td>
                    <input
                      type="text"
                      value={{rule.roomIdDraft}}
                      aria-label={{i18n
                        "chat_channels_integrations.admin.matrix_room_id"
                      }}
                      {{on "input" (fn this.changeRoomId rule)}}
                    />
                  </td>
                  <td>
                    <DToggleSwitch
                      @state={{rule.enabled}}
                      aria-label={{i18n
                        "chat_channels_integrations.admin.enabled"
                      }}
                      {{on "click" (fn this.toggleRule rule)}}
                    />
                  </td>
                  <td class="chat-channels-integrations__actions">
                    <DButton
                      @label="chat_channels_integrations.admin.save"
                      @icon="check"
                      @action={{fn this.saveRoomId rule}}
                      class="btn-primary btn-small"
                    />
                    <DButton
                      @label="chat_channels_integrations.admin.delete"
                      @icon="trash-can"
                      @action={{fn this.deleteRule rule}}
                      class="btn-danger btn-small"
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <p>{{i18n "chat_channels_integrations.admin.no_rules"}}</p>
        {{/if}}
      </section>
    </div>
  </template>
}
