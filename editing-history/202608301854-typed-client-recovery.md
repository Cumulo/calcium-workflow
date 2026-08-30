# Typed browser recovery and revision resynchronization

## 中文

- 将 Calcit 与 `@calcit/procs` 同步到 0.13.66，并升级到 cumulo-reel 0.0.29、
  ws-edn 0.0.19。
- 保留 nominal `WsClient`，以 typed `ConnectionRecoveryAction` 集中表达
  `none`、`reconnect`、`connect` 三种浏览器恢复决策。
- `visibilitychange`、`online` 与离线页面触摸统一调用恢复策略；旧 generation
  的 socket callback 由 ws-edn 丢弃，避免快速重连污染新连接状态。
- 每次 WebSocket open 都发送携带当前 revision 的 `:sync/resume`，确保首次连接、
  断线重连与后台恢复都进入同一 snapshot/resync 收敛路径。
- 热更新时替换当前连接的 `on-data` handler，不因代码 reload 额外创建连接。

## English

- Align Calcit and `@calcit/procs` on 0.13.66 and upgrade to cumulo-reel 0.0.29
  and ws-edn 0.0.19.
- Retain the nominal `WsClient` and centralize browser recovery as the typed
  `ConnectionRecoveryAction` choices `none`, `reconnect`, and `connect`.
- Route `visibilitychange`, `online`, and offline-page touches through one
  recovery policy. ws-edn drops callbacks from stale socket generations so a
  rapid reconnect cannot overwrite the new connection state.
- Send `:sync/resume` with the current revision on every WebSocket open, putting
  initial connection, reconnect, and background recovery on one convergent
  snapshot/resync path.
- Replace the active `on-data` handler during hot reload without creating an
  additional connection.
