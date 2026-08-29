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

Ordinary state changes schedule one sync within a 16 ms coalescing window. The
first change starts the timer, so a continuous dispatch stream cannot postpone
the flush indefinitely. WebSocket backpressure uses an independent 200 ms retry
timer; it never blocks a new ordinary update from taking the fast path. Server
coordination iterates the synchronous `*client-states` and `*dirty-clients`
registries. Do not use asynchronous `wss-each!` callbacks as if they completed
before the next statement; reserve WebSocket FFI for transport operations.

普通状态变更会在 16ms 合并窗口内安排一次同步。首个变更立即启动 timer，因此
持续 dispatch 不会无限推迟 flush。WebSocket 背压使用独立的 200ms 重试 timer，
不会阻塞新的普通更新走快速路径。服务端协调同步遍历自身维护的
`*client-states` 与 `*dirty-clients`；不要假设异步 `wss-each!` 回调会在下一条
语句之前完成，WebSocket FFI 只负责实际传输。

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
