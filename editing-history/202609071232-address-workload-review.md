# Address workload review / 处理 workload 审查意见

## English

- Exercise `try_patch_twig` with a structurally valid change-op list that points
  at a missing node, and assert rejection preserves both the client object and
  its Store baseline.
- Attach explicit per-stage work counters to updater, projection, diff,
  encoding, decoding, and apply timing statistics.
- Share list/statistics helpers between Node and browser harnesses, avoid DOM
  serialization outside the no-op check, and document that `rawHash` covers the
  full environment- and timing-dependent report.
- Revalidated 1,000/10,000 entities with 5 warmups and 30 repetitions. The data
  report hash is `c939e368bccb1d2a60967df059515dc6ca07528ef73cc359acd80ed00398f3ec`;
  the Chrome 152 browser report hash is
  `54bcd2b5990188646f895669ab48add34609b65097b8337ff5f2c4a2fb5a3b17`.

## 中文

- 使用结构有效但指向缺失节点的 change-op 列表真正进入 `try_patch_twig`，并断言
  拒绝后客户端对象及 Store baseline 都保持不变。
- 为 updater、projection、diff、encode、decode、apply 六个计时阶段补充明确的
  work counter。
- Node 与浏览器 harness 共用列表/统计 helper；仅在 no-op 检查时序列化 DOM；并
  明确 `rawHash` 覆盖包含环境和时间数据的完整报告。
- 对 1,000/10,000 entity 重新完成 5 次 warmup 与 30 次采样；数据报告 hash 为
  `c939e368bccb1d2a60967df059515dc6ca07528ef73cc359acd80ed00398f3ec`，Chrome 152
  浏览器报告 hash 为
  `54bcd2b5990188646f895669ab48add34609b65097b8337ff5f2c4a2fb5a3b17`。
