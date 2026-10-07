# 2026-10-07 分区引擎改从 cumulo-reel 加载（阶段 B）

- 删除 `app.sync.partition`，改用 cumulo-reel 0.0.49 的 `cumulo-reel.partition`。类型用泛型实例化：
  `PartitionState`/`PartitionAction` 取 `PartitionKey PartitionView`，`PartitionSlot` 取 `PartitionView`。
- `struct-tree-input` 也从模块加载，删除 `app.schema/struct-tree-input`。
- 业务相关的视图 decoder 移到 `app.schema/decode-partition-view`，`app.sync.client` 把它传给
  `apply-partition-deltas`；原 `struct-tree-input` 的 nominal 解码测试挂到这个 decoder 上。
- 引擎测试随引擎移到 cumulo-reel，`app.hooks/sample-partition-view` 只服务于这些测试，一起删除，
  `app.hooks` 命名空间不再存在。
- 没有新建模块：cumulo-reel 本来就依赖 recollect、锁定 alpha.6，只有本项目直接依赖它。
- 验证：两端 check-only、check-types（client 156、server 238 个定义）、两端原生测试、模板边界检查、
  生成 JS 测试、原生服务端 e2e 全部通过（cumulo-reel 0.0.49 发布前用本地构建覆盖 `.calcit/modules`）。
