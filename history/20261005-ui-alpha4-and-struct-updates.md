# UI 发布依赖与服务端 Struct 更新

## 正式依赖

UI `0.7.32-alpha.4` 已发布，annotated tag 指向主分支提交
`5fa77d1b1c57c263933a8583051b6f202ba37a2a`。该提交的 Actions
`37297583157` 完成严格 Caps、类型检查、原生与 JS 测试、公开接口、示例、
质量门禁及构建。Calcium 直接依赖升级到这个版本，没有本地源码覆盖。
UI 及其 router 已对齐 Respo alpha.7、JS-FFI alpha.13 和 CLI alpha.6。

## 服务端 Struct 更新

`read-sync-metrics` 使用 `struct-with` 更新 `SyncMetrics` 的连接 gauge，
保留已有计数器；`persist-db!` 使用同一 API 清空 `Db` 的 sessions。
两处数据原本已是 nominal Struct，不应经由通用 Map 的 merge/assoc 更新。
保持既有连接遍历、持久化格式、存储路径与备份策略。

新增服务端测试覆盖三个不同连接状态，验证 pending/slow 均为 2、保留
resync/patch 计数，并确认读取指标不修改原 atom。测试在断言前恢复全局状态。

## 验证与剩余工作

- 客户端与服务端默认严格入口检查通过；原生测试客户端 41/41、服务端 53/53。
- 重新生成 JS 后，Session/User Option、client-patch、Respo 边界与成员显示、
  mount、stored-login、connection-url 和差量 workload smoke 通过。
- Node 24 上 Vite 构建通过。
- 独立临时目录的原生服务在端口 5023 启动，SIGINT 退出码 0，写出 Db storage
  和备份；测试数据没有写入项目。`port=0` 启动失败，本次不将其记为通过。
- 严格 Caps 仍有五组冲突：util、UI、Respo、JS-FFI、ws-edn；旧 Reel、message、
  value、recollect 等上游仍请求旧版。此次升级没有消除全部冲突。
- 保留远端 `fec1175` 对 Store 解码与历史操作输入的收敛后，质量门禁仍有
  34 项逐定义回归（此前为 40 项），未调整预算或移除 CI 检查。完整 Actions
  尚不能通过。

其余 Store/ReelState 和开放输入路径仍可产生动态方法告警，本次仅修复上述
两个已知 Struct 更新点，不宣称整个应用消除了动态调用。
