# 冷热分离同步方案（Kanban + 个人操作历史模板）

> 状态：设计草案，尚未实现。本文给出把 Calcium 从“单一 Store 全量 diff/patch”调整为
> “公共热数据广播 patch + 个人热数据局部 patch + 冷数据按需查询”的分阶段方案，
> 并用 Kanban 看板与个人操作历史作为新的模板 demo。

## 1. 现状与瓶颈

当前链路（见 `app.server/sync-client!`、`mark-clients-dirty!`、`app.twig.container/twig-container`）：

```
任意 DomainOp → reel-reducer → request-sync!（16ms 合并）
  → mark-clients-dirty!：所有 active 连接都标脏
  → 对每个脏连接：twig-container(db, session, shared) 生成完整 Store
  → diff-twig-budgeted(上次已确认 Store, 新 Store)
  → patch / 超预算或超 64 ops 时回退 snapshot（整份 Store）
```

问题按影响排序：

| # | 问题 | 代价 |
|---|------|------|
| 1 | 任何变更都让**所有**连接变脏，每个连接各自生成并 diff **整个** Store | O(连接数 × Store 大小)，和变更大小无关 |
| 2 | 公共数据（成员列表、将来的看板）对每个连接重复 diff、重复 `format-cirru-edn` | 同一份 patch 被算 N 次、编码 N 次 |
| 3 | 一切都在 Store 里：历史、详情、归档这类“大而冷”的数据也只能放进 twig | Store 随数据量线性增长，diff 预算（50k visited / 80k emit）很快触顶，频繁退化为整份 snapshot |
| 4 | 全局单一 revision，客户端一个子树出错就整份 resync | resync 成本 = 整个 Store |
| 5 | Reel `:records` 无上限累积并可整体 replay；`persist-db!` 每次写整份 Db | 内存与写盘随操作数增长；操作历史无法分页读取 |
| 6 | 列表用 vector 表达顺序 | 一次拖拽重排会产生大量 vector diff op，10k 行需要提高 Node 栈 |

结论：diff/patch 本身没问题，问题是**它被用在了所有数据上，并且对每个连接重复执行**。

## 2. 目标模型：三层数据

| 层 | 例子（Kanban demo） | 同步方式 | 谁来算 |
|----|------|------|------|
| **公共热数据** Shared Hot | 看板的列、卡片摘要（标题/列/顺序/负责人）、在线成员、每块看板的活动计数 | 按 **topic** 订阅；每个 topic 每个 revision **只 diff 一次**，同一份已编码 patch 广播给所有订阅者 | topic 级 |
| **个人热数据** Personal Hot | 当前用户资料、偏好设置（主题、折叠的列、收藏的看板）、session 路由、草稿、未读计数 | 按用户/会话 topic 做 diff/patch，**只在该用户的数据变化时**标脏 | 用户级 |
| **冷数据** Cold | 个人操作历史、看板活动流、卡片详情与评论、已归档卡片、搜索结果 | **请求/回调**：`query` 带 request-id，服务端以分页结果回调；不进入 diff；变化时只推轻量 `invalidate` 提示 | 按需 |

判断一份数据放哪一层：

- 大多数在线用户需要同时看到、且体量有界 → 公共热；
- 只属于一个用户、体量小、需要即时一致 → 个人热；
- 体量无界（随时间增长）、只在打开某个视图时才需要、允许“点一下再加载” → 冷。

## 3. 协议调整

在现有 nominal `ClientMessage` / `ServerMessage`（`app.schema`）基础上**新增**变体，旧变体保留到迁移完成。

```cirru
defenum Topic
  :board 'String          ; 公共：一块看板的热数据
  :presence               ; 公共：在线成员
  :me                     ; 个人：当前登录用户（服务端从 session 解析，不信任客户端传 uid）
  :session                ; 个人：路由、消息等会话态

defenum ClientMessage
  ; ...现有 :sync/* 与 :dispatch 保留
  :topic/subscribe 'Topic 'Number       ; 带客户端已有 revision，0 表示要 snapshot
  :topic/unsubscribe 'Topic
  :topic/ack 'Topic 'Number
  :query 'String 'Query                 ; request-id + 查询

defenum ServerMessage
  ; ...现有 :snapshot / :patch / :effect/pong 保留
  :topic/snapshot 'Topic 'Number 'Dynamic
  :topic/patch 'Topic 'Number 'Number $ :: 'List 'recollect.schema/change-op
  :query/page 'String 'Page
  :query/error 'String 'String
  :hint/invalidate 'Invalidation        ; 例如某看板活动流有新条目，带新条目数

defenum Query
  :history/mine $ :: 'Option 'String            ; cursor，none 表示第一页
  :board/activity 'String $ :: 'Option 'String
  :card/detail 'String
  :board/archived 'String $ :: 'Option 'String

defstruct Page (:items $ :: 'List 'Dynamic) (:next-cursor $ :: 'Option 'String) (:as-of 'Number)
```

