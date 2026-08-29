# Dispatch-driven coalesced server sync / Dispatch 驱动的服务端合并同步

## Summary / 概要

- Replaced the fixed 200 ms global render scan with a 16 ms first-change timer. Repeated dispatches share the pending callback, giving both coalescing and a bounded flush delay.
- 用首个变更触发的 16ms timer 替代固定 200ms 全局 render 扫描；连续 dispatch 复用同一回调，同时获得合并与有上界的 flush 延迟。
- Added an independent 200 ms retry timer for `(:backpressured)`, so a slow peer cannot create a 16 ms busy loop or block a new ordinary update.
- 为 `(:backpressured)` 增加独立 200ms 重试 timer，避免慢连接形成 16ms 忙循环，也不阻塞新的普通更新。
- Replaced coordination through asynchronous `wss-each!` callbacks with synchronous iteration over `*client-states` and `*dirty-clients`.
- 将依赖异步 `wss-each!` 回调的协调逻辑改为同步遍历 `*client-states` 与 `*dirty-clients`。
- Added concrete contracts to the touched scheduler and client-state functions. Reachable Dynamic positions fell from 37.7% to 34.2%; all upgrade-baseline metrics improved.
- 为本次涉及的调度与客户端状态函数补充具体类型契约。可达 Dynamic 位置从 37.7% 降至 34.2%，全部升级基线指标均有改善。

## Key finding / 关键发现

After the C async FFI migration, `wss-each!` does not complete before the next Calcit statement. The old sequence could start marking clients dirty, immediately observe an empty dirty set, and finish the Recollect memo frame before callbacks ran. The old periodic scan masked this race. Application-owned state must be the synchronous source of truth; WebSocket FFI should remain a transport boundary.

C async FFI 迁移后，`wss-each!` 不会在下一条 Calcit 语句之前完成。旧流程可能刚开始异步标记 dirty client，就立即读到空集合，并在回调执行前关闭 Recollect memo frame；原有周期扫描偶然掩盖了这个竞态。应用自有状态必须作为同步事实来源，WebSocket FFI 只保留在传输边界。

## Runtime validation / 运行时验证

A real calcit-wss 0.2.23 connection exercised ping/pong, active snapshot, duplicate ACK, three immediate router dispatches, ACK, and forced resume snapshot. The warm snapshot arrived in 19.4 ms; the three dispatches produced one revision and one patch in 22.1 ms; resume returned a snapshot at the acknowledged revision. Duplicate/stale ACK is now ignored instead of unwrapping a missing pending revision.

真实 calcit-wss 0.2.23 连接覆盖 ping/pong、active snapshot、重复 ACK、三次连续 router dispatch、ACK 与强制 resume snapshot。预热 snapshot 为 19.4ms；三次 dispatch 在 22.1ms 内合并为一个 revision 和一个 patch；resume 返回已确认 revision 的 snapshot。重复或过期 ACK 现在会被忽略，不再 unwrap 已清理的 pending revision。
