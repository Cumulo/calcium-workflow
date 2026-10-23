## Calcium workflow

> template for mini realtime apps, based on calcit-js eco. But with calcit-rs runtime.

### Usages

Install Node.js, Yarn, [Calcit](https://github.com/calcit-lang/calcit) to start.

Install the dependencies declared in `deps.cirru` with `caps --strict --ci`.
They are linked under `.calcit/modules/` from the immutable module cache.

Use Calcit's `query`, `tree`, and `edit` commands to inspect and edit the snapshot.

Run frontend:

```bash
# dev mode
corepack enable && corepack prepare yarn@4.18.0 --activate
yarn install --immutable
caps
yarn watch-page
yarn vite # for browser app

# release mode
caps --ci
yarn install --immutable
yarn compile-page
yarn release-page
```

Run backend in calcit-rs:

```bash
# dev mode
mode=dev calcit -w calcit.cirru --entry server

# release mode
calcit calcit.cirru --entry server
```

当前 CLI 与 npm runtime 精确配对正式 Calcit **0.30.1**。升级后重新安装依赖、重启
服务并刷新浏览器，不能混用旧 alpha runtime/native 库。Respo `0.16.124`、
JS-FFI `0.2.5`、UI `0.8.0`、Util `0.0.31`、Message `0.0.38`、Recollect `0.0.67`、
ws-edn `0.0.47`、calcit-wss `0.2.37`、calcit.std `0.2.44`、Reel `0.0.61`
均使用已发布正式 Git tag，不使用 main/hash 或本地候选覆盖。UI 0.8 基础样式可能影响外观。

本轮使用官方受保护事务清理原附带测试中的 23 处旧 Option helper，原 99 项测试的名称、
tag、断言和执行顺序保留；业务函数代码与两处页面 `hud!` 不改。连接状态、同步 revision、
只读 Reel 和同步 metrics 四个 Ref 补上真实具体类型合同，不增加强转或 Dynamic 预算。
原模板边界检查改用官方 query 读取 imports、定义及附带区域，不再正则拆 Snapshot 文本；
原三类边界规则保留，独立合成副本验证非法 import/附带测试/entry 依赖仍会被拒绝。
已有 workload 的 List 转换改用公开 `listToArray`，不读取 runtime 私有数组布局。
不增加测试脚本、验证框架或进程管理器；正式 Linux 与实际页面验收待完成。

### 历史 alpha.4 迁移与验收

必填配置通过公开 `get` / Option 和具体边界解码读取，缺失仍拒绝，不新增兜底值。
Kanban 操作参数直接用类型谓词验证；Map 遍历使用 `MapEntry` / `map-list-kv` /
`filter-map-kv` 保留键值关系，不把异构 pair List 断言成业务类型。
共享 Twig 的私有缓存改为具名 Struct + Option，避免热路径反复深度解码缓存值；
它不进入数据库或线协议。effect 与 WSS callback 明确返回 Unit，保留原有副作用顺序。
历史 Reel 的 base 仍先验证，再构造保留 records/merged? 的具体数据库类型 Reel。
旧 Dynamic 数量 baseline 已退役，`yarn check-types`
按 browser/native 检查全项目公开定义（156/239 个）。严格入口检查、完整 strict、
dynamic-method/deprecated-call 检查和全部既有原生、生成 JS 回归均保留。
项目代码中的 Option helper 改为 `.unwrap`、`.unwrap-or`、`.some?`、`.none?`，
旧 `list-match` 改为 `match (destruct-list ...)`，原生定时器使用带 `!` 的正式 API。
组件状态的 key 类型由泛型保留，不能强制收窄为 Tag 或扩大为 Dynamic；
固定 `:cursor` / `:data` 元数据通过公开 `get-in` 读取，业务输入仍经过原有具体类型解码。
运行时会在非法 Struct 写入时提前拒绝，解码器和补丁原子性测试仍独立验证数据边界。
CI 完整执行上述验证与原有运行回归，不以入口检查代替完整验收。详见
[发布工具链与成员显示回归](history/20261005-respo-alpha7-and-member-options.md)；
[UI 发布依赖与 Struct 更新](history/20261005-ui-alpha4-and-struct-updates.md)记录后续验证；
[Reel reset/merge 与 resync 指标](history/20261005-reel-and-resync-struct-updates.md)记录服务端更新；
[旧类型边界迁移记录](history/20261004-strict-client-boundaries.md)保留历史验证范围；
[冷热分区同步与 Kanban 模板](history/20261007-hot-cold-partitions.md)记录本次分区改造；
[模板分层](history/20261007-template-layers.md)记录模板与业务代码的拆分。

本轮原 client 44/44、server 68/68、全部既有 Node 回归与 100-entity workload smoke 通过。
核对完整测试清单后，还发现原 tag 分组漏跑两项已有测试；CI 的 native server entry
现直接执行全部 99 项（99/99），保留原 client 分组，不新增测试或单独 runner。
真实浏览器运行原 diff/patch workload：六类操作、patched DOM 与 fresh render 相同，
key/ref/listener/focus/selection 保持，no-op 无 DOM 修改；这不是整个 Kanban UI 的手工验收。
隔离 native Kanban E2E 验证共享 board patch、冷详情与私有历史、匿名拒绝和退出分区清理；
测试只使用临时合成数据库，不连接生产数据。完整性能 benchmark 不在本轮验收范围。
源码及附带测试的旧 `%{}` / `%::` 构造器已迁移到直接具名构造器，原断言、
variant、字段和执行顺序保持；用于解码兼容性测试的 EDN 字符串不作文本替换。
完整 strict、附带区域 surface 预览均无诊断或迁移建议；开放状态/宿主边界仍存在，
不宣称整个项目已静态化。

前端监听使用 `calcit calcit.cirru js -w`。结构化 CLI 编辑保存后，使用
`calcit edit inc --changed <namespace/definition>` 通知 watcher；忽略的
`.compact-inc.cirru` 是临时通知，不是退役的 `compact.cirru` 源码格式。

### CDN 与部署边界

COS 仅上传 `dist/` 前端资源，生产 prefix 为 `Cumulo/calcium-workflow/`；
PR prefix 隔离编号、run 和 attempt。构建使用 `VITE_BASE_URL`，本地默认 `./`。
仅使用 COS Action 自带公共 URL verify，不维护额外探测脚本。

原网页 rsync 和 `/servers/calcium-workflow/` 后端路径不变，只允许 main push 执行。
服务端产物包含 Snapshot、`deps.cirru` 与 `package.json`；服务器须安装匹配工具与模块后，
继续使用 `calcit calcit.cirru --entry server`。本轮不确认服务器已准备好，**不合并、不部署**；
前后端应一起升级，页面完整刷新，不能让旧服务配新页面。

### Template layers

Copying this repository as a template? Namespaces tell you what to keep:
`app.sync.*` is the runtime (keep unchanged), `app.feature.<name>.*` is the
replaceable business demo, and `app.schema` / `app.hooks*` / `app.updater` /
entry namespaces are the few wiring points that name the current feature.
`tests/template-boundary.mjs` (run in CI) keeps `app.sync.*` from referencing
business code directly. See [模板分层与替换业务](docs/template-layers.md) for
the hook list and the replace-the-feature checklist.

复制为新项目时：`app.sync.*` 原样保留，`app.feature.<name>.*` 是可整体替换的业务，
`app.schema`、`app.hooks*`、`app.updater` 与入口命名空间是唯一需要改成新业务的 wiring 点。

### Hot/cold partitions (Kanban template)

The demo is a Kanban board with personal operation history. Data is split by
how it must stay in sync:

- **Shared hot partitions** — `(:lobby)` and `(:board id)`. Each partition is
  diffed once per revision and the same delta (and encoded payload) is sent to
  every authorized subscriber; diff cost no longer grows with connection count.
- **Private hot partition** — `(:user id)`: settings and a `history-rev`
  counter, shared by all tabs of that user.
- **Session Store** — route and session messages, still synced per connection.
- **Cold data** — card descriptions and personal history live outside the hot
  Db and the Reel. Browsers fetch them with `ClientMessage :query` and request
  ids; hot partitions only carry `detail-rev`/`history-rev`, so stale replies
  are dropped and unused content is never downloaded.

The server decides subscriptions from the session (logged-out sessions see no
partitions; logging out drops them and clears private caches). Partition
envelopes carry an epoch plus base/revision, ACKs advance a per-connection
baseline, and missing history falls back to one bounded snapshot. See
[冷热分离同步：设计与实现状态](docs/hot-cold-sync-plan.md) for the protocol,
verification and remaining work (durable publish, reconnect resume, board
membership, scale benchmarks).

```bash
# end-to-end check against the native server (also runs in CI)
port=5099 calcit calcit.cirru --entry server &
yarn compile-page && yarn node tests/kanban-e2e.mjs ws://127.0.0.1:5099
```

模板 demo 改为 Kanban 与个人操作历史：公共分区（lobby、board）每个 revision 只 diff 一次并复用给
所有订阅者；私有 user 分区保存设置与 `history-rev`；卡片描述和历史作为冷数据经 request id 回调获取，
热分区只保留内容版本号。详见 [冷热分离同步：设计与实现状态](docs/hot-cold-sync-plan.md)。

### Realtime sync lifecycle

Calcium keeps realtime synchronization state per browser connection. A visible
page sends heartbeats and receives revisioned patches. A hidden page, or a
connection that misses heartbeats, becomes idle: the server records only the
latest dirty revision and releases its previous Twig cache. When the page is
visible again, the server sends a fresh snapshot before resuming patches.

Transport recovery has one owner: ws-edn manages visibility/online reconnect,
bounded backoff, generation replacement, and its 75-second receive deadline.
Calcium reuses cumulo-util's cleanup-backed browser lifecycle only for
application signals: visible/hidden activity and one 30-second revision
heartbeat. Main and hot reload replace the previous cleanup capability, so no
listener or timer accumulates. The older page-touch reconnect path and local
visibility interval have been removed.

传输恢复只有一个 owner：ws-edn 管理 visibility/online 重连、有界退避、generation
替换及 75 秒接收 deadline。Calcium 复用 cumulo-util 带 cleanup 的浏览器生命周期，
但只处理应用信号：visible/hidden 活跃状态和 30 秒 revision heartbeat。main 与热更新
都会先执行旧 cleanup，因此 listener/timer 不会累积；旧 page-touch 重连路径及本地
visibility interval 已删除。

The server allows only one unacknowledged snapshot or patch per connection.
Patches carry `base-revision` and `revision`; a client that cannot apply the
base requests a new snapshot. Even when the revision matches, the client applies
the batch through Recollect's validated `Result` API; a missing path, container
or payload type mismatch, invalid index, or unsupported operation rejects the
whole batch and deterministically requests a full snapshot. No partial tree is
published. Diffs above the configured operation threshold
fall back to snapshots, bounding the retained patch and client-side patch work.
Server diff traversal also uses deterministic budgets of 50,000 visited nodes
and 80,000 operation-construction units. A budget-exceeded result contains no
partial patch and goes directly to the existing snapshot/send policy. These
limits bound counted traversal work, not wall-clock time: map key
materialization, comparisons, large leaves, snapshot encoding, queue admission,
and backpressure remain independently bounded or observed.

服务端 diff 遍历还使用 50,000 个 visited node 与 80,000 个 operation-construction
unit 的确定性预算。超限结果不携带 partial patch，直接进入既有 snapshot/send
策略。这些上限约束的是已计数的遍历工作，而不是 wall-clock：map key
materialization、比较、大叶子、snapshot 编码、queue admission 与 backpressure
仍需分别设限或观测。

The per-client cache is the last acknowledged store, not merely the last value
offered to the socket. An accepted send keeps its candidate store separately
until the matching acknowledgement arrives. `(:backpressured)` leaves the
acknowledged baseline untouched, marks the client slow, and requeues only the
latest desired revision; the next attempt recomputes one patch from that stable
baseline. `(:too-large)` requests snapshot policy without spinning on the same
oversized payload, while `(:closed)` clears pending send state.

每个客户端的 cache 表示“已确认 store”，而不是最近一次尝试发送的值。只有
`(:accepted)` 且收到匹配 ack 后，pending store 才会成为新的 diff 基线。
`(:backpressured)` 不推进基线，标记 slow client 并合并到最新 dirty revision；
下一次发送从稳定的确认基线重新计算。`(:too-large)` 保持 snapshot 策略但避免
重复忙循环，`(:closed)` 则清理 pending send 状态。

A native slow-reader regression deliberately pauses the TCP reader while asking
for repeated 192 KiB snapshots. With calcit-wss 0.2.25, 16 requests produce only
9 delivered baseline snapshots before the bounded transport coalesces pressure;
the next acknowledged snapshot contains the final coalesced application state,
and the following patch uses that acknowledged revision as its base. Retryable
socket `WouldBlock`/timeout results keep the connection alive instead of being
reported as a disconnect.

原生慢读端回归会暂停 TCP reader，同时重复请求 192 KiB snapshot。使用
calcit-wss 0.2.25 时，16 次请求只实际收到 9 个 baseline snapshot，证明有界
transport 已触发背压；随后确认的 snapshot 包含最终合并后的业务状态，下一条 patch
也从该已确认 revision 继续。socket 的 `WouldBlock`/timeout 作为可重试结果处理，
不会再把普通慢读端误判为断线。

Ordinary state changes schedule one sync within a 16 ms coalescing window. The
first change starts the timer, so a continuous dispatch stream cannot postpone
the flush indefinitely. WebSocket backpressure uses an independent 200 ms retry
timer; it never blocks a new ordinary update from taking the fast path. Server
coordination iterates the synchronous `*client-states` and `*dirty-clients`
registries. Do not use asynchronous `wss-each!` callbacks as if they completed
before the next statement; reserve WebSocket FFI for transport operations.

The pure `cumulo-util.realtime/Coalescer` was evaluated here but is intentionally
not inserted into this server path: the existing fixed-window single timer is
already bounded and cannot starve, while the generic planner would still need
the same application-owned timer and add clock/state transitions without
removing duplicated behavior. RetryBackoff, HeartbeatLease, and browser
lifecycle do remove duplicated state and are reused through ws-edn/cumulo-util.

普通状态变更会在 16ms 合并窗口内安排一次同步。首个变更立即启动 timer，因此
持续 dispatch 不会无限推迟 flush。WebSocket 背压使用独立的 200ms 重试 timer，
不会阻塞新的普通更新走快速路径。服务端协调同步遍历自身维护的
`*client-states` 与 `*dirty-clients`；不要假设异步 `wss-each!` 回调会在下一条
语句之前完成，WebSocket FFI 只负责实际传输。

这里也评估了 `cumulo-util.realtime/Coalescer`，但没有强行接入：现有固定窗口单
timer 已经有界且不会饥饿，通用 planner 仍需应用持有同一个 timer，并额外增加
clock/state 转换，不能减少重复行为。RetryBackoff、HeartbeatLease 与 browser
lifecycle 确实删除了重复状态，因此已通过 ws-edn/cumulo-util 复用。

When migrating an older `(:patch changes)` application, first accept revisioned
`(:snapshot revision store)` and `(:patch base-revision revision changes)`
messages on the client, add `(:sync/ack revision)` and `(:sync/resume revision)`,
then switch the server cache to acknowledgement-driven advancement. Do not
advance a cache for `backpressured`, `too-large`, or `closed` send outcomes.
Use recollect 0.0.37 or newer and route incoming batches through `PatchBatch`
`.apply-to`; do not restore the old exception-only `patch-twig` boundary.

The template now represents the wire protocol as nominal `ClientMessage` and
`ServerMessage` enums. Raw Cirru EDN is decoded once in `app.schema`; revision,
snapshot, patch-list, and string operation payloads are validated before the
typed envelope reaches client/server synchronization code. New clients wrap
business operations in `ClientMessage :dispatch Op`. The server still decodes
legacy direct `Op` enums during rolling deployment, while old clients can keep
matching the unchanged snapshot/patch variant tags from named `ServerMessage`.

模板现在用 nominal `ClientMessage` 与 `ServerMessage` enum 表示线协议。原始
Cirru EDN 只在 `app.schema` 解码一次；revision、snapshot、patch list 与字符串
操作参数经过校验后，typed envelope 才进入客户端/服务端同步逻辑。新客户端把
业务操作包装为 `ClientMessage :dispatch Op`。滚动部署期间服务端仍兼容旧客户端
直接发送的 `Op`，旧客户端也可继续按未变化的 snapshot/patch variant tag 匹配
named `ServerMessage`。

Browser recovery keeps the nominal `ws-edn.client/WsClient`; ws-edn owns the
`visibilitychange`/`online` recovery listeners, generation gate, bounded retry,
and heartbeat deadline. Calcium's cleanup-backed lifecycle watcher only emits
application activity and revision heartbeats, so it never installs a second
reconnect path. Every successful open—including a reopened socket—sends
`ClientMessage :sync/resume` with the last applied revision before ordinary
activity/login messages. ws-edn generation gating discards callbacks from
replaced sockets, and hot reload replaces the active data handler without
rebuilding the connection. The template enables a 75-second inbound heartbeat
deadline. Its existing 30-second protocol heartbeat now receives a typed
`ServerMessage :effect/pong`, renewing healthy connections while a silent dead
socket is actively closed and recovered through backoff.

浏览器恢复会保留 nominal `ws-edn.client/WsClient`；`visibilitychange`/`online`
recovery、generation gate、有界重试与 heartbeat deadline 统一由 ws-edn 管理。
Calcium 带 cleanup 的 lifecycle watcher 只发送应用 activity 和 revision heartbeat，
不会安装第二套重连路径。每次成功 open（包括重新连接）都会先携带
最后已应用 revision 发送 `ClientMessage :sync/resume`，再发送普通 activity/login
消息。ws-edn 的 generation gating 会丢弃已替换 socket 的迟到 callback；热更新
只替换当前 data handler，不重建连接。模板启用 75 秒入站 heartbeat deadline；
已有的 30 秒协议 heartbeat 现在会收到 typed `ServerMessage :effect/pong`，健康连接
据此续租，静默失效 socket 则被主动关闭并通过 backoff 恢复。

Server synchronization observability is available through
`app.sync.server/read-sync-metrics`. The typed `SyncMetrics` snapshot records the
latest diff latency, the latest patch payload's real UTF-8 byte length, patch
and snapshot payload byte lengths, latest visited/emitted diff work, budget
fallback count, patch and snapshot send attempts, explicit resync requests, and
the latest revision.
Pending-ACK and slow-client gauges are calculated only when the snapshot is
read, so ordinary dispatch/send paths do not rescan every connection. Attempt
counts include transport retries; combine them with calcit-wss `wss-metrics`
when transport admission and queue details are needed.

服务端同步观测可通过 `app.sync.server/read-sync-metrics` 获取。Typed
`SyncMetrics` snapshot 记录最近 diff 延迟、最近 patch payload 的真实 UTF-8
字节数、最近 snapshot 字节数、visited/emitted 工作量、预算回退次数、
patch/snapshot 发送尝试次数、显式 resync 请求数与最新 revision。
等待 ACK 和 slow-client gauge 只在读取 snapshot 时计算，普通 dispatch/send
热路径不会重新扫描所有连接。发送尝试包含传输重试；需要 transport admission
与队列细节时，可与 calcit-wss 的 `wss-metrics` 组合使用。

Payload byte accounting uses Calcit's string receiver method
`.utf8-byte-count`; the template no longer carries an interpreted helper on this
hot path. 字节统计直接使用 Calcit 的 String 方法 `.utf8-byte-count`，
不再在模板中维护解释执行的辅助函数。

Twig rendering is split into a shared projection cached once per Reel revision
and a session-specific projection. Keep both layers pure and deterministic so
unchanged application state does not create artificial patches.

Cache ownership is intentionally narrow. Respo owns component memoization;
Recollect owns keyed Twig memoization; Calcium keeps only protocol/business
caches such as the revision-indexed shared Twig and per-client patch baselines.
`sync-clients!` opens one Recollect memo frame around the active dirty clients,
so entries for idle/disconnected clients are pruned without every application
implementing cache bookkeeping. Twig code should use the typed
`memo-twig-by0`, `memo-twig-by1`, or `memo-twig-by2` helpers. The generic
`memof` module is not part of the Calcium dependency graph.

### Diff/patch regression workload

The deterministic workload replays the same typed `DomainOp` sequence over
keyed entities: no-op, leaf update, insert, remove, reorder, and full replace.
The data runner checks each patched client Store against a fresh projection and
also covers a slow client, out-of-order and duplicate acknowledgements, wrong
revisions, invalid payloads, recovery convergence, and a deliberately corrupted
baseline oracle. CI runs only the small correctness smoke:

```bash
yarn workload:smoke
```

Run the performance workload only on a fixed environment. It warms up first,
then records at least 30 samples for both 1,000 and 10,000 entities, including
p50, p95, variance, stage throughput, visited/emitted diff work, patch and
snapshot bytes, process memory, toolchain/environment metadata, input and
dependency hashes, and the raw report hash. Keep raw results outside this
repository; allocation data is reported as unavailable because JavaScript does
not expose a stable per-stage allocator API. The benchmark script raises Node's
stack explicitly because Recollect's 10,000-row vector diff exceeds Node's
default JavaScript stack.

```bash
yarn workload:benchmark --out /absolute/path/outside/repo/calcium-data.json
yarn workload:browser
# then open:
# http://127.0.0.1:5173/tests/diff-patch-browser.html?mode=full
```

The browser runner measures VDOM diff and DOM write independently and compares
every patched DOM with a fresh render. It also asserts zero no-op DOM mutation,
stable keyed node identity and ref behavior, listener continuity, and retained
focus/selection. Both commands begin with `caps verify --toolchain`, so a global
Calcit binary that differs from `deps.cirru` fails before producing a baseline.

差量回归会对固定 seed 的 keyed entity 重放同一组 typed `DomainOp`：no-op、叶子
更新、插入、删除、重排和全量替换。数据 runner 会逐步比较 patch 后的客户端 Store
与 fresh projection，并覆盖慢客户端、乱序/重复 ack、错误 revision、非法 payload、
恢复收敛以及故意损坏 baseline 的 oracle。CI 只运行小规模正确性 smoke。

完整基线仅在固定环境运行：先 warmup，再分别对 1,000/10,000 entity 采集至少 30
次，输出 p50、p95、方差、阶段工作量、环境/工具链、输入/依赖哈希和 raw hash。原始
结果还包含阶段吞吐、visited/emitted diff 工作量、patch/snapshot 字节数与进程内存；
必须保存在仓库外。JavaScript 没有稳定的逐阶段 allocator API，因此 allocation
明确记录为 unavailable。10,000 行的 Recollect vector diff 会超过 Node 默认的
JavaScript 栈，因此 benchmark 脚本显式提高栈上限。浏览器 runner 独立测量 VDOM
diff 与 DOM write，并验证 patched DOM 等于 fresh render、no-op 不产生 DOM
mutation，以及 key/ref/listener/focus/selection 语义不变。命令会先执行
`caps verify --toolchain`，避免静默混用全局 Calcit 版本。

### License

MIT