要点：

- **revision 改成按 topic 计**。一个 topic 出错只 resync 这个 topic，不影响其他 topic。
- 现有的 ack 基线、单 in-flight、backpressure、`too-large` 和预算等规则**原样下沉到每个 (连接, topic)**，已有回归测试的语义不变。
- `query` 是无状态的请求/响应：服务端不为它保存 diff 基线，客户端按 request-id 关联回调，并丢弃过期的响应（例如路由已切走）。
- cursor 采用不透明字符串，内部为 `(时间, id)`，保证翻页时插入新数据也不重复、不丢。

## 4. 服务端结构

### 4.1 数据存储拆分

```
Db (内存，热，可 diff)
  :sessions   Map Number Session
  :users      Map String User
  :settings   Map String UserSettings
  :boards     Map String Board
                Board: :id :title :members (Set String)
                       :columns Map String Column        ; Column: :id :title :rank
                       :cards   Map String CardSummary   ; :id :column-id :rank :title :assignee :updated-at
                       :activity-count Number

ColdStore (按追加写，不进 twig)
  history/<user-id>     分段追加的 HistoryEvent 日志（可以是每天或每 N 条一个文件）
  activity/<board-id>   看板活动流
  card-detail/<card-id> 描述、评论
  archive/<board-id>    已归档卡片
```

- 顺序用 **fractional rank 字符串**（如 `"a0"`、`"a0V"`），存在 `Map id → item` 里；客户端渲染时排序。拖动一张卡只改一个叶子 `:rank`/`:column-id`，patch 只有 1–2 个 op，不再出现 vector 重排。
- 冷数据从热 Db 中**彻底拿走**：Db 只存计数或最近几条摘要（例如 `:activity-count`），保证热 Db 的体量和用户数、看板数成正比，与时间无关。

### 4.2 updater 输出影响面

保持 updater 为纯函数，但让 reducer 同时返回这次操作影响到的 topic 与冷数据事件：

```cirru
defstruct Effects
  :topics $ :: 'Set 'Topic          ; 受影响的热 topic
  :users  $ :: 'Set 'String         ; 受影响的个人 topic（用户 id）
  :cold   $ :: 'List 'ColdEvent     ; 追加到冷存储的事件（历史、活动）

; updater :: Db DomainOp Sid OpId Time -> (Db, Effects)
```

也可以不改 updater 签名，另写一个纯函数 `op-effects (db-before op sid) → Effects` 推导影响面（推荐，现有 updater 和测试改动更少）。例如：

| DomainOp | 热 topic | 个人 | 冷事件 |
|---|---|---|---|
| `:card/move card-id col rank` | `(:board b)` | — | `activity/b`、`history/操作者` |
| `:card/edit-detail card-id text` | `(:board b)`（仅 `:updated-at`） | — | `card-detail/c`、`history/操作者` |
| `:settings/toggle-column col` | — | 操作者 | `history/操作者`（可选） |
| `:session/connect` | `:presence` | — | — |

### 4.3 同步调度（替代 `mark-clients-dirty!`）

```
*subscriptions : Map Topic (Set Sid)      ; 反向索引
*topic-state   : Map Topic {:revision :value :encoded-patches (ring buffer)}
*client-topics : Map (Sid, Topic) {:acked-rev :in-flight :needs-snapshot? ...}  ; 由现有 client-state 下沉而来

dispatch → (db', effects)
  → 冷事件追加到 ColdStore，并给相关订阅者排一个 :hint/invalidate（合并后发）
  → dirty-topics ∪= effects.topics ∪ (users → :me topics)
  → 16ms 合并窗口到期：
      对每个 dirty 公共 topic：
        new = project-topic(db', topic)          ; 每个 topic 只算一次
        changes = diff-twig-budgeted(prev, new)  ; 每个 topic 只 diff 一次
        payload = format-cirru-edn (:topic/patch topic rev-1 rev changes)  ; 只编码一次
        放进 ring buffer（保留最近 K 个 revision 的已编码 patch）
        对订阅者：acked-rev == rev-1 → 直接发送 payload
                  acked-rev 落后但仍在 ring 内 → 依次发送已缓存的 patch，或合并后发送
                  更早或 needs-snapshot → 发 topic snapshot
      对每个 dirty 个人 topic：沿用现有的单连接 diff 逻辑，只是输入变成个人切片
```

