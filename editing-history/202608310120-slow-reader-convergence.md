# Slow-reader convergence and Calcit 0.13.67 / 慢读端收敛与 Calcit 0.13.67

## 中文

- 将 Calcit CLI 与 `@calcit/procs` 对齐到 0.13.67，并以 String 方法 `.utf8-byte-count` 替代应用内的 Unicode fold，保持真实 wire-byte 指标但移除热路径解释执行开销。
- 将 calcit-wss 升级到 0.2.25；该版本会恢复 tungstenite 已保留的待写 frame，不会把 `WouldBlock`、`TimedOut` 或 `Interrupted` 误判为断线。
- 将 cumulo-reel 升级到 0.0.32，消除其旧 wss 0.2.24 固定版本与模板根依赖之间的 strict resolver 冲突。
- `next-sync-send-state` 在 `:backpressured` 时保留 `max(current-dirty, attempted-revision)`，避免重复压力覆盖更新目标。
- 抽取 `next-sync-ack-state`，并增加从重复 backpressure、最新 accepted send 到最终 ACK 的纯状态序列测试。
- 原生慢读端测试暂停 TCP reader 并请求 16 次 192 KiB snapshot；实际只收到 9 个 baseline snapshot，随后在 revision 3 收敛到最后一次业务状态，ACK 后 patch 从 3 推进到 4；标准 WebSocket close handshake 只产生正常的 `Client closed!`。
- 三次连续 dispatch 被 16ms server window 合并为一个 revision；回归按最终业务 payload 和 ACK base 验证收敛，而不是错误假设每次 dispatch 都生成独立 revision。

## English

- Align the Calcit CLI and `@calcit/procs` on 0.13.67, replacing the application-level Unicode fold with the String receiver method `.utf8-byte-count`. Wire-byte metrics remain exact without interpreted hot-path overhead.
- Upgrade calcit-wss to 0.2.25, which resumes tungstenite's retained pending frame instead of treating `WouldBlock`, `TimedOut`, or `Interrupted` as a disconnect.
- Upgrade cumulo-reel to 0.0.32, removing its stale wss 0.2.24 pin and the resulting strict-resolver conflict with the template root.
- Preserve `max(current-dirty, attempted-revision)` when `next-sync-send-state` receives `:backpressured`, preventing repeated pressure from overwriting the desired target revision.
- Extract `next-sync-ack-state` and add a pure state-sequence test from repeated backpressure through the latest accepted send and final ACK.
- The native slow-reader test pauses its TCP reader and requests sixteen 192 KiB snapshots. Only nine baseline snapshots are delivered; revision 3 contains the final application state, and the post-ACK patch advances from base 3 to revision 4. A standard WebSocket close handshake produces only the expected `Client closed!` event.
- Three consecutive dispatches intentionally coalesce into one revision within the 16 ms server window. The regression verifies the final business payload and ACK base instead of assuming one revision per dispatch.
