# 发布依赖组合与 Reel 重放兼容

## 依赖

将直接依赖更新到实际已发布版本：cumulo-reel `0.0.47`、cumulo-util
`0.0.24`、respo-message `0.0.28`、respo-ui `0.7.31`、Respo
`0.16.114-alpha.6`、ws-edn `0.0.33`。保留 JS-FFI
`0.2.1-alpha.11`、recollect `0.0.53` 和正式 Calcit / procs `0.28.0`。
删除没有出现在两入口源码、测试或当前文档示例中的 alerts 与 respo-feather
直接依赖；不修改共享缓存或已发布标签。

Caps 的真实发布图已在隔离目录安装，项目使用对应不可变发布缓存，
`caps verify --toolchain` 验证 12 个模块。此前的本地 Respo、Reel 和 ws-edn
开发分支覆盖不再用于本轮验收。

## 重放

实际执行发现 cumulo-reel `0.0.47` 的 `refresh-reel` 仍使用旧 Map 字段访问，
传入 ReelState Struct 时抛出 `expected a hashmap`。新增应用兼容入口
`refresh-domain-reel`，使用 Struct 字段读取、现有数据库 decoder、上游
`play-records` 和 `struct-with`。不复制记录重放实现，不改变记录顺序、
reset/merge 语义或 callback 参数。

生产 reload 和原五项重放测试改用此入口，保留原测试名称、tags 与断言。
新增两项测试：拒绝损坏的 merged base；未 merge 时使用新的合法 base，
忽略旧 base 并保留 records/merged 字段。

状态 watcher 的两个参数未被读取，合同改为独立泛型参数，仍返回 Unit。
服务端异构 Map 更新保持真实开放合同；泛型候选被原有异构数据测试否定，
没有纳入提交。外部数据 decoder 的 Dynamic 边界保留。

## 验证

- 正式 0.28 两入口严格预处理通过。
- client 标签 41/41；server 标签 52/52，包括原重放回归与两个新负边界测试。
- 真实发布依赖生成的 JS：Session/User Option、client patch、Respo cursor/dispatch、
  mount、stored login、connection URL、diff/patch workload smoke 均通过。
- Node 24 下 Vite 生产构建通过，Snapshot 格式与 diff 检查通过。
- 未提交生成 JS、测试输出或 JSON 大文件。

## 尚未通过的门禁

`caps --strict --ci` 仍拒绝四组传递依赖差异：

| 模块 | 选择版本 | 上游仍请求 |
| --- | --- | --- |
| cumulo-util | 0.0.24 | Reel 请求 0.0.23 |
| Respo | 0.16.114-alpha.6 | Reel、message、router、ui、value、recollect 请求 0.16.113 |
| JS-FFI | 0.2.1-alpha.11 | Reel、message、ui、recollect 请求 0.1.36 |
| ws-edn | 0.0.33 | Reel 请求 0.0.32 |

逐定义质量门禁仍有 40 项回归，原为 45 项。预算未提高，unsafeCoerce
保持 2。开放 decoder、异构状态和宿主边界尚需继续逐项处理；不以总量降低
替代逐定义验收。CI 保留原严格依赖解析与质量门禁，本轮不宣称完整 CI 已通过。

## 客户端 dispatch 收敛

查询实际调用点后，客户端 `dispatch!` 收敛为单参数 `Op → Unit`。
旧 Tag、未受信任 enum 与 Respo callback 仍由原有 `dispatch-from-respo!`
和 `decode-operation` 处理；内部入口删除已无调用者的第二参数、nil 默认值
与重复 legacy decoder。保留 states 更新、connect 与 WebSocket 消息分支，
日志直接输出完整 nominal Op，不再从废弃参数取 payload。

没有增加 helper、验证脚本、测试或放宽 baseline。客户端严格入口、原 client
41 项测试、原 Respo cursor/Tag dispatch 与 SSR 回归、stored-login、mount、
connection URL 回归及 Node 24 Vite 构建通过。质量回归由 42 降为 40；
`schemaDynamic` 47→45、`typeNotFull` 35→34、`codeNil` 16→15、
`unresolved` 63→60。严格依赖图的四组冲突仍待上游发布版本对齐，PR 保持 draft。
