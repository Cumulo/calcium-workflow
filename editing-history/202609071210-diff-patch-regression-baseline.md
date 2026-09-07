# Diff/patch regression workload / 差量回归与基线

Base: `74be20c`; calcit-lang/calcit#794.

## English

- Add a deterministic typed Calcium workload with 1,000/10,000 keyed entities
  and the same replayable `DomainOp` sequence for no-op, leaf update, insert,
  remove, reorder, and full replacement. The architecture scaffold is
  reproducible and all Snapshot writes used exact Calcit `0.13.78-rc.1` CLI.
- Add generated-JavaScript data checks that compare every patched client Store
  with a fresh projection. The protocol oracle rejects out-of-order/duplicate
  acknowledgements, wrong revisions and invalid payloads without changing the
  old baseline, then proves slow-client recovery convergence. A deliberately
  foreign baseline proves the corruption oracle fails as intended.
- Add a real Respo browser harness that measures VDOM diff separately from DOM
  writes and compares patched DOM with a fresh render after every operation. It
  verifies keyed node identity, stable ref behavior, listener continuity,
  focus/selection retention, and zero no-op patch/DOM mutation.
- Full fixed-environment validation completed 5 warmups and 30 repetitions for
  both sizes. The data report was written outside the repository at
  `/private/tmp/calcium-794-data.json` with raw hash
  `2041aa9780345599989c6093f80a5663e51c7fe8c0c9635c7edfff87949b49de`.
  The Chrome 152 browser report raw hash is
  `a15c42db62df59c2b6eaa2b86997d5974594bf5c4c9f418401f052fb769ccd9a`.
  Allocation is explicitly unavailable because JavaScript exposes no stable
  per-stage allocator API.
- Recollect's 10,000-row vector diff exceeds Node's default JavaScript stack;
  the reproducible benchmark command therefore raises only the Node stack size.
  CI keeps the default stack and runs the small correctness smoke, with no
  performance threshold.
- Validation: exact-RC client/server check-only, 12/12 client and 15/15 server
  attached tests, dynamic-method budgets, unchanged native quality baseline,
  generated-JS smoke, browser smoke and full browser/data baselines.

## 中文

- 新增确定性的 typed Calcium workload：固定 seed、1,000/10,000 个 keyed entity，
  并对 no-op、叶子更新、插入、删除、重排和全量替换重放同一组 `DomainOp`。架构
  scaffold 可复现，所有 Snapshot 写入均使用精确 Calcit `0.13.78-rc.1` CLI。
- 新增 generated-JavaScript 数据检查，逐步比较 patch 后的客户端 Store 与 fresh
  projection。协议 oracle 会拒绝乱序/重复 ack、错误 revision 和非法 payload，且
  保持旧 baseline 不变；随后验证慢客户端恢复收敛，并用外来 baseline 证明损坏
  oracle 会按预期失败。
- 新增真实 Respo 浏览器 harness，分别测量 VDOM diff 与 DOM write，每步都比较
  patched DOM 和 fresh render；同时验证 keyed node identity、稳定 ref、listener、
  focus/selection，以及 no-op 的零 patch/零 DOM mutation。
- 固定环境完整验证对两个规模均完成 5 次 warmup 与 30 次正式采样。数据 raw 结果
  保存在仓库外 `/private/tmp/calcium-794-data.json`，hash 为
  `2041aa9780345599989c6093f80a5663e51c7fe8c0c9635c7edfff87949b49de`；Chrome 152
  浏览器报告 hash 为
  `a15c42db62df59c2b6eaa2b86997d5974594bf5c4c9f418401f052fb769ccd9a`。
  JavaScript 没有稳定的逐阶段 allocator API，因此 allocation 明确记为 unavailable。
- Recollect 的 10,000 行 vector diff 会超过 Node 默认 JavaScript 栈，基线命令只
  显式提高 Node stack size；CI 保持默认栈，只运行小规模正确性 smoke，不设置易
  抖动的性能阈值。
- 验证包括：精确 RC 的 client/server check-only、client 12/12 与 server 15/15
  attached tests、dynamic-method 预算、未放宽的 native quality baseline、生成 JS
  smoke，以及浏览器/data 的 smoke 与完整基线。
