# Respo alpha.7 与成员 Option 显示回归

## 发布依赖

基于当前 PR #60 的 `0e4f04d`，保留已收敛的客户端 `Op → Unit` 合同。
CLI/procs 更新为已发布 `0.29.0-alpha.6`，Respo 为 `0.16.114-alpha.7`，
JS-FFI 为 `0.2.1-alpha.13`，UI 为 `0.7.32-alpha.3`。其余模块保留已有发布
版本；Reel 仍消费 `0.0.47`，应用重放兼容入口保持不变。

实际 Caps 安装与 toolchain 核对十二个发布模块，npm runtime 不可变安装
通过；没有本地未发布源码覆盖。原生模块通过 Caps 对应实现加载。

## 源码迁移

按真实 query AST 定位十处 deprecated 调用，使用 CLI transaction、dry-run
和 revision 守卫修改五个定义：watch 名称增加 `!`、`some?` 改为
`non-nil?`、`vals` 改为同语义的 `distinct-values`，两处字面量
`case-default` 改为原 macro 的 `match` 展开。修改前后逐定义比较，原
schema、tests、examples、doc 与其他 metadata 保持不变。

## 实际浏览器发现并修复的问题

资料页把 `Option :some name` 直接传给文本节点，导致 Members 显示 Enum
格式。现复用 `decode-optional-string`，验证后取出名称；缺失名称显示空文本。
该 decoder 同时保留旧 String/nil 输入，损坏值拒绝进入文本显示。
不改变服务端投影、线协议、成员 Map、状态树或用户字段设计。

现有 JS/SSR 回归增加 present/absent Option、旧 String/nil 与错误 Number
场景。组件依赖浏览器样式，回归在原有 JS 测试入口执行；未修改原生测试
断言或删除既有测试。

## 保留门禁继续收敛 decoder 合同

后续基于 dca4d55，只把 `decode-store` 的受检输入和 `updater-from-reel`
的操作输入声明为独立量化 Input。具体 Store/Db 返回、嵌套字段解码、历史
记录的 sid/id/time 验证全部保持，运行代码和所有原 tests 不变。

六处初稿在类型检查通过后，被原client测试否定（33/41）：四个 Enum
decoder 的泛型输入导致非Enum值进入 match。已恢复这四处原schema，未改
断言或加入绕过。单定义 decode-operation 复现3/6，恢复原schema后6/6；
已报告 [Calcit #1779](https://github.com/calcit-lang/calcit/issues/1779)。根因尚未
定位，不声称已证明是某个内部优化。

最终两处修改：两入口严格检查、原client41/41、server52/52、重新生成JS的
原Session/Option、client patch、Respo/SSR/members、mount、stored-login、
connection URL、workload smoke及Node24/Vite8.0.5构建通过。canonical无修改。
原质量门禁40→34，schemaDynamic45→43、typeNotFull34→32、unresolved60→58；
unsafeCoerce仍2。原预算、CI、依赖和锁文件完全未改，没有新测试文件、脚本
或helper。严格Caps五组发布版本差异仍阻塞CI。未重跑完整浏览器UI、生产
服务或实际COS上传；旧浏览器记录仅对应dca4d55，不替代新head的全量验收。

## 验证范围

### Respo 入站适配器的量化输入

基于并行 e66dcd3 的实际发布 UI/Struct 修复，`dispatch-from-respo!` 输入
使用 `Fn<Input>(Input) → Unit`；整个运行代码不变，仍先调用原
`decode-operation`，只允许具体 `Op` 进入业务 dispatch。损坏值继续拒绝，
不会发布状态；没有再次尝试已报告 #1779 的 Enum decoder 泛型改写。

两入口严格检查、原client41/41、server53/53、freshJS、原Session/Option、
patch、Respo cursor/Tag/错误值拒绝/SSR/members、mount、storedlogin、URL、
workload smoke及Node24/Vite8.0.5构建通过；canonical/diff检查通过。
原质量34→31，schemaDynamic43→42、typeNotFull32→31、unresolved58→57，
unsafeCoerce仍2。baseline/预算/workflow/deps/package/lock/tests均未改；
没有新脚本/helper或额外测试。五组严格依赖冲突仍待上游发布，不宣称
完整CI或浏览器UI/COS上传通过，不合并或发版。

- client/server 严格入口与 `--warn-dyn-method` 检查通过。
- 原 client 标签 41/41、server 标签 52/52 全部通过。
- 重新生成 JS 的 Session/User Option、client patch、Respo cursor/dispatch、
  lifecycle、SSR、成员显示、mount、stored-login、七项 URL 兼容输入和
  diff/patch workload smoke 通过；Node 24 Vite 生产构建通过。
- 原生服务端与生产预览的真实浏览器连接、注册、资料/成员投影、重新连接
  后的存储登录与退出同步通过，error console 为空。
- 服务端最终从隔离 Snapshot 副本启动，数据库与备份按实际 dirname 规则
  写到临时目录。页面、预览与本任务的两个服务端进程均已停止；SIGINT
  退出码为 0。首次启动产生的空数据库和对应备份已核对后移到临时目录。
- 格式与 diff 检查通过，没有提交生成 JS、截图、数据库或 JSON。

## 剩余门禁

严格 Caps 实际拒绝五组传递版本差异：cumulo-util、UI、Respo、JS-FFI、
ws-edn。Reel/message/recollect 等已发布清单仍请求旧版本，需上游发布对齐。
保留 CI 的 `caps --strict --ci`，不改成普通下载绕过验收。

质量仍有 40 项逐定义回归，预算未提高，unsafeCoerce 为 2，deprecatedCalls
为 0。实际原生运行还出现既有 Struct 动态访问提示；入口静态通过并不证明
这些运行时提示已清零。完整 Actions、dispatch #195 与 milestone 整体验收
仍未完成。
