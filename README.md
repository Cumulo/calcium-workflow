## Calcium workflow

> template for mini realtime apps, based on calcit-js eco. But with calcit-rs runtime.

### Usages

Install Node.js, Yarn, [Calcit](https://github.com/calcit-lang/calcit) to start.

Clone dependencies into `~/.config/calcit/modules/` with `caps` command from Calcit.

Code with [calcit-editor](https://github.com/calcit-lang/editor).

Run frontend:

```bash
# dev mode
corepack enable && corepack prepare yarn@4.12.0 --activate
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
The current threshold is checked after diffing; an interruptible node/time
budget inside Recollect is still required to bound worst-case diff CPU.

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

Browser recovery keeps the nominal `ws-edn.client/WsClient` instead of creating
untracked sockets from individual DOM callbacks. A pure typed policy selects
`none`, `reconnect`, or `connect` from connection, client, visibility, and
online state for manual page-touch acceleration. ws-edn owns the
`visibilitychange`/`online` recovery listeners, generation gate, bounded retry,
and heartbeat deadline, so the application does not install a second reconnect
path. Every successful open—including a reopened socket—sends
`ClientMessage :sync/resume` with the last applied revision before ordinary
activity/login messages. ws-edn generation gating discards callbacks from
replaced sockets, and hot reload replaces the active data handler without
rebuilding the connection. The template enables a 75-second inbound heartbeat
deadline. Its existing 30-second protocol heartbeat now receives a typed
`ServerMessage :effect/pong`, renewing healthy connections while a silent dead
socket is actively closed and recovered through backoff.

浏览器恢复会保留 nominal `ws-edn.client/WsClient`，不在各个 DOM callback 中
创建无法追踪的新 socket。纯 typed 策略根据 connected、client、visibility 与
online 状态为 page-touch 提供手动加速；`visibilitychange`/`online` recovery、
generation gate、有界重试与 heartbeat deadline 统一由 ws-edn 管理，应用不再安装
第二套重连路径。每次成功 open（包括重新连接）都会先携带
最后已应用 revision 发送 `ClientMessage :sync/resume`，再发送普通 activity/login
消息。ws-edn 的 generation gating 会丢弃已替换 socket 的迟到 callback；热更新
只替换当前 data handler，不重建连接。模板启用 75 秒入站 heartbeat deadline；
已有的 30 秒协议 heartbeat 现在会收到 typed `ServerMessage :effect/pong`，健康连接
据此续租，静默失效 socket 则被主动关闭并通过 backoff 恢复。

Server synchronization observability is available through
`app.server/read-sync-metrics`. The typed `SyncMetrics` snapshot records the
latest diff latency, the latest patch payload's real UTF-8 byte length, patch
and snapshot send attempts, explicit resync requests, and the latest revision.
Pending-ACK and slow-client gauges are calculated only when the snapshot is
read, so ordinary dispatch/send paths do not rescan every connection. Attempt
counts include transport retries; combine them with calcit-wss `wss-metrics`
when transport admission and queue details are needed.

服务端同步观测可通过 `app.server/read-sync-metrics` 获取。Typed
`SyncMetrics` snapshot 记录最近 diff 延迟、最近 patch payload 的真实 UTF-8
字节数、patch/snapshot 发送尝试次数、显式 resync 请求数与最新 revision。
等待 ACK 和 slow-client gauge 只在读取 snapshot 时计算，普通 dispatch/send
热路径不会重新扫描所有连接。发送尝试包含传输重试；需要 transport admission
与队列细节时，可与 calcit-wss 的 `wss-metrics` 组合使用。

Payload byte accounting uses Calcit 0.13.67's string receiver method
`.utf8-byte-count`; the template no longer carries an interpreted helper on this
hot path. 字节统计直接使用 Calcit 0.13.67 的 String 方法 `.utf8-byte-count`，
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

### License

MIT
