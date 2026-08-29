# Typed pending sync state / 类型化待确认同步状态

- Replaced `nil` sent-revision and sent-store sentinels with absent map fields, cleared through `dissoc` on acknowledgement, disconnect, invalidation, and resume.
- 用缺失字段替代 `nil` 的发送 revision/store 哨兵，并在确认、断线、缓存失效与恢复时通过 `dissoc` 清理。
- Made `next-sync-send-state` generic over its state and payload while preserving the state type, and narrowed the runtime send path to `app.schema/Store`, numeric session ids, and `Unit` effects.
- 让 `next-sync-send-state` 以泛型保持输入输出状态类型关系，同时将运行时发送路径收窄为 `app.schema/Store`、数字会话 ID 与 `Unit` 副作用。
- Modelled an absent acknowledged twig cache with `Option` instead of introducing `nil` into `diff-twig` inputs.
- 使用 `Option` 表达已确认 twig cache 缺失，避免将 `nil` 混入 `diff-twig` 输入。
- The upgrade gate improved from the repository baseline: `typeNotFull` 53/56, `schemaDynamic` 108/112, `codeNil` 37/43, and unresolved weak positions 145/155.
- 升级守门指标优于仓库基线：`typeNotFull` 53/56、`schemaDynamic` 108/112、`codeNil` 37/43、未解析弱类型位置 145/155。
