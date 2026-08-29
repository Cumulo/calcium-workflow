# Validated patch full-resync boundary

## 修改概要

- 升级到 cumulo-reel 0.0.28 与 recollect 0.0.38，严格 16-module graph 保持零版本分歧。
- 新增泛型纯函数 `validate-server-patch`，先验证 base revision，再通过 `PatchBatch.apply-to` 原子应用增量。
- 显式导入并断言 `PatchBatchOps` trait，使跨模块方法调用可静态专门化，不增加 dynamic dispatch。
- 用 `ClientPatchError` 区分 revision mismatch 与结构化 `PatchError`；任一失败均不发布部分 store，并请求 full snapshot。
- 增加 client fault-injection tests，并纳入 GitHub Actions。

## 可复用知识

- revision 相等只能证明消息顺序，不能证明 patch 仍与本地数据形状兼容；两层检查缺一不可。
- 将纯验证函数与 atom/WebSocket side effects 分离，能够直接测试乱序和损坏 patch，而无需模拟浏览器连接。
- 跨模块方法即使返回 nominal struct，也应在能力边界用 `assert-traits` 提供明确证据，并用 dynamic-methods baseline 验证没有退化。
- 应用依赖升级必须先发布中间模块的稳定 tag；strict resolver 出现同模块多版本时，不应使用宽松选择或 commit hash 绕过。
