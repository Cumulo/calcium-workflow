# 2026-10-07 升级到 Calcit 0.29.0-alpha.16

- Calcit CLI 与 `@calcit/procs` 升级到 `0.29.0-alpha.16`。
- 依赖：cumulo-reel `0.0.50`、respo-message `0.0.30`、Respo `0.16.114-alpha.8`、Respo UI `0.7.32-alpha.5`、
  Recollect `0.0.56`、calcit-wss `0.2.33`、calcit.std `0.2.37`；cumulo-util `0.0.25`、ws-edn `0.0.35`、
  JS-FFI `0.2.1-alpha.13` 不变。之前阻塞升级的 `caps --strict` 冲突，只需要 respo-message 和
  cumulo-reel 两个模块发版即可解决（两者都统一到 Respo alpha.8 / UI alpha.5 / Recollect 0.0.56）。
- alpha.16 检查声明为 Unit 的函数实际返回值：`app.sync.client/connect!`、`app.sync.server/record-sync-send!`、
  `mark-client-idle!`、`record-resync!` 以 `reset!`/`swap!`/`when` 结尾，改为显式以 `&unit` 结尾。
- 验证：两端 check-only、dynamic-methods/deprecated 检查、两端原生测试（44/68）、check-types、模板边界、
  生成 JS 测试、原生服务端 e2e 和双用户浏览器走查均通过。
