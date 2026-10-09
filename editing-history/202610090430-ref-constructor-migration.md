# Ref 构造器迁移与 Calcit 0.29.0-alpha.19

## 版本对齐

- Calcit、`@calcit/procs` 与 CI 的 setup-calcit 固定到 0.29.0-alpha.19（caps 0.1.1），与 Respo/respo.calcit main 一致。
- respo 升到 0.16.114-alpha.9，js-ffi 升到 0.2.1-alpha.15；`caps --strict` 要求传递依赖版本一致，因此同步升级 cumulo-reel 0.0.51、cumulo-util 0.0.26、respo-message 0.0.31、respo-ui 0.7.32-alpha.6、recollect 0.0.57、ws-edn 0.0.36。

## 升级带来的最小修复

- alpha.19 要求调用参数有类型证明：Respo 组件的 cursor、草稿、登录状态与 `:dirty-rev` 用 `decode-map-as` 收窄。
- `refresh-domain-reel` 返回 `ReelState<Db>`，满足 `reset! *reel` 的类型检查。
- Respo alpha.9 要求 states key 为 Tag，看板列与卡片详情用 `turn-tag`。
- 运行时 Struct 字段写入开始检查类型：原先用 `&struct:assoc` 构造损坏 Struct 的测试，改为断言写入被拒绝，或以 EDN 文本构造损坏输入继续测试解码器。
- stored-login 测试中的 localStorage 替身补齐 StorageHost 形状。

## Ref 迁移

- 运行 `calcit fix --rule core-ref-constructor-v1 --include-attached`：26 处 `defatom` 改为 `defref`，1 处附带测试的 `atom` 改为 `ref`；重新预览为 `:changed false`。
- 未出现 `fn -> :unit` 回调返回 `swap!` 结果的告警，无需额外回调修复。
- Agents.md 与 docs 中的 atom/defatom 措辞改为 ref/defref；history 与 editing-history 中的历史记录保持原样。
