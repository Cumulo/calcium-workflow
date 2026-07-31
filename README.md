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
mode=dev cr --entry server -w

# release mode
cr --entry server
```

### Realtime sync lifecycle

Calcium keeps realtime synchronization state per browser connection. A visible
page sends heartbeats and receives revisioned patches. A hidden page, or a
connection that misses heartbeats, becomes idle: the server records only the
latest dirty revision and releases its previous Twig cache. When the page is
visible again, the server sends a fresh snapshot before resuming patches.

The server allows only one unacknowledged snapshot or patch per connection.
Patches carry `base-revision` and `revision`; a client that cannot apply the
base requests a new snapshot. Diffs above the configured operation threshold
fall back to snapshots, bounding the retained patch and client-side patch work.
The current threshold is checked after diffing; an interruptible node/time
budget inside Recollect is still required to bound worst-case diff CPU.

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
