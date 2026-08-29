# Typed synchronization envelopes / 类型化同步消息封装

## Summary / 概要

- Added nominal `ClientMessage` and `ServerMessage` enums for sync control, application dispatch, snapshots, patches, and pong effects.
- 为同步控制、业务 dispatch、snapshot、patch 与 pong effect 增加 nominal `ClientMessage` / `ServerMessage` enum。
- Added `Result` decoders at the raw Cirru EDN boundary. Invalid revisions, patch payloads, string credentials, unknown operations, and non-enum messages no longer reach synchronization/business code.
- 在原始 Cirru EDN 边界增加 `Result` decoder；非法 revision、patch payload、字符串凭据、未知操作及非 enum 消息不再进入同步或业务代码。
- Reconstruct every `Op` variant nominally. `unsafe-coerce` was rejected because runtime enum payload validation correctly refuses an unknown `%:: _` definition.
- 对每个 `Op` variant 做 nominal 重建；没有使用 `unsafe-coerce` 绕过，因为运行时 enum payload 校验会正确拒绝未知 `%:: _` definition。
- New clients send `ClientMessage :dispatch Op`; the server continues accepting direct legacy `Op` values for rolling deployment. Named `ServerMessage` retains the old variant tags for older clients.
- 新客户端发送 `ClientMessage :dispatch Op`；服务端在滚动部署期间继续接受旧的直发 `Op`。Named `ServerMessage` 保留旧 variant tag，兼容旧客户端匹配。

## Validation / 验证

- Client protocol tests: 7/7; server protocol/state tests: 8/8, including malformed payloads, nominal patch lists, direct legacy Op, and actual named wire strings. The browser class mapper now includes both `ServerMessage` and Recollect `change-op`.
- Client 协议测试 7/7，server 协议/状态测试 8/8，覆盖错误 payload、nominal patch list、旧直发 Op 及真实 named wire string；浏览器 class mapper 同时加入 `ServerMessage` 与 Recollect `change-op`。
- A real calcit-wss 0.2.23 session used named envelopes end to end: ping/pong, initial snapshot, duplicate ACK, three immediate dispatches coalesced into one patch revision, patch ACK, and forced resume snapshot. Snapshot was 20.7ms and patch 19.0ms.
- 真实 calcit-wss 0.2.23 会话端到端使用 named envelope，覆盖 ping/pong、首次 snapshot、重复 ACK、三次 dispatch 合并为单 patch revision、patch ACK 与强制 resume snapshot。Snapshot 20.7ms，patch 19.0ms。
- Reachable Dynamic positions improved from the pre-envelope 34.2% to 31.9%; Dynamic remains at the explicit decode/FFI boundary.
- 可达 Dynamic 位置从改造前 34.2% 降至 31.9%；Dynamic 保留在明确的 decode/FFI 边界。

## Follow-up / 后续

One rapid reconnect attempt exposed calcit-wss 0.2.23 treating nonblocking handshake `WouldBlock` as a failed connection; an immediate retry succeeded. The transport issue is tracked in [calcit-wss #38](https://github.com/calcit-lang/calcit-wss/issues/38) rather than weakening the typed protocol boundary.

一次快速重连暴露 calcit-wss 0.2.23 将 nonblocking handshake 的 `WouldBlock` 当成连接失败；立即重试成功。传输层问题由 [calcit-wss #38](https://github.com/calcit-lang/calcit-wss/issues/38) 单独追踪，不应削弱 typed protocol 边界。
