import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "chat-channels-integrations";

export default {
  name: "chat-channels-integrations-admin-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "comments");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "chat_channels_integrations.admin.nav.rules",
          route: "adminPlugins.show.chat-channels-integrations",
          description: "chat_channels_integrations.admin.nav.rules_description",
        },
      ]);
    });
  },
};