收益：一次卡片移动的成本从 “N 个连接 × 整个 Store 的 diff” 降为 “1 次看板 diff + N 次发送同一个字符串”。没有订阅该看板的连接完全不参与。

Twig 缓存：现有 `get-shared-twig`（按全局 revision 缓存）泛化为按 `(topic, topic-revision)` 缓存；Recollect memo frame 仍包在一次 flush 外面。

### 4.4 冷数据查询

```cirru
defn handle-query! (sid request-id query)
  ; 1. 鉴权：从 session 取 user-id；:history/mine 只能读自己的数据，:board/* 要检查成员资格
  ; 2. 读 ColdStore（可以异步读文件，完成后回调发送）
  ; 3. wss-send! sid (:query/page request-id page)，单页上限 N 条，并限制字节数
```

- 查询不改变热 Db，也不写进 Reel record。
- 冷数据变化时只推 `:hint/invalidate`（例如 `(:board/activity b 3)` 表示有 3 条新的），由客户端决定是刷新第一页还是只显示“有新内容”。
- 读路径设限：单页条数、单次查询字节、每个连接同时进行的查询数。

### 4.5 Reel 与持久化

- Reel 只保留**最近 M 条** record 供开发期 time-travel（`:reel/merge` 定期执行，或按 M 截断），不再承担“操作历史”的职责；用户可见的操作历史由 ColdStore 提供。
- `persist-db!` 只写热 Db（它的体量已经有界）；冷数据在事件发生时追加写，崩溃恢复靠分段日志。
- 现有的 `decode-database` 校验边界继续用于热 Db；冷日志逐条解码，坏行跳过并计数，不让整份数据作废。

## 5. 客户端结构

```cirru
defstruct Store
  :session  SessionView                    ; 个人热（:session topic）
  :me       $ :: 'Option 'MeView           ; 个人热（:me topic）：资料 + 设置
  :topics   $ :: 'Map 'Topic 'TopicSlot    ; 公共热：每个订阅一份
  :queries  $ :: 'Map 'String 'QueryState  ; 冷：按查询 key 缓存的页

defenum TopicSlot (:loading) (:ready 'Number 'Dynamic) (:error 'String)
defenum QueryState
  :loading
  :ready $ :: 'List 'Page                  ; 已加载的页，按顺序
  :stale $ :: 'List 'Page                  ; 收到 invalidate 后的旧页，仍可显示
  :error 'String
```

- 路由变化时**由客户端发** `:topic/subscribe` / `:topic/unsubscribe`（例如进入 `/board/b1` 订阅 `(:board |b1)`，离开时取消），服务端据此维护反向索引；页面不可见时现有的 idle 逻辑对所有 topic 生效。
- 每个 topic 单独执行现有的 validated `PatchBatch .apply-to`：校验失败只为这个 topic 请求 snapshot。
- `:sync/resume` 改为携带 `Map Topic revision`，断线恢复后逐个 topic 续传。
- 冷查询：`(query! q)` 生成 request-id，写入 `:queries key → :loading`；结果到达时校验 request-id 仍然有效再写入。滚动到底时用 `next-cursor` 加载下一页。
- 乐观更新（可选、后续）：卡片拖动先在本地更新 rank，收到 topic patch 时以服务端为准，被拒绝时回滚。

## 6. Kanban demo 设计

页面：

1. **看板列表**（公共热 `:presence` + 个人热 `:me` 里的收藏）。
2. **看板页** `/board/:id`：订阅 `(:board id)`。显示列、卡片摘要、在线成员。拖动卡片发送 `:card/move`。顶部“活动 (3 条新)”的提示来自 `:hint/invalidate`。
3. **卡片详情抽屉**：打开时 `query (:card/detail id)`（冷），编辑后服务端追加冷事件，并只把摘要里的 `:updated-at` 写回热 Db。
4. **活动流侧栏**：`query (:board/activity id cursor)`，无限滚动分页。
5. **我的操作历史** `/history`：`query (:history/mine cursor)`，按天分组，显示“移动了卡片 X 从 A 到 B”等；可按看板筛选（作为 `Query` 的参数扩展）。
6. **设置**：个人热 `:me`，修改后立刻同步到该用户的所有标签页（同一用户多 session 都订阅 `:me`）。

新增 DomainOp（示例）：

