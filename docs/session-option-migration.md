# Session view absence / SessionView 缺失值迁移

Issue: calcit-lang/calcit#876, aggregate #653 / #578.

The stored database/session maps retain their existing nil/missing-field input
format. The projection boundary converts absent SessionView user-id, id and
nickname to Option none, and validates present String/Number values before
constructing some. Zero and the empty string remain present values.

数据库和 session map 的输入格式保持不变；投影边界将缺失值转成 Option none，
有效值经过 String/Number 校验后构造 some。0 与空字符串不是缺失值。

The logged-in regression also exposed a pre-existing constructor mismatch:
UserView nickname/avatar were declared Option<String> but twig-user supplied
raw nil/String. That projection now performs the same explicit normalization.
Invalid present values raise rather than enter a falsely typed view.

已登录回归同时发现 UserView 的 nickname/avatar 构造与 Option 声明不一致，
现已修正。非法的非空值报错，不进入带错误类型的视图。

SessionView's serialized fields intentionally change from raw values/nil to
nominal Option values. Deploy client and server together; mixed-version clients
are not claimed compatible. Database input, message envelopes, revision/ACK and
diff/patch algorithms are unchanged. Serialized view roundtrips are tested.

SessionView 序列化字段会从裸值/nil 改为 nominal Option；客户端和服务端需配套
部署，不能声称兼容混合版本。数据库输入、消息 envelope、revision/ACK 与 diff/patch
算法未改，序列化往返已有测试。

Native client tests (10), server-tagged tests (12), and server-entry full tests
(21) pass. The generated-JS
`tests/session-option.mjs` suite covers missing/explicit nil, zero/empty present
values, rejected invalid field types, and Session/User EDN roundtrips. CI runs
this suite after compilation. The existing quality baseline passes unchanged,
and the production build passes.

Browser acceptance also exposed a pre-existing client state bug: the atom
initializer was an anonymous loading enum while subsequent values were Store
structs. Generated JS erased the enum predicate's alternative and tried to
render Store as an offline enum. Client state now has a nominal
`Ref<ClientState>` contract with loading/offline/ready(Store) variants. Snapshot
and patch handlers wrap validated Store values; rendering unwraps only ready.
The patch validator's Result schema was also reversed; it now uses the actual
`Result<Error, Value>` order, with a typed ready-state regression.

浏览器验收发现原先客户端 atom 混放 Enum/Store，导致生成 JS 丢失正常渲染分支。
现改为具名 ClientState；同时修正补丁验证器 Result 类型参数顺序。客户端状态
容器不参与服务端序列化，消息 envelope 和补丁算法不变。

Local browser smoke (isolated server port 15021, frontend 5182) reached Guest,
created a disposable local test user, rendered the authenticated home/profile,
and restored login after reloading the original URL. The profile Refresh button
has a separate existing limitation: it replaces the URL with origin plus time,
discarding the custom `port` query. Logout returned to Guest, and explicitly
logging in again restored the profile. That button's custom-port flow did not pass;
restoring the explicit test URL reconnects successfully. No production data or
Reel worktree was changed.

## Retained executable nil / 保留的可执行 nil

Calcit 0.13.77 reports 37 project-local occurrences in 16 definitions (10
namespaces). These are AST code positions, not tests, quoted examples, generated
JS or documentation. The following classification does not suppress their
analyzer status; the unchanged baseline still reports them as unresolved.

| Definition owner | Count | Meaning and decision |
| --- | ---: | --- |
| `app.client/reload!` | 1 | `hud!` inactive-message payload at the external bottom-tip API; retain the existing host call. |
| `app.comp.container/comp-container` | 1 | Respo `=<` absent spacing axis; retain the published helper's input convention. |
| `app.comp.container/comp-session-messages` | 1 | Respo `<>` absent style argument; not a callback drop result. |
| `app.comp.login/comp-login` | 3 | Respo `=<` absent spacing axes; retain helper compatibility inputs. |
| `app.comp.navigation/comp-navigation` | 2 | Respo `<>` absent style and `=<` absent axis. |
| `app.comp.profile/comp-profile` | 4 | Respo `=<` absent axes. |
| `app.schema/router` | 3 | Legacy open router template name/title/parent data; retain database/template shape. |
| `app.schema/session` | 5 | Legacy session user-id/id/nickname and nested router data/parent; normalize at projection, not in persisted input. |
| `app.schema/user` | 5 | Legacy open user name/id/nickname/avatar/password template; preserve stored format. |
| `app.server/*shared-twig-cache` | 1 | Internal cache value before any revision is projected; retain the paired revision/value cache protocol. |
| `app.server/invalidate-sync-caches!` | 1 | Resets that same cache protocol, not a Unit-return nil. |
| `app.twig.container/twig-container` | 5 | Legacy map lookup defaults (user-id/id/nickname) and default router data/parent; converted into owned Option view fields before publication. |
| `app.twig.container/twig-members` | 1 | Legacy members map uses nil when a session has no corresponding user name; keep existing members projection semantics, not a filter/drop sentinel. |
| `app.twig.user/twig-user` | 2 | Legacy nickname/avatar lookup defaults, now validated and converted into Option fields. |
| `app.updater.user/log-out` | 1 | Clears the legacy stored session user-id; projection produces none. |
| `app.updater.user/sign-up` | 1 | Initial absent avatar in persisted user data; projection produces none. |

保留项按实际边界分类，不将它们偷偷标为已解决，也不扩大本次变更为数据库、
缓存或 Respo helper API 的整体重构。`comp-session-messages` 的 `map-kv` 回调
始终返回 `[id, element]`，其中 nil 是内部 `<>` 参数，不是过滤用返回哨兵。

Reproduce:

```bash
calcit analyze weak-types --only code-nil --intent unresolved --format json
calcit --strict-types --check-only
calcit --entry server --strict-types --check-only
```

Both whole-strict commands remain blocked by `E_WHOLE_DYNAMIC_PUBLIC_SCHEMA`:
client at `app.comp.container/comp-offline`, server at an `if-let` callback in
`app.server/main!`. These early failures do not prove that all downstream strict
nil diagnostics pass. The schema migration and retained-boundary inventory are
evidence for the bounded change, not a whole-project strict-zero claim.

Browser/protocol validation, review and Actions remain required before this
issue is complete. Aggregate #653 must also retain the separate strict-preflight
limitation rather than close on the absence of raw Optional text alone.
