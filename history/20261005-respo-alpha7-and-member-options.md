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

## 验证范围

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
