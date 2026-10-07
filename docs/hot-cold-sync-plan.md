# 冷热分离同步：设计与实现状态

> 对应 issue：[#54 分区拆分冷热数据](https://github.com/Cumulo/calcium-workflow/issues/54)、
> [#55 共享分区 diff 与私有热状态](https://github.com/Cumulo/calcium-workflow/issues/55)、
> [#56 版本化冷内容 callback](https://github.com/Cumulo/calcium-workflow/issues/56)、
> [#57 场景验收](https://github.com/Cumulo/calcium-workflow/issues/57)、
> [#58 声明式 Resource](https://github.com/Cumulo/calcium-workflow/issues/58)。
> 本文记录模板里已经实现的第一版，以及尚未覆盖的部分。

## 1. 为什么要改

原链路（仍保留给 session Store 使用）：任意操作 → 所有 active 连接标脏 → 每个连接各自生成并 diff
整个 Store → 各自编码发送。成本是“连接数 × Store 大小”，与这次改了多少数据无关；历史、正文等
随时间增长的数据也只能塞进 Store，diff 很快超出预算，退化成整份 snapshot。

## 2. 三层数据

| 层 | Kanban 模板中的例子 | 同步方式 | 实现位置 |
|----|------|------|------|
| 公共热分区 | `(:lobby)` 看板摘要 + 在线用户；`(:board id)` 列与卡片摘要 | 每个分区每个 revision 只 diff 一次，所有订阅者复用同一个 delta 和同一份编码 payload | `app.partition`、`app.twig.partition`、`app.server/sync-partitions!` |
| 私有热分区 | `(:user id)` 资料、设置、`history-rev` | 与公共分区同一机制；同一用户的多个连接复用 | 同上 |
| 会话 Store | 路由、session 消息、登录状态 | 沿用原 revision/ACK/resync 的单连接 diff，体量很小 | `app.twig.container`、`app.server/sync-client!` |
| 冷数据 | 个人操作历史、卡片描述 | `ClientMessage :query` + request id 回调；不进入 diff；热分区只放 `detail-rev` / `history-rev` | `app.updater.kanban`（读写）、`app.resource`（客户端缓存） |

判断规则：所有订阅者都能看到、体量有界 → 公共分区；只属于一个用户、需要即时一致 → 私有分区；
随时间增长、只在打开某个视图时才需要 → 冷数据，热分区里只留 id、摘要和内容版本号。

**分区就是可见性边界**：分区里的所有数据对它的订阅者都可见。私有字段不能先广播再由客户端过滤。
订阅由服务端决定（`session-partitions`）：未登录 → 没有分区；登录 → lobby + 自己的 user
分区 + 当前路由指向的 board。登出后下一次 flush 会发 `:part/drop`，客户端清除缓存；drop 掉 user
分区时同时清空私有冷缓存。

## 3. 协议

```cirru
defenum PartitionKey (:lobby) (:board 'String) (:user 'String)
defenum PartitionView (:lobby LobbyView) (:board Board) (:user UserHotView) (:missing)
defstruct PartitionDelta (:base 'Number) (:revision 'Number) (:changes (:: 'List change-op))

; 服务端 → 客户端
:part/snapshot PartitionKey epoch revision PartitionView
:part/patch PartitionKey epoch (List PartitionDelta)   ; 连续 delta 链
:part/drop PartitionKey
:query/reply request-id QueryReply                      ; :history / :card-detail / :missing / :denied

; 客户端 → 服务端
:part/ack PartitionKey epoch revision
:part/resync PartitionKey
:query request-id Query                                 ; (:history cursor limit) / (:card-detail board-id card-id)
```

- **epoch**：分区创建时从进程级单调计数器取得，以进程启动时间为种子。分区被回收后再创建会换新 epoch，
  旧 lineage 的 ACK 和 delta 都不会匹配。
- **ACK 推进基线**：每个（连接，分区）最多一个未确认发送；只有 `:accepted` 的发送才记录 pending，
  只有 epoch 和 revision 都匹配的 ACK 才推进基线，重复、乱序、过期的 ACK 一律忽略。
  `:backpressured` 不推进，稍后从同一基线重试。
- **追赶**：订阅者落后时按保留的连续 delta 链补发（每个分区保留 32 条）。链断了、epoch 变了，
  或者 diff 超过预算/操作数上限，都发一份有界 snapshot，绝不会把最新 delta 套在旧基线上。
- **客户端原子应用**：epoch 和每个 base 都必须匹配，最终视图要按 nominal `PartitionView` 校验通过，
  才替换缓存；任何一步失败只对该分区发 `:part/resync`。
- **订阅交接**：服务端单线程；每次 flush 先推进所有脏分区，再为每个连接规划发送。新订阅的 snapshot
  就取自刚推进完的同一状态，读取和注册之间不会漏掉更新。

## 4. 服务端流程

```
dispatch-domain! op
  db-before → reel-reducer → db-after
  :kanban 操作 → kanban-effects(db-before, db-after) → apply-cold-effects（追加历史、替换卡片详情）
  mark-partitions-dirty! (affected-partitions db-before op sid)
  request-sync!                         ; 16ms 合并窗口
render-loop!
  sync-clients!       ; 会话 Store（原机制）
  sync-partitions!
    refresh-partitions!   ; 每个“脏且存活”的分区：一次投影 + 一次有预算的 diff
    对每个 active 连接：
      desired = session-partitions db session
      ensure-partition!    ; 首次订阅时创建，取新 epoch
      connection-actions   ; 已撤权 → drop；已授权 → snapshot / delta 链 / idle
      send-partition-action!  ; 单 delta 的 payload 每个 revision 只编码一次
    collect-partitions!   ; 没有订阅者的分区回收，存活分区数有界
```

`affected-partitions` 是纯函数：卡片和列的操作 → 该 board + lobby + 操作者的 user 分区；设置操作 →
user 分区；路由变化只改变订阅；会话类操作 → lobby。reel reset/merge 和热更新会把所有存活分区标脏。

可观测性：`app.server/read-partition-metrics` 返回 `PartitionMetrics`，包括 diffs、advances、resets、
snapshot/delta 发送次数、reused-payloads、drops、queries 和 live-partitions。diff 次数只随脏分区数增长，
发送次数随订阅连接数增长，两者分开计数。

## 5. 冷数据

- 冷存储 `ColdStore`（每个用户一份只追加的 `HistoryEvent` 列表，以及按卡片保存的 `CardDetail`）不在热 Db、
  也不在 Reel 里，单独持久化到 `cold-storage.cirru`。读写接口只有 `apply-cold-effects`、`history-page`
  和 `card-detail-reply`，以后可以换成数据库，同步层不需要改。
- **身份只来自服务端 session**：`:history` 永远只读调用者自己的；未登录返回 `:denied`；卡片详情只在热卡片
  仍存在时返回，否则返回 `:missing`。
- **版本化**：卡片的 `detail-rev`（热）和 `CardDetail :rev`（冷）由同一个已提交操作推进。客户端只接受仍在
  pending 的 request id，新请求会让旧请求失效；已关闭的面板、比缓存更旧的 rev 都会被丢弃。热 `detail-rev`
  前进时，只重新拉取当前打开的卡片，没打开的内容从不下载。
- **历史分页**：cursor 是只追加日志里的排他下标，新事件追加时保持稳定；每页 1..50 条，从新到旧；
  user 分区的 `history-rev` 只负责提示有 N 条新事件。每个用户最多保留 2000 条，超出时裁掉最旧的；
  裁剪会使旧 cursor 偏移，所以 `history-rev` 变化后客户端重新读第一页。

## 6. 验证

| 检查 | 位置 |
|------|------|
| 分区引擎：未变化不升 revision、N 个订阅者复用同一个 delta、历史裁剪回退 snapshot、epoch 变化、单 pending 与过期 ACK、溢出 reset、delta 链重放收敛、客户端原子应用 | `app.partition` 的测试（`--tag partition`） |
| 授权、投影与脏分区推导 | `app.twig.partition/session-partitions` 的测试 |
| 服务端真实路径：5 个订阅者、一次卡片新增 → 3 次 diff（每个脏分区一次）、0 次 snapshot、10 次 delta 发送、5 个订阅者拿到同一个 board delta、8 次 payload 复用 | `app.server/sync-partitions-with!` 的测试 |
| Kanban reducer、冷效果、历史分页、卡片详情回复、session 身份 | `app.updater.kanban`、`app.server/query-reply` 的测试 |
| 客户端冷缓存：迟到、过时、已关闭的回复 | `app.resource/receive-reply` 的测试 |
| 生成 JS 的 SSR：看板、看板不存在、历史、设置 | `tests/respo-client-boundaries.mjs` |
| 原生服务端端到端：两个用户共享同一份 board patch、冷描述不进入热 patch、版本化详情、私有历史、登出 drop、匿名读取被拒绝 | `tests/kanban-e2e.mjs`（已加入 CI） |

## 7. 尚未覆盖 / 后续

- **持久写入后才发布**（#54/#56）：模板仍沿用定期快照持久化（`persist-db!` 同时写热 Db 和冷存储）。
  “提交成功后再发布热状态”、不确定提交、提交后发布前崩溃的恢复，需要接入真实数据库（worktools/unionid#191/#192）后再做。
- **重连续传**：新连接一律从 snapshot 开始（有界）。客户端可以带上各分区的 epoch/revision 来续传，目前尚未实现。
- **按看板授权**：目前所有登录用户都能看到所有看板；成员资格检查应该放在 `session-partitions` 和 `card-detail-reply` 里。
- **跨分区一致性**：board 与 lobby 的 revision 相互独立，可能短暂不一致（例如卡片数量晚一步更新）。需要原子可见的数据应放在同一分区。
- **查询限流**：目前只限制了每页条数，还没有并发数和字节数的限制。
- **#57 场景与规模基准**：10k/100k 冷数据下的 RSS、diff 次数与连接数的关系、callback 延迟，需要在固定环境下测量并保留原始数据。
- **#58 声明式 Resource**：`app.resource` 已提供 request id、过期丢弃和 rev 比较这个核心；ResourceRef、
  订阅生命周期、inspect 仍是后续工作。
- **工具链**：Calcit 0.29.0-alpha.16 + 最新 respo/recollect 在 `caps --strict` 下与 cumulo-reel 0.0.48、
  respo-message 0.0.29、cumulo-util 0.0.25、ws-edn 0.0.35 的依赖请求冲突，需要等这些库发版后再升级；
  当前保持 alpha.6。
