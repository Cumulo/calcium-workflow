# 冷热分区同步与 Kanban 模板

## 修改

按 #54/#55/#56 的方向，把“每连接完整 Store diff”拆分为：

- `app.partition`：纯分区引擎。每个分区维护 epoch、revision、视图和有界 delta 历史
  （32 条）；每个 revision 只 diff 一次，并按连接规划 idle / snapshot / 连续 delta 链。
  ACK 只在 epoch 与 pending revision 都匹配时推进；预算或操作数溢出时 reset 历史。
- `app.twig.partition`：lobby / board / user 投影、服务端订阅授权
  （`session-partitions`）以及按操作推导脏分区（`affected-partitions`）。
- `app.server`：分区注册表、首次订阅时取新 epoch、无订阅者时回收、单 delta 的 payload
  只编码一次、backpressure 下不推进基线；`:part/ack`、`:part/resync`、`:query` 的处理；
  `PartitionMetrics` 指标。
- 冷数据：`ColdStore`（个人只追加历史、版本化卡片详情）独立于热 Db 与 Reel，
  持久化到 `cold-storage.cirru`；查询身份只取自 session。
- 客户端：分区 snapshot 与 delta 链经 nominal `PartitionView` 校验后才发布，失败只
  resync 该分区；`app.resource` 按 request id 接收回复，丢弃迟到或旧 rev 的内容；
  drop user 分区时清空私有冷缓存。
- demo 改为 Kanban（lobby、看板、卡片详情）、个人历史与同步设置。

原 session Store 的 revision/ACK/resync 协议、预算与回归保持不变。

## 回归

新增原生测试覆盖分区引擎、授权投影、Kanban reducer 与冷效果、历史分页、查询身份、
客户端冷缓存，以及一次真实服务端路径（5 个订阅者、一次更新 → 每个脏分区 1 次 diff、
5 个相同的 board delta、8 次 payload 复用）。生成 JS 的 SSR 回归覆盖看板、历史和设置视图。
`tests/kanban-e2e.mjs` 对原生服务端跑两用户端到端流程，已加入 CI；本地还用 Playwright
在真实浏览器里走了一遍注册、建看板、移动卡片、编辑详情和查看历史。

客户端 45/45、服务端 77/77 原生测试通过，`check-types` 两个入口全部公开定义通过，
既有 JS 回归与 workload smoke 通过。

## 剩余

持久写入成功后才发布、重连续传、看板成员资格、查询并发限额、#57 规模基准与
#58 声明式 Resource 仍是后续工作，见 `docs/hot-cold-sync-plan.md`。工具链保持
Calcit 0.29.0-alpha.6；alpha.16 需等待 cumulo-reel、respo-message、cumulo-util、
ws-edn 配套发版后才能通过 `caps --strict`。
