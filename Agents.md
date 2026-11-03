# Calcium 模板维护指南

本仓库是 Calcit 原生服务端与 Respo 浏览器端的实时应用模板。工具链精确版本以
`deps.cirru` 和 `package.json` 为准；CLI 与 `@calcit/procs` 必须配对。

## 先读当前合同

```sh
calcit --version
calcit docs agents --contract
calcit query config
calcit docs read Respo-Agent.md --full --module respo.calcit
```

遇到不熟悉的操作先查 live `--help`、`calcit docs` 和所属模块的 query 视图。
不用旧 `calcit libs`、`-p`/`-e`、`tree append-child` 或已删除的宏当作当前命令。
Snapshot 只通过官方 `query` / `tree` / `edit` / `config` 操作；先查真实节点，
多步写入先 transaction dry-run，再带返回的 scoped revision 应用。
不要直接读写或正则修改 `calcit.cirru`，不恢复 `compact.cirru` / `package.cirru`。

## 修改所属层

详见 `docs/template-layers.md`、`docs/hot-cold-sync-plan.md` 和既有
`tests/template-boundary.mjs`：

- `app.sync.*` 是模板同步运行时。业务应用不向其中加入 feature 分支；模板自身的
  运行时维护须保留原协议、生命周期和全部边界验收。
- `app.schema` 声明 Op/DomainOp、分区和 query/reply 合同；`app.hooks.client/server`
  是同步运行时调用业务逻辑的接线层。
- `app.client/server` 接线入口与根渲染；`app.comp.container` 接线页面。
- `app.twig.*`、`app.updater.{session,user,router}`、账户组件是基础脚手架。
- `app.feature.<name>.*` 放可替换业务逻辑，当前示例是 Kanban。

新增字段前先决定其范围：有界共享数据进入 shared hot partition；单用户实时数据
进入 private user partition；增长数据或按需加载内容进入 cold store/query；每标签页
UI/路由数据留在 session Store。授权来自 session，不从 query 参数取得身份。
操作可能改变的分区列入 `affected-partitions`，访问范围由 `session-partitions` 决定。

## 代码合同

- Updater 是纯函数，返回新 Db；I/O、日志、WebSocket 与持久化放在外层派发/同步。
- Twig 必须在服务端过滤会话可见数据，绝不广播所有私有数据或密码字段。优先显式
  投影公开字段；不要依赖浏览器过滤来保护数据。
- 线输入、旧存档经现有 decoder 校验并重建本地名义值。名称/字段相同不代表定义身份，
  class mapper 也不替代字段校验。保留受检 wire 恢复与错误顺序。
- DOM handler 使用 RespoEvent 和单个具名 Op 派发，不能继续 `d! cursor state`。
  读取文本优先复用 Respo 的受检 `event-value`；事件 raw Dynamic 不是已验证 String。
  需要返回 Unit 的副作用回调明确丢弃分支返回值。
- 根组件构建与实际渲染同处 managed memo frame；数据 key 不因 CoordKey 的渲染边界
  而被强行收窄。spacer 使用 `space-x` / `space-y`，保持原宽高。
- UI 使用 Respo memo；服务端纯投影使用 Recollect 的 typed twig memo helper。
  服务端在完整 dirty-client pass 外管理 twig frame，feature 不另开嵌套帧。
  不重新加入通用 memof，不为协议/revision cache 隐藏生命周期。
- 优先真实 Struct/Enum/union/generic 合同。开放 payload、存档和异构状态在真实入口
  保留受检边界，不用假泛型、有限 union、assert-type 或 unsafe 冒充业务证明。
- 保留 `hud!` 的页面错误展示，不改为 raise；原后端监听、服务目录与前端部署路径保持。

## 原门禁必须保留

原工作流 `.github/workflows/upload.yaml` 是完整入口，不能仅凭 check-only 或历史数字
声称完成迁移。安装使用 Caps strict/toolchain 和 Yarn immutable；未发布候选链接
必须明确标识，其通过不能冒充正式根依赖图已解析。npm 安装隔离期保持一小时。

```sh
caps --strict --ci
yarn install --immutable
caps verify --toolchain
calcit --check-only
calcit --entry server --check-only
calcit fix --workflow strict --verify
calcit test --tag client --require-match
calcit --entry server test --require-match
yarn check-types
yarn compile-page
yarn release-page
```

还须按原 CI 执行：双入口 dynamic-method/deprecated 零诊断、完整 strict 空 diagnostics
且无 unsafe-coerce findings、session Option 投影、五组客户端/挂载/存档/URL 边界、
模板分层检查、diff/patch smoke 和原生 Kanban E2E。JS 检查须在对应源码生成完成后运行。
本地原生 E2E 使用既有回环/独立数据隔离流程，不把配置断言当作实际监听验收。
涉及 UI 更新时保留真实浏览器的 identity/listener/focus/selection/no-op 验收。

迁移不新增项目级 checker 或永久改写脚本，不放宽预算或跳过原测试。
COS 仅上传 dist，沿用 action 内置 verify 和独立 PR 预览前缀；不把后端源码混入 COS。
发现上游问题先核对真实 owner、版本和既有 issue，再补充最小事实与消费者证据，
优先完善现有门禁和提示，不为各项目增加编译器专用 fix/proof 规则。
