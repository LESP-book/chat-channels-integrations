# chat-channels-integrations

将公开 Discourse Chat 频道中新创建的消息异步、单向转发到一个或多个 Matrix 房间。

## 安装

将本插件目录放到 Discourse 的 `plugins/chat-channels-integrations`，然后在 Discourse 根目录执行：

```bash
RAILS_ENV=production bundle exec rake db:migrate
```

重启 Discourse 后，在管理后台启用 `chat_channels_integrations_enabled`。

## Matrix 配置

在管理后台的站点设置中配置：

- `chat_channels_integrations_matrix_homeserver`：Matrix homeserver 的 HTTPS 地址，默认 `https://matrix.org`；
- `chat_channels_integrations_matrix_access_token`：能够向目标房间发消息的 Matrix 用户 access token；
- `chat_channels_integrations_matrix_use_notice`：启用时发送 `m.notice`，关闭时发送 `m.text`。

插件通过 `Authorization: Bearer` header 发送 token，不会把 token 放入 URL 或日志。

如果 homeserver 位于私有网络，除使用 HTTPS 外，还需把 hostname 加入 Discourse 的 `allowed_internal_hosts` 站点设置。请求使用 Discourse 的 `FinalDestination::HTTP`，默认拒绝未获准的私有、环回和保留地址。

## 创建频道映射

1. 打开管理后台的 **Plugins**。
2. 选择 **Chat Channels Integrations**。
3. 打开 **频道映射**（路径：`/admin/plugins/chat-channels-integrations/rules`）。
4. 选择一个公开 Discourse Chat 频道，输入 Matrix room ID（例如 `!room:matrix.example.com`），创建映射。

同一 Chat 频道可以建立多条映射，每条规则对应一个 Matrix 房间。页面支持修改、启停和删除规则。服务端拒绝个人私信及群体私信频道。

## 手动测试

1. 确保目标 Matrix 用户已加入对应房间，并拥有发送消息权限。
2. 创建并启用一条映射。
3. 在映射的公开 Chat 频道发送包含换行和 HTML 特殊字符（例如 `<test> & text`）的消息。
4. 确认 Matrix 收到发送者、可点击的频道名和引用格式的正文；点击频道名应打开该条 Discourse 消息，并确认 HTML 显示的是文本而不是执行标签。
5. 发送一个只有附件、没有正文的 Chat 消息，确认 Matrix 在引用块中显示文件名。
6. 使用 Discourse Chat incoming webhook 向同一频道写入消息，确认不会再次转发。
7. 暂时填入无效 token，确认 Discourse Chat 发消息仍然成功，并检查日志包含 message ID、channel ID、room ID 和 HTTP status，但不包含 token。

## 第一版边界

当前版本不实现：

- Matrix 到 Discourse 的反向同步；
- 附件重新上传到 Matrix；
- Matrix 原生线程；
- Chat 消息编辑或删除同步；
- Matrix E2EE 房间支持；
- 复杂的投递状态和失败管理界面。
