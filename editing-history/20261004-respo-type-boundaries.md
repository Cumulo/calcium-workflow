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

## 第二阶段：Twig 的类型保留

用户查找直接匹配 `Map<String,User>` 的 get 结果，避免 if-let 展开出的 Option 回调擦除 UserView 类型。消息投影使用 `.filter-map-kv` 与 `MapEntryDecision :keep`，保持原 key 与 MessageView 字段，不再经异构 pair List 转换。回调声明 String/Message → MapEntryDecision<String,MessageView> 合同，两个编译器都能检查。两处旧的 Message/User 断言因此移除；没有扩大 Dynamic 或添加 coercion。

两个 SessionView 序列化测试继续比较完整值，并向普通 `parse-cirru-edn` 提供 Option 定义及 Struct prototype，以恢复名义身份。RouterView 仍含开放 Map，因此这里没有声称使用闭合递归 decoder，也不把身份恢复当作字段验证。

新增 missing-user-retains-session 回归：session 中保留 user-id，但数据库已无该用户时，投影保留 session 与 logged-in? 的既有行为，`:user` 为 Option :none。

验证结果：

- 正式 0.28.0 与候选 0.29.0-alpha.1：twig-container 的 4/4 附带测试均通过。
- 正式 0.28.0 生成 Twig JS，配套正式 procs 0.28.0 重放既有 `tests/session-option.mjs`（仅在临时副本调整生成目录）：缺失/存在 Option、nominal 数据库存储、非法字段拒绝和 EDN 往返均通过。
- 服务端入口全部 37 个附带测试：25 passed / 12 failed。相对第一阶段，原有三个 Twig 测试由失败转为通过，并新增一个通过测试。剩余 decoder、patch 泛型等问题仍待迁移，完整客户端入口也仍受 dispatch 可选参数阻断。

日志：`/private/tmp/calcium-194-twig-map-{formal,candidate}.log`、`/private/tmp/calcium-194-twig-js-replay.log`、`/private/tmp/calcium-194-twig-updated-server-tests.log`。该结果仍不满足 #194 的完整第二下游验收。

## 第三阶段：Patch 与协议能力边界

`patch-batch` 已返回实现 PatchBatchOps 的 nominal PatchBatch，validate-server-patch 移除旧 assert-traits 包装和对应 import。函数的泛型 T 输入/输出合同保留，未改成 Dynamic 或仅支持 Store。两个空 patch 测试为初始空 List 显式声明 change-op 元素类型。

decode-server-message 已检查 revision 类型、Store 的结构匹配，以及 patch List 中 change-op 的 nominal 定义。为其中原有 unsafe-coerce 声明词法 js-ffi 能力，没有增加转换或给调用方扩大权限。此步骤仅明确既有转换的边界：Store 结构匹配不证明所有嵌套字段有效，nominal change-op 身份也不等于任意动态 payload 已递归验证；更深的协议解码仍需继续推进。

同时发现依赖解析偏差：虽然 deps.cirru 声明 Recollect 0.0.45，原本忽略目录链接实际指向 0.0.38。已将该链接修正到现有 0.0.45 缓存 `b2aa7d7051ed79bdf9d546d71e281d899e6a5add`，没有编辑缓存源码。这解决了 DiffStats/DiffBudget 缺失。当前 JS-FFI 链接实际指向本地 main `605367e`，不再是第一阶段记录的 alpha.11 缓存；它仍是本地覆盖，不能声称声明的 alpha.11 pin 包含所有 main 修复。

验证结果：

- 正式 0.28.0：服务端入口全部 37/37 附带测试通过。
- 候选 0.29.0-alpha.1：33 passed / 4 failed。失败包括 Recollect patch helper 的泛型返回合同，以及数据库解码和服务端状态 helper 的返回合同；不将其当作通过。
- 正式生成 JS 配套正式 procs 0.28.0，`tests/client-patch.mjs` 通过：有效更新、非法第二条操作时原子拒绝且基线不变、revision mismatch、空 patch 保留 nominal Store。
- 最新完整客户端严格检查仍被旧 dispatch! 可选参数阻断，没有宣称实际 UI/浏览器全部验收通过。

日志：`/private/tmp/calcium-194-boundaries-{formal,candidate}-tests.log`、`/private/tmp/calcium-194-patch-js-replay.log`、`/private/tmp/calcium-194-latest-client-check.log`。

## 第四阶段：可选参数与连接地址适配器

dispatch! 的旧 `?` 尾参数改为 `Option<Dynamic>`，入口 unwrap-or nil 后保留原分支，包括旧 Tag 的 recur 路径。首参数仍为原 Op，未扩大其输入类型。静态 usages 显示应用登录以单个 nominal Op 调用；Respo 的 wrap-dispatch 也先归一化 cursor/Tag，再以单个 enum 转发。显式提供尾数据的调用方现在必须提供 `%some data`，省略参数由 Option omission sugar 处理。此步骤尚未证明 Fn<Op> 与 Respo Fn<Dynamic> 回调合同兼容，也未完成 dispatch 的运行回归，不能称为 #195 解决方案。

