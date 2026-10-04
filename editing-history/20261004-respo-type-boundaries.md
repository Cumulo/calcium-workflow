# Respo 类型边界迁移：第一阶段，尚未完成

本地分支 `fix/respo-types-194` 从 Calcium `5de7a9b` 开始，用于 Respo #194 的第二个真实下游回归。当前结果不能作为完整下游通过证据。

## 已做修改

- 将 Calcit 与 `@calcit/procs` 对齐到正式 0.28.0，更新锁文件；增加显式 JS-FFI 0.2.1-alpha.11 依赖，并声明浏览器 target。
- 为 container、navigation、login、profile、status-color 与 ack-sync! 补充真实输入合同。UI 状态仍为异构 Map，profile 的 members 保持泛型 Map；未伪造封闭 dispatch 合同。
- navigation 的人数文本显式调用 `str`，满足 Respo 文本节点的 String 合同。
- 登录存储调用复用 StorageHost 的 `.set-item!`，配置中的存储键在 unwrap 后检查为 String。非法配置会增加类型检查，不能宣称所有异常行为完全不变。
- 将 mount-target 的直接宿主访问改为 query-mount-target，复用 JS-FFI 查询与 Respo 的 narrow-element。标准 DOM 找不到元素时仍返回 nil，找到时保持对象身份；JS-FFI 也将非标准 undefined 结果规范化为 nil。没有增加新的 unsafe-coerce。

Snapshot 修改均由 Calcit 0.28 CLI 完成；较大的文本差异包含 CLI 的规范序列化。

## 实际依赖范围

当前忽略目录 `.calcit/modules` 中，respo.calcit 指向本地 Respo 类型边界分支 `7644b19`，js-ffi 指向已解析的 alpha.11 模块缓存。其余模块沿用原解析缓存。Respo 的声明版本仍是 0.16.95；这些局部覆盖是迁移实验，并非依赖锁已完整升级的发布结果。

## 已验证

- navigation 的 public check：2/2，通过，无 diagnostics。
- query-mount-target 独立入口：正式 0.28.0 与候选 0.29.0-alpha.1 严格检查均通过。
- 正式 0.28.0 生成 JS，配套正式 `@calcit/procs` 0.28.0 执行 `tests/mount-boundary.mjs`：检查缺失元素、宿主对象身份、`.app` 选择器，以及模块导入时的初始化查询。测试提供最小 document/canvas 宿主替身，不代表真实浏览器集成测试。

独立 JS 编译命令（参数置于子命令之前）：

```bash
calcit --init-fn app.client/query-mount-target --reload-fn app.client/query-mount-target --emit-path /private/tmp/calcium-194-mount-js js
node tests/mount-boundary.mjs /private/tmp/calcium-194-mount-js
```

临时输出目录需要能解析匹配版本的 `@calcit/procs` 与模块自带 JS 文件；产物与依赖链接均未入库。

## 未通过与后续工作

- 完整客户端严格检查仍报 `E_LEGACY_OPTIONAL_PARAM`：dispatch! 的 `(op ? op-data)`。保留旧 Tag 调用的转换语义，后续结合 Respo #195 解决可选参数和 dispatch 输入合同。
- 默认入口的 36 个附带测试：14 passed / 22 failed。该入口不加载部分服务端模块，不能作为服务端回归命令。
- 使用 `--entry server` 执行相同测试：21 passed / 15 failed。仍有泛型 `.apply-to` 无法专门化、UserView 的 Option 回调合同，以及协议 decoder 中未隔离的 unsafe-coerce 等失败。测试命令没有启动 server/main!。
- 尚未完成完整客户端 JS、实际 UI SSR、浏览器及全部原生回归；不能将 Calcium 计入 #194 的第二个成功下游。

原始检查日志均保留在 `/private/tmp/calcium-194-*.log`，不将大 JSON 或生成 JS 纳入仓库。
