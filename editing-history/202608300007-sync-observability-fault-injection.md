# Synchronization observability and skipped-patch recovery / 同步观测与跳帧恢复

## Summary / 概要

- Added typed `SyncMetrics` process-lifetime counters for diff latency, UTF-8 patch payload bytes, patch/snapshot attempts, explicit resync requests, and latest revision.
- 增加 typed `SyncMetrics` 进程级指标，覆盖 diff 延迟、UTF-8 patch payload 字节数、patch/snapshot 尝试、显式 resync 请求与最新 revision。
- `read-sync-metrics` computes pending-ACK and slow-client gauges only on read. The ordinary dispatch/send path performs no all-client metrics scan.
- `read-sync-metrics` 仅在读取时计算等待 ACK 与 slow-client gauge；普通 dispatch/send 热路径不会为指标全量扫描客户端。
- Payload size uses a non-allocating Unicode-scalar traversal and reports actual UTF-8 wire bytes rather than character count. Tests cover ASCII, two-byte, three-byte, and four-byte characters.
- Payload size 通过不分配 encoded buffer 的 Unicode scalar 遍历计算真实 UTF-8 wire bytes，而不是字符数；测试覆盖 ASCII、2/3/4 字节字符。
- Metric names explicitly use `patch-attempts` / `snapshot-attempts` because backpressure retries are attempts, not confirmed delivery.
- 指标明确命名为 `patch-attempts` / `snapshot-attempts`，因为背压重试属于尝试而不是已确认送达。

## Fault injection / 故障注入

A real calcit-wss 0.2.23 client deliberately dropped revision 2 without ACK, resumed from its last applied revision 1, and converged through a full snapshot at revision 2. Observed timings: initial snapshot 32.4ms and coalesced patch 35.1ms.

真实 calcit-wss 0.2.23 客户端故意丢弃 revision 2 且不 ACK，从最后已应用的 revision 1 发起 resume，最终通过 revision 2 full snapshot 收敛。观测耗时：首次 snapshot 32.4ms，coalesced patch 35.1ms。

## Validation / 验证

- Server tests: 10/10, including UTF-8 byte size and pure metric-state transitions.
- Server 测试 10/10，包含 UTF-8 字节数与纯 metric state transition。
- Server check passed; reachable Dynamic usage is 30.2%, down from 31.9% before this phase despite adding typed observability positions.
- Server check 通过；虽然增加了 typed observability positions，可达 Dynamic 占比仍从 31.9% 降至 30.2%。
