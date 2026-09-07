# Budgeted server sync / 有预算的服务端同步

Issue: calcit-lang/calcit#798.

## English

- Upgrade Recollect to `0.0.45` through cumulo-reel `0.0.38`, then make
  `sync-client!` consume the nominal bounded-diff outcome. Complete work keeps
  the existing idle/patch/operation-threshold paths; exceeded work discards the
  partial candidate and enters the existing snapshot/send policy.
- Keep the acknowledged Store as the only diff baseline. A candidate Store is
  staged until its matching acknowledgement, so wrong acknowledgements,
  backpressure, and slow clients cannot publish an unacknowledged baseline.
- Use deterministic per-client limits of 50,000 visited nodes and 80,000
  operation-construction units. The 10,000-entity fixed workload's largest case
  consumes 40,002 visited nodes and 70,001 construction units, while all six
  cases complete without fallback.
- Extend `SyncMetrics` with snapshot bytes, latest visited/emitted work, and a
  budget-fallback count. Repeated transport attempts for the same revision are
  deduplicated, so backpressure does not count one planning fallback multiple
  times. Patch/snapshot byte policy, queue admission, and backpressure remain
  independent from the traversal budget.
- On Darwin 25.6.0 arm64, Apple M1 Pro, Node 20.10.0, and Calcit 0.14.0, the
  generated-JavaScript full run completed 5 warmups and 30 repetitions. The
  server-side data-diff stage measured p50/p95 of 1.56/5.91 ms at 1,000 entities
  and 22.12/63.59 ms at 10,000, with 793,592 and 710,660 visited nodes/second.
  End-of-run RSS was 358,612,992 bytes and heap used was 272,094,456 bytes.
- Snapshot evidence ranges from 72,714-72,790 bytes at 1,000 entities and
  756,715-756,794 bytes at 10,000. Remove/reorder/replace patches are larger than
  their snapshots, which confirms that the existing payload threshold remains a
  separate fallback. Raw data stays outside the repository at
  `/private/tmp/calcium-798-data-v2.json`; hash:
  `6727db7b1a2d8473d9b6226a4416f5ed0872903d7b4b713d6afdcbdff44bc94d`.
- The bounded path has visible accounting cost versus the earlier unlimited
  baseline, especially at 10,000 entities. CI therefore keeps a deterministic
  correctness smoke rather than a noisy wall-clock threshold. Per-stage
  allocation remains unavailable because JavaScript exposes no stable allocator
  API. Map key materialization, comparisons, large leaves, snapshot encoding,
  queue admission, and backpressure are not covered by the first traversal
  budget.

## 中文

- 通过 cumulo-reel `0.0.38` 升级到 Recollect `0.0.45`，由 `sync-client!` 消费具名
  的有界 diff outcome。完成时保持既有 idle/patch/operation-threshold 路径；超限时
  丢弃 partial candidate，并进入原有 snapshot/send 策略。
- 仍只把已确认 Store 作为 diff baseline。候选 Store 必须等到匹配 ack 才提交，
  因此错误 ack、背压与慢客户端都不能发布未确认 baseline。
- 每客户端使用 50,000 visited node 与 80,000 operation-construction unit 的确定性
  上限。固定的 10,000 entity workload 中最大 case 消耗 40,002 visited node 与
  70,001 construction unit；全部六种 case 均未回退。
- `SyncMetrics` 新增 snapshot 字节数、最近 visited/emitted 工作量和预算回退计数。
  同一 revision 的重复 transport attempt 会去重，因此 backpressure 不会把一次规划
  回退重复计数。patch/snapshot 字节策略、queue admission 与 backpressure 仍独立于
  遍历预算。
- 在 Darwin 25.6.0 arm64、Apple M1 Pro、Node 20.10.0、Calcit 0.14.0 环境，generated
  JavaScript 完成 5 次 warmup 与 30 次正式采样。服务端 data-diff 阶段在 1,000
  entity 的 p50/p95 为 1.56/5.91 ms、吞吐 793,592 visited nodes/s；10,000 entity
  为 22.12/63.59 ms、吞吐 710,660 visited nodes/s。结束时 RSS 358,612,992 bytes，
  heap used 272,094,456 bytes。
- 1,000 entity 的 snapshot 为 72,714-72,790 bytes，10,000 entity 为
  756,715-756,794 bytes。remove/reorder/replace patch 大于对应 snapshot，说明既有
  payload threshold 仍须独立回退。原始数据保存在仓库外
  `/private/tmp/calcium-798-data-v2.json`，hash 为
  `6727db7b1a2d8473d9b6226a4416f5ed0872903d7b4b713d6afdcbdff44bc94d`。
- 有界路径相对旧无限预算基线存在明显计数成本，10,000 entity 尤其如此，因此 CI
  保留确定性 correctness smoke，而不设置易抖动的 wall-clock threshold。JavaScript
  没有稳定的逐阶段 allocator API，allocation 仍明确为 unavailable。首版遍历预算
  不包含 map key materialization、比较、大叶子、snapshot 编码、queue admission
  与 backpressure。