connect! 的地址读取抽为 connection-url：继续使用现有 url-parse 的 `true` 查询解析模式，对其已安装源码返回的 query 对象声明两个最小外部 trait（可空 String host/port），并复用 JS-FFI LocationHost。原来 5 次地址相关 unsafe-coerce 收敛为一次 parser 对象边界转换；query 属性读取有静态合同。恢复默认值使用 js-nullish->option，保留空字符串与第一项重复 query 的行为。request-snapshot! 与 send-activity! 按既有 ws-send! Unit 返回合同声明零参数 Fn<Unit>。

验证：

- connection-url 在正式与候选编译器下均严格通过，正式生成 JS。
- `tests/connection-url.mjs` 使用配套正式 procs 和原安装的 url-parse，对照旧表达式验证 7 个 query 场景；未启动 WebSocket。
- 正式编译器服务端入口的 37/37 附带测试仍通过。其范围不包括 dispatch! 的新参数运行回归。
- 完整客户端严格检查已越过旧可选参数和 URL 原始 JsObject 访问，当前停在 simulate-login! 的 localStorage 词法边界。后续仍需处理 callback 及 dispatch 合同。

日志：`/private/tmp/calcium-194-url-{formal,candidate}-check.log`、`/private/tmp/calcium-194-url-replay.log`、`/private/tmp/calcium-194-url-stage-native.log`、`/private/tmp/calcium-194-connection-adapter-check.log`。

## 第五阶段：登录存储与直接依赖核对

simulate-login! 的 raw getItem 访问移入 stored-login 小适配器，使用 StorageHost `.get-item` 和 `js-nullish->option`。String 内容在边界以 `parse-cirru-edn-as` 验证为 List<String>，返回 Option<List<String>>；业务调用仍使用原来的两项读取与 nominal 登录操作。移除原 raw String unsafe-coerce。存储缺失走原无凭据分支，宿主读异常仍向外抛出；非法 List 元素现在在解析边界更早拒绝，不宣称其异常时机完全不变，也没有把异常静默当作无凭据。

connect! 的单 String console.error 改用既有 console-error!；on-server-data 与 apply-server-patch! 中保留的多参数 console 诊断则显式声明自身词法 js-ffi 能力，保留其参数结构。

核对后发现多个直接依赖的忽略目录链接实际早于 deps.cirru 的声明。已仅修正当前迁移工作区的链接到匹配版本缓存，没有修改缓存或原工作区：

| 模块 | 修正后的声明版本 | 缓存源提交 |
| --- | --- | --- |
| cumulo-reel.calcit | 0.0.38 | 5940d2d37807c2eabb4c70c2d1e07e104e6a0edd |
| cumulo-util.calcit | 0.0.18 | 5fd2a5634a2f9fa920b99fea9ce0568f7864dd69 |
| alerts.calcit | 0.10.30 | 01288f07c1b04f59e4a0bf419770bcbde2a6f7f7 |
| respo-feather.calcit | 0.4.11 | 5a058551361d07a641d9d98b975472c9469a773f |
| respo-message.calcit | 0.0.20 | a1de3c42ceae416cfed2b0733249a786d564d88b |
| respo-ui.calcit | 0.7.19 | 112d52dee1c493be666d6dc6e843614de3873129 |
| ws-edn.calcit | 0.0.26 | 6f46ccce20565865d9a2016f076352204ff82052 |

calcit-wss 与 calcit.std 仍使用原 native realization；同版本存在多个候选缓存或 realization，尚未核实 ABI 与 tag 对应关系，因此没有任意替换。这一步也不证明所有传递依赖锁已正确。

当前验证：

- stored-login 在修正链接后的正式与候选编译器下独立严格检查通过。
- 正式生成 JS，`tests/stored-login.mjs` 配套正式 procs 通过：nil 缺失、正常/空 String 凭据、非法元素/容器拒绝、getItem 异常原样传播，读取的 key 为 calcium-storage；没有登录或连接网络。
- 修正七个直接依赖链接后，正式原生附带测试仍为 37/37 通过。
- 完整客户端检查现在报 cumulo-util.activity/watch-browser-lifecycle! 的 E_JS_FFI_FEATURE_REQUIRED（原始 js/setInterval）。匹配的 0.0.18 缓存函数没有 js-ffi feature，不能退回缺少生命周期 API 的旧缓存或给整个项目开放权限。

依赖问题的独立复现（不执行监听器或计时器）：

```bash
calcit --check-only --init-fn cumulo-util.activity/watch-browser-lifecycle! --reload-fn cumulo-util.activity/watch-browser-lifecycle!
```

