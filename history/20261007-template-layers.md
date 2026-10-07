# 模板分层：app.sync / hooks / app.feature

## 修改

为了让复制模板的项目能快速区分模板代码和业务代码，按命名空间分层：

- `app.partition`、`app.server`、`app.client` 的运行时部分移到 `app.sync.partition`、`app.sync.server`、
  `app.sync.client`；`app.server` / `app.client` 只保留入口函数、根渲染和 watcher。
- Kanban 相关的 reducer、投影、组件、冷缓存、workload 和类型移到 `app.feature.kanban.*`；
  冷存储状态与持久化移到 `app.feature.kanban.server`，客户端冷缓存移到 `app.feature.kanban.client`。
- 新增 `app.hooks`、`app.hooks.server`、`app.hooks.client`：模板调用业务的所有地方都改为调用这些 hook。
  `Query` / `QueryReply` / `decode-query` 与 `PartitionKey` / `PartitionView` 一样留在 `app.schema`，
  作为协议声明的业务变体。
- 依赖 Kanban 的多订阅者集成测试从 `app.sync.server` 移到 `app.hooks.server/affected-partitions`；
  分区引擎自测改为通过 `app.hooks/sample-partition-view` 取得测试视图。
- `tests/template-boundary.mjs` 在 CI 中断言 `app.sync.*` 不引用 `app.feature.*` 和入口命名空间，
  feature 不依赖 hooks 和入口。

搬迁通过受 revision 保护的 `calcit edit transaction` 完成：先用 CLI 读出各定义的结构化 JSON，在脚本里改写引用，
再生成事务写回，没有直接修改快照文本。

## 回归

客户端 45/45、服务端 77/77 原生测试通过；`check-types` 两个入口全部公开定义通过（179/179、261/261）；
既有 JS 回归、workload smoke、原生服务端 Kanban e2e 和边界检查通过。行为与协议没有变化。

## 剩余

阶段 B（把分区引擎、`struct-tree-input`、客户端校验状态机抽到模块）等 hooks 接口稳定后再评估，
见 `docs/template-layers.md`。
