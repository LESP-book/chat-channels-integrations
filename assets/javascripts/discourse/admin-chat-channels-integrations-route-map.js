export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("chat-channels-integrations", { path: "rules" });
  },
};