对应 owner 为 Cumulo/cumulo-util.calcit；后续应在其源码工作区修正与验证，不能编辑缓存。日志为 `/private/tmp/calcium-194-lifecycle-pin-repro.log`、`/private/tmp/calcium-194-direct-pins-client-check.log`。登录检查与回归日志为 `/private/tmp/calcium-194-stored-login-aligned-{formal,candidate}.log`、`/private/tmp/calcium-194-stored-login-replay.log`，全部测试为 `/private/tmp/calcium-194-aligned-direct-native.log`。完整客户端和 dispatch 运行回归仍未完成。

## 第六阶段：完整客户端与 Respo 回归

核对 GitHub tags 后，发现 cumulo-util 已发布的 0.0.23（bf21934ab982bd667a1aae03b73bcba439d4ec33）包含 typed browser lifecycle 修复，升级依赖并复用其匹配缓存即可越过第五阶段的问题，无需修改缓存或再实现监听器。

ws-edn 升级声明至已发布的 0.0.32，但该发布仍有 WsClient → WsClient0 的断言冲突。实际迁移链接复用已有源码工作区 `ws-edn-client-traits-194` 的 ce23074：它检查布局后保留同一状态句柄，已有原生、generation/retry/heartbeat/lifecycle 验证记录。该提交仍是本地覆盖，不能声称 0.0.32 发布已经包含修复。

Calcium 的回调边界调整：

- render! 使用内部 dispatch-from-respo! 适配器：接收 Respo 已归一化的 Dynamic 操作，经现有 decode-operation 重建应用 Op，再调用原 dispatch!，只在这个适配器末尾返回 Unit。应用 dispatch! 的返回值仍保留；没有新增另一套 Respo 公共 dispatch API，也未修改全局 Respo Op 的身份规则。
- 旧 Tag 分支保留，通过同一 decoder 取得 Op 后，以显式 Option :none recur。非法操作现在在边界拒绝；这不是“任意旧非法 payload 行为不变”的承诺。
- *states 显式为 Ref<Map<Dynamic,Dynamic>>，符合实际异构状态树，避免初始空 cursor 将全部未来状态推为 List。update-states 的返回合同目前仍是 Dynamic，但实现始终 assoc 当前 Map；在这一调用点保留 Map 类型断言，未使用 unsafe-coerce，未改动状态树布局。
- 两组 watch 回调改为共享具名函数，分别声明 ClientState 和状态 Map 参数；仍只调用 render-app!。activity signal 回调末尾显式 Unit，符合生命周期合同，不改变可见/隐藏/心跳的发送分支。

验证结果：

- 正式 Calcit 0.28.0 的完整 main! / reload! 严格检查通过，零警告；实际完整客户端 JS 生成通过。
- 同一完整输出配套正式 procs 0.28.0，client-patch、stored-login、connection-url 三个既有迁移回归再次通过。
- 新增 `tests/respo-client-boundaries.mjs`：真实 Respo wrap-dispatch 转发旧双参数 cursor、Tag + nil；验证状态 payload、nominal wire 操作与非法操作拒绝。使用可控 socket factory，没有建立网络连接。
- 同一测试验证两次安装后只保留一组监听器和一个 30 秒心跳，hidden/visible 信号工作且 cleanup 清理监听器、interval 与 touch timeout。DOM 会忽略外层事件 listener 的返回值，visible 分支的库 touch cooldown 返回 timer handle 不作为应用 callback Unit 的断言。
- 对实际 comp-offline/comp-container 做 SSR，检查 loading/offline 文本、登录页四个控件标签，以及 comp-offline/comp-login 的组件身份。不是只比较输出长度，也不代表真实浏览器 DOM 交互全部通过。
- 正式服务端入口的附带测试仍为 37/37 通过。
- 候选完整客户端仍失败于 Recollect 的两个泛型返回合同（try-patch-get、try-patch-one-at）；不能宣称候选编译器通过。

生成与回放命令（临时目录已配置匹配 runtime 和原安装的 npm 依赖；loader 只补已知 Node ESM 扩展）：

```bash
calcit --emit-path /private/tmp/calcium-194-complete-client-js js
node --experimental-loader /Users/chenyong/repo/respo/respo-render-node-boundaries-194/test/downstream/resolve-diary-ssr-imports.mjs tests/respo-client-boundaries.mjs /private/tmp/calcium-194-complete-client-js
```

日志：`/private/tmp/calcium-194-complete-client-{formal,candidate}.log`、`/private/tmp/calcium-194-complete-client-js.log`、`/private/tmp/calcium-194-respo-client-replay.log`、`/private/tmp/calcium-194-full-js-{patch,login,url}.log`、`/private/tmp/calcium-194-lifecycle-dispatch-native.log`。#194 的完整发布依赖解析、真实浏览器回归与 issue/PR 交付仍未完成；这些本地结果不是整个 milestone 完成证明。
