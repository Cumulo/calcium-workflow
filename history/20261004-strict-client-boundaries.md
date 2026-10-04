# Calcium 类型边界迁移：严格入口与补丁解码

这轮工作对应 Respo 0.19.0 milestone 的 #194 下游回归。尚未完成正式依赖发布及全部质量门禁。

## 源码变更

- 开发、构建和 CI 移除 `--compat-types`，使用默认严格检查。
- 将 136 处旧 Option/Result 构造调用迁移到具名构造器，废弃调用降为 0。
- 原有 67 项附属测试的名称和标签集合保持一致，累计新增 14 项测试。
- `enum-definition-matches?` 先解开 Option，再比较 EnumDef，保留原来的定义相等语义。
- 服务端补丁解码先验证 change-op 定义，再通过 `try-decode-map-as` 验证完整参数。错误数量参数、递归操作中的错误参数及非 Enum 元素返回错误结果。删除该入口的两处 `unsafe-coerce`。
- 客户端源码显式导入 `calcit.build-errors.mjs`，满足 Node ESM 路径要求。
- CI 增加补丁原子发布、旧 cursor/Tag 分派、生命周期清理、挂载节点、存储登录及连接 URL 回归。
- `Op :states` 的 cursor 改为 `List Dynamic`，保留 Tag、String、Number 路径键及开放状态值。解码器拒绝非列表 cursor；混合路径经过真实 Respo 分派和状态更新回归。
- 客户端消息及操作解码器先判断 Enum，非 Enum 外层值和 dispatch payload 返回 `Result :err`，不再在 match 中抛错。
- 十处已知 Db/Entity 更新使用 `struct-with`，保持原来字段、名义类型及不可变更新语义，避免通用 `.assoc` 分派。相同 81 项 native 测试日志中的动态分派警告由 24 条降至 11 条；仍有测试及依赖告警。
- 修复 CI 中不受支持的 `dynamic-methods --max` 参数，改为 JSON 汇总与 jq 验证，保持原先阈值 1。

Node 测试入口只为 bottom-tip 0.1.5 的 `virtual-dom/create-element` 导入补充 `.js`。仍执行真实 bottom-tip/virtual-dom 代码，不替换客户端或依赖实现；生产 Vite 构建继续使用其自身解析。

## 本地验证

| 验证 | 结果 |
| --- | --- |
| Calcit 0.28.0 客户端与服务端严格检查 | 通过 |
| Calcit 0.28.0 全部原生附属测试 | 81/81 |
| 候选 0.29.0-alpha.1 全部原生附属测试 | 81/81 |
| 客户端/服务端项目动态方法静态汇总 | 两个入口均为 0，CI jq 门禁通过 |
| 正式编译器新生成 JS 的五组客户端回归 | 通过 |
| Node 24 + Vite 8 生产构建 | 通过 |
| 确定性 diff/patch workload smoke | 通过，包含 EDN 往返与错误基线收敛反例 |
| 项目废弃调用 | 0 |
| 项目 unsafe-coerce | 2，原预算 15 |
| 原质量基线 | 失败：45 项逐定义回归，未放宽预算 |

workload 原先调用旧 `patch-twig`，在 Struct 更新时失败。现在使用生产客户端同一验证 API `try-patch-twig`，显式断言成功结果，并为 EDN 解析传入类型映射。0.28 parser 的 Struct 映射要求代表值，因此取实际 workload 初始 store 和 Entity；保留编码、解码、收敛及错误基线反例检查。

严格入口与 JS 回归依赖本地迁移模块覆盖。它们证明当前源码组合的行为，不证明 `caps --strict --ci` 能从现有发布版本重建该组合。

## 依赖与剩余工作

js-ffi main 在本轮同步后变为 `08cf9e0`，要求 Calcit 0.29.0-alpha.2，并使用新版字面量 match。Calcium 的本地忽略目录链接固定到同步前的 `762d5ee`，避免正式 0.28 回归随 main 漂移。该提交的清单也声明 alpha.1，因此这里的 0.28 结果属于已验证源码兼容组合，不能称为匹配清单的正式依赖版本。

Respo 本地覆盖使用类型边界分支；ws-edn、Cumulo Reel 等也包含尚未发布的迁移。旧依赖中仍有不在严格入口可达路径上的废弃 API 警告。正式交付需要发布并固定适配的依赖版本，然后重跑完整 CI。

质量回归主要包括开放 state、Respo dispatch 适配器、状态监听和服务端同步适配器。下一步继续核实真实边界，减少不必要的 Dynamic/转换；不能通过提高基线或给开放输入加虚假泛型来消除记录。
