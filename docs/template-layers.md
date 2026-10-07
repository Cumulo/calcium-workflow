# 模板分层与替换业务

把 calcium-workflow 复制成新项目时，按命名空间前缀就能判断哪些代码原样保留、哪些需要替换。
分层规则由 `tests/template-boundary.mjs` 在 CI 中检查（`yarn node tests/template-boundary.mjs --list`
可以打印当前分层）。

## 1. 分层

| 层 | 命名空间 | 复制后怎么处理 |
|----|------|------|
| **template** | `app.sync.server`、`app.sync.client` | 原样保留，不按项目修改。包括 Reel、会话 Store 同步、分区注册表与扇出、ACK/背压/resync、冷查询传输，以及热 Db 快照的持久化流程；业务冷状态及其持久化由 `app.feature.<name>.server` 负责，经 `app.hooks.server/persist!` 调用 |
| **wiring** | `app.schema`、`app.hooks.server`、`app.hooks.client`、`app.updater`、`app.client`、`app.server`、`app.comp.container` | 唯一点名当前业务的地方，改成指向新业务 |
| **base** | `app.twig.*`、`app.updater.{session,user,router}`、`app.comp.{login,navigation,profile}`、`app.config`、`app.workload.diff-patch` | 账号、会话、路由脚手架，大多数项目保留，按需修改 |
| **feature** | `app.feature.<name>.*`（当前是 `app.feature.kanban.*`） | 可以整体删除，换成自己的业务 |

依赖方向：

```
feature → base / app.schema / cumulo-reel.partition（例如 PartitionSlot 类型）
wiring  → feature / base / template
template → app.schema / app.hooks* / app.config / cumulo-reel.partition（不能引用 app.feature.*，也不能引用入口命名空间）
```

`tests/template-boundary.mjs` 断言两件事：template 的代码、测试和 imports 里不出现 `app.feature.*` 或入口命名空间；
feature 不依赖 `app.hooks*` 和入口命名空间。

## 2. Hooks：模板调用业务的唯一入口

**`app.hooks.server`**

| hook | 签名 | 作用 |
|------|------|------|
| `updater` | `Db DomainOp sid op-id time → Db` | 纯 reducer，由 Reel 调用 |
| `session-store` / `shared-twig` | `Db Session SharedTwig → Store`、`Db Number → SharedTwig` | 每个连接的会话 Store |
| `project-partition` | `Db PartitionKey → PartitionView` | 分区投影。分区是可见性边界 |
| `session-partitions` | `Db Session → Set PartitionKey` | 服务端授权：这个 session 能订阅哪些分区 |
| `affected-partitions` | `Db DomainOp sid → Set PartitionKey` | 操作可能改变的分区，用操作之前的 Db 计算 |
| `after-domain-op!` | `Db Db DomainOp sid op-id time → Unit` | 提交之后、发布之前的副作用，例如追加冷数据 |
| `answer-query` | `Db sid Query → QueryReply` | 冷读取，身份只能取自 session |
| `persist!` | `→ Unit` | 和热 Db 快照一起持久化业务自己的状态 |

**`app.hooks.client`**

| hook | 签名 | 作用 |
|------|------|------|
| `class-mapper` | `Map Tag Dynamic` | ws-edn 需要按名字还原的业务 struct 和 enum |
| `dispatch-client!` | `Op → Bool` | 处理客户端本地操作；返回 false 表示交给服务端 |
| `on-query-reply!` | `request-id QueryReply → Unit` | 冷查询回复 |
| `after-partition-update!` | `PartitionKey (Map PartitionKey PartitionSlot) → Unit` | 分区 snapshot 或 patch 发布之后调用，例如重新拉取过期的冷内容 |
| `on-partition-drop!` | `PartitionKey → Unit` | 分区被撤销时调用，清理相关的私有缓存 |

## 3. 必须修改的 wiring 点

- `app.schema`：
  - `Op`、`DomainOp` 里的业务变体（当前是 `:kanban`，以及客户端本地的 `:client/*`）；
  - 对应的 `decode-operation`、`decode-domain-operation` 分支；
  - `PartitionKey`、`PartitionView` 的变体，以及 `decode-partition-key`；
  - `Query`、`QueryReply` 的变体，以及 `decode-query`；
  - `Db` 的业务字段，以及 `decode-database` 里对应的解码。
- `app.updater/updater`：把 `DomainOp` 路由到业务 reducer。
- `app.hooks*`：把各个 hook 的函数体换成新业务的实现。
- `app.comp.container`：页面路由到业务组件。
- `app.client`：`render-app!` 传入业务需要的缓存，`workload-entry!`，`main!` 里的 watcher。

## 4. 换成自己的业务（清单）

1. 新建 `app.feature.<name>.*`：schema（热视图 struct、冷数据 struct、业务操作 enum）、updater（纯 reducer 和冷效果）、
   twig（`project-partition`、`session-partitions`、`affected-partitions`）、server（业务状态、`answer-query`、持久化）、
   client（冷缓存、客户端本地操作）、comp（UI）。按 `Agents.md` 的 Step 0 先决定每个字段放在哪一层。
2. 按第 3 节修改 wiring 点，让 hooks 指向新业务。
3. 删除 `app.feature.kanban.*`，以及 wiring 里残留的 Kanban 变体，比如 `Op :kanban`、`:client/*`、`PartitionView :board`。
4. 运行 `yarn node tests/template-boundary.mjs --list`、`yarn check-types`、两端的原生测试，以及原生服务端 e2e
   （e2e 需要替换成新业务的场景）。
5. 分区引擎的测试在 cumulo-reel 模块里，不随项目复制；`app.schema/decode-partition-view` 的测试需要换成新业务的视图。

## 5. 从模块加载的部分（阶段 B）

纯函数的分区引擎放在 cumulo-reel（0.0.49 起）的 `cumulo-reel.partition`，不再复制到项目里：
`advance-partition`、`connection-actions`、`plan-partition-send`、ACK 进度、`apply-partition-deltas`
和 `struct-tree-input`，说明见 cumulo-reel 的 `docs/partition-sync.md`。key 和视图类型是泛型，
项目用自己的类型实例化，例如：

```cirru
:: 'cumulo-reel.partition/PartitionState 'app.schema/PartitionKey 'app.schema/PartitionView
:: 'cumulo-reel.partition/PartitionSlot 'app.schema/PartitionView
```

客户端校验视图的 decoder 是业务相关的，留在 `app.schema/decode-partition-view`，由 `app.sync.client`
传给 `apply-partition-deltas`。

放进 cumulo-reel 而不是新建模块：它本来就依赖 recollect、锁定同一工具链，而且只有应用直接依赖它，
发一个版本就能更新，不增加新的依赖冲突（对照 Calcit alpha.16 因为上游依赖冲突无法升级的情况）。

服务端运行时（分区注册表、发送、ACK 消息、冷查询传输）依赖 calcit-wss 原生传输，hooks 接口也还在演进，
仍然作为模板代码留在 `app.sync.*`。
