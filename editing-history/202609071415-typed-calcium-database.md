# Type the Calcium database workflow / 为 Calcium 数据库工作流补齐类型

## English

- Replace the open database maps with nominal `Db`, `Session`, `User`,
  `Router`, and `Message` structs, plus concrete `RemoveMessage` and
  `DomainOp` contracts.
- Deeply decode legacy persisted maps and nominal structs through path-aware
  `Result` values, including malformed EDN and corrupt nested-value coverage.
- Keep domain updates pure and typed from `Db` to `Db`; route local effects
  outside the reducer and make the server's storage and reel boundaries
  explicit.
- Type the shared/session projections and update the JavaScript Option
  regression to enter through the same database decoder used in production.
- Validation used Calcit `0.13.78-rc.1`: client/server checks passed; 12 client,
  20 server, and 32 full server-entry tests passed; dynamic-method and
  deprecated-API gates passed; the unchanged quality baseline passed with
  lower `typeNotFull`, `schemaDynamic`, `codeNil`, `unresolved`, and
  `unsafeCoerce` counts.
- The #794 end-to-end smoke workload passed all patch/revision recovery
  oracles with report hash
  `cf9530b7fa305dfa4b3614069798c806dc9b0b25fa985a6133fb71dae123c06e`.

## 中文

- 将开放的数据库 Map 替换为名义化的 `Db`、`Session`、`User`、`Router`、
  `Message` struct，并为 `RemoveMessage` 与 `DomainOp` 建立具体契约。
- 通过带路径信息的 `Result` 深度解码旧版持久化 Map 与名义 struct，覆盖损坏
  EDN 以及嵌套脏数据。
- 保持领域更新器为纯函数且类型为 `Db -> Db`；将本地 effect 移出 reducer，
  并显式命名服务端存储与 reel 边界。
- 为共享/会话投影补齐类型，并让 JavaScript Option 回归通过生产所用的数据库
  解码器进入。
- 使用 Calcit `0.13.78-rc.1` 验证：client/server 检查通过；client 12 项、
  server 20 项、server 入口全量 32 项测试通过；动态方法与废弃 API 门禁通过；
  未修改质量基线且检查通过，`typeNotFull`、`schemaDynamic`、`codeNil`、
  `unresolved`、`unsafeCoerce` 均下降。
- #794 端到端 smoke workload 的 patch/revision 恢复断言全部通过，报告 hash 为
  `cf9530b7fa305dfa4b3614069798c806dc9b0b25fa985a6133fb71dae123c06e`。
