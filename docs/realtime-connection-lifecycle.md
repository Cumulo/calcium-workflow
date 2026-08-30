# Real-time connection lifecycle / 实时连接生命周期

## Ownership / 职责

`ws-edn.client/WsClient` owns browser transport lifecycle: one active socket
generation, stale-callback rejection, visibility/online recovery, bounded
backoff, and the optional inbound heartbeat deadline. Calcium owns protocol
meaning: revision resume, application activity, typed heartbeat/pong messages,
and updater state.

`ws-edn.client/WsClient` 负责浏览器 transport lifecycle：单一有效 socket
generation、旧 callback 拒绝、visibility/online recovery、有界 backoff 与可选的
入站 heartbeat deadline。Calcium 负责协议语义：revision resume、应用 activity、
typed heartbeat/pong 消息与 updater 状态。

Do not add application-level `online` or `visibilitychange` reconnect listeners.
They race with ws-edn's listener and can replace a socket that is already
connecting. Calcium keeps only `on-page-touch` as an explicit manual
acceleration when the store is offline; `.reconnect` cancels a pending backoff
timer before opening a new generation.

不要再增加应用层 `online` 或 `visibilitychange` 重连 listener；它们会与 ws-edn
listener 竞争，并替换已经处于 connecting 的 socket。Calcium 只保留 store offline
时的 `on-page-touch` 手动加速；`.reconnect` 会先取消 pending backoff timer，再打开
新 generation。

## Heartbeat and resync / 心跳与重同步

The template sends `ClientMessage :sync/heartbeat` every 30 seconds while open.
The server records activity and returns typed `ServerMessage :effect/pong`.
`ws-connect!` uses `:heartbeat-timeout-ms 75000`, so any inbound snapshot,
patch, or pong renews the lease. Expiration closes only the active generation;
the normal backoff path reconnects it.

模板在连接打开时每 30 秒发送 `ClientMessage :sync/heartbeat`。服务端记录 activity
并返回 typed `ServerMessage :effect/pong`。`ws-connect!` 使用
`:heartbeat-timeout-ms 75000`，因此入站 snapshot、patch 或 pong 都会续租；超时只
关闭当前 generation，再由普通 backoff 路径重连。

Every `:on-open` callback sends `ClientMessage :sync/resume` with the last
applied revision before ordinary activity/login messages. The server either
continues from the acknowledged baseline or sends a full snapshot. Heartbeat
recovery therefore cannot bypass revision convergence.

每次 `:on-open` 都会在普通 activity/login 之前，携带最后已应用 revision 发送
`ClientMessage :sync/resume`。服务端从 acknowledged baseline 继续，或发送 full
snapshot；因此 heartbeat recovery 不会绕过 revision 收敛。

## Cleanup / 清理

Hot reload only replaces the data handler. Explicit client `.close` owns cleanup
of lifecycle listeners, reconnect timers, heartbeat timers, and leases. Avoid
detached timers or untracked sockets in application code.

热更新只替换 data handler。显式 client `.close` 负责清理 lifecycle listener、
reconnect timer、heartbeat timer 与 lease；应用代码不应创建 detached timer 或
无法追踪的 socket。
