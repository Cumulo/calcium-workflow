# Reel reset/merge 与 resync 指标的 Struct 更新

## 修改

保留远端 `2fb25b2`、`7886712` 的受检 Op 与状态键收敛。
本次把服务端 dispatch 的 Reel reset/merge 改为 `struct-with`：
reset 恢复 base、清空记录并保留 merged 标志；merge 将当前 Db 设为 base、
清空记录并标记 merged。所有外层 dispatch、通知同步和业务操作分支不变。

`record-resync!` 使用明确的 SyncMetrics callback 更新计数，替代通用 Map update。
没有改变原 Struct 字段、记录格式、存储或网络协议，没有放宽外部输入。
Snapshot 只由 Calcit dry-run 与 revision 保护事务更新。

## 回归

新增两项真实函数回归，保留原测试：

- 构造不同 base/current Db 和非空记录，调用真实 dispatch reset/merge，
  检查 Db、base、记录清空与 merged 标志。测试预先占用同步调度标志，
  避免创建后台同步 timer，并在断言前恢复全局状态。
- 调用两次 `record-resync!`，确认仅 resync 增加 2，其他指标保持不变。

客户端 41/41、服务端 55/55 原生测试通过，两个默认严格入口通过；
重新生成 JS 后，既有 Respo/cursor/Tag/生命周期/SSR/成员 Option 回归通过。
record-resync 定向 `--warn-dyn-method` 回归没有动态调用告警。
reset/merge 的定向回归也通过；其他旧 Reel reducer/refresher 路径仍有告警，
不宣称整个应用已消除动态调用。

## 剩余门禁

原质量门禁仍为 27 项逐定义回归，没有提高预算或删除检查。
严格 Caps 的上游发布依赖冲突尚未解除，完整 Actions 仍不能通过。
本次是已有 nominal Struct 更新路径的运行时修复，不以测试通过替代 milestone 验收。

## 2026-10-06 配套依赖发版

获得用户授权后发布 Value 0.5.13、Message 0.0.29、Util 0.0.25、
Recollect 0.0.54 和 ws-edn 0.0.34。Value/Message/Recollect/WS 的 PR 与
合并主分支完整 CI 均通过；Util 使用已经合并且验证通过的 #42。
本项目消费发布标签，不引用 hash 或工作分支，不更改原检查、预算、源码或测试。

真实十二个发布模块上两入口、client 41/server 55、fresh JS、原 SessionOption、
patch/Respo/mount/stored-login/URL、workload smoke 与 Vite 构建通过，
canonical format 没有变化。质量门禁独立执行仍为 27 项回归。普通 Caps 的
七组警告全部来自已发布 Reel 0.0.47 的旧请求；严格 CI 需要先完成 Reel #50
质量门禁并发布新版，不能把上述本地测试当作完整 CI 通过。