```cirru
defenum DomainOp
  ; 现有 session/user/router 保留
  :board/create 'String
  :column/add 'String 'String              ; board-id title
  :card/add 'String 'String 'String        ; board-id column-id title
  :card/move 'String 'String 'String       ; card-id column-id rank
  :card/rename 'String 'String
  :card/archive 'String
  :card/edit-detail 'String 'String        ; 只写冷存储 + 更新摘要 :updated-at
  :settings/set 'SettingsPatch
```

`HistoryEvent`：`(:id 'String) (:time 'Number) (:user-id 'String) (:board-id (:: 'Option 'String)) (:kind 'Tag) (:summary 'String) (:data 'Dynamic)`，由 `op-effects` 从 DomainOp 和执行前的 Db 推导，无需在 updater 里做 I/O。

种子数据：提供一个开发模式下的 seed 命令（例如 3 个用户、2 块看板、每块看板 200 张卡片、每个用户 5,000 条历史），用于手工体验和 workload。

## 7. 实施阶段

每个阶段都可以单独合并，并且都要求 `yarn check-types`、原有原生测试和 `yarn workload:smoke` 保持通过。

| 阶段 | 内容 | 验收 |
|---|---|---|
| **P0 基线** | workload 增加“连接数”维度：1/10/100 个连接 × 1k/10k 实体，记录单次变更的服务端 CPU 与发送字节 | 产出可复现的“改动前”报告（保存在仓库外） |
| **P1 Topic 化协议** | 新增 `Topic`、`:topic/*` 消息与按 topic 的 client state；先把现有 Store 拆成 `:session`、`:me`、`:presence` 三个 topic，行为保持一致 | 旧回归（乱序/重复 ack、坏 payload、慢读端）在 topic 粒度全部重写并通过 |
| **P2 公共 topic 广播** | `op-effects` + 订阅反向索引；公共 topic 每个 revision 只 diff、编码一次，再加上已编码 patch 的 ring buffer | 100 连接时单次变更的 diff 次数 = 1；不订阅的连接零工作；一致性 oracle 通过 |
| **P3 冷数据通道** | `:query` / `:query/page` / `:hint/invalidate`；ColdStore 分段追加日志；鉴权和读路径限额 | 历史 5,000 条时热 Store 体量不变；分页不重不漏（含翻页期间插入） |
| **P4 Kanban demo** | Board/Column/CardSummary schema、fractional rank、看板页、卡片详情、活动流、我的历史、设置；替换原有的 home/profile demo | 拖拽一张卡只产生 ≤2 个 patch op；浏览器 runner 验证 DOM 一致性 |
| **P5 Reel/持久化收敛** | Reel record 截断或定期 merge；`persist-db!` 只写热 Db；冷日志的崩溃恢复测试 | 长时间运行内存平稳；损坏的冷日志行被跳过并计数 |
| **P6 文档与 Agents.md** | 更新 README、`Agents.md` 的 5 步流程：新增“先判定数据层级”这一步；`docs/architectures/` 增加对应 cirru 规格 | 新功能按模板可在一处判定层级 |

兼容策略：P1–P2 期间服务端同时支持旧的 `:snapshot`/`:patch`（视为一个隐式的 `:legacy` topic），客户端切换完成后在 P4 删除。

## 8. 指标

在现有 `SyncMetrics` 基础上增加：

- 每个 topic 的 diff 次数、diff 延迟、patch 字节数，以及 ring 命中和 snapshot 回退次数；
- 每次 flush 涉及的 topic 数、发送次数，以及“每次变更的 diff 次数”（目标是公共 topic 恒为 1）；
- 查询：QPS、p95 延迟、单页字节数、被限流次数；
- invalidate 推送数（合并后）。

## 9. 风险与取舍

- **topic 粒度**：太粗会回到全量 diff，太细会让订阅管理变复杂。建议以“一个页面需要的一块公共状态”为单位（如一块看板），不要细到单张卡片。
- **多 topic 之间的一致性**：不同 topic 的 revision 独立，客户端可能短暂看到看板已更新而活动计数还没更新。对 demo 场景可以接受；需要强一致的数据应放在同一 topic。
- **冷数据的新鲜度**：靠 invalidate 提示 + 用户触发刷新，不保证实时。需要实时的部分（如未读数）以计数形式放进个人热数据。
- **鉴权面变大**：query 是新的读入口，必须在服务端从 session 推导身份，并对每类 Query 做成员资格检查；分页参数要做边界校验（沿用 `app.schema` 的一次性解码模式）。
- **ColdStore 实现**：先做本地分段文件，接口抽象为 `append!` / `read-page`，以后可以替换成 SQLite 或外部存储，同步层不感知。
