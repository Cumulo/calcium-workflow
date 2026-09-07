# Mark stage allocation unavailable / 标记阶段 allocation 不可用

## English

- Add one shared, explicit allocation-unavailable marker to every Node and
  browser timing stage, while retaining each result's allocation summary.
- JavaScript does not expose a stable per-stage allocator API; the report now
  makes that limitation locally visible wherever stage metrics are consumed.
- Final 1,000/10,000 full-run hashes after this schema change: data
  `c939e368bccb1d2a60967df059515dc6ca07528ef73cc359acd80ed00398f3ec`;
  Chrome 152 browser
  `54bcd2b5990188646f895669ab48add34609b65097b8337ff5f2c4a2fb5a3b17`.

## 中文

- 为 Node 与浏览器的每个计时阶段加入同一个明确的 allocation-unavailable 标记，
  同时保留每项结果的 allocation 汇总。
- JavaScript 没有稳定的逐阶段 allocator API；现在消费任一阶段指标时都能直接看到
  这一限制。
- 本次 schema 变更后的 1,000/10,000 完整结果：数据 hash 为
  `c939e368bccb1d2a60967df059515dc6ca07528ef73cc359acd80ed00398f3ec`，Chrome 152
  浏览器 hash 为
  `54bcd2b5990188646f895669ab48add34609b65097b8337ff5f2c4a2fb5a3b17`。
