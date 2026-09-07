# Address typed database review / 处理类型化数据库审查意见

## English

- Enforce persisted message map-key and nested `Message.id` consistency, with
  a path-aware negative fixture.
- Keep deep validation at the persistence boundary and make `reel-db` a
  zero-copy trusted adapter for the already typed reel slot, avoiding repeated
  whole-database decoding in synchronization hot paths.
- Correct the architecture graph so `get-shared-twig` is the caller that reads
  the reel database/count and invokes `twig-shared`.

## 中文

- 校验持久化消息的 Map key 与嵌套 `Message.id` 一致，并加入带路径错误的负例。
- 深度验证继续只发生在持久化边界；`reel-db` 改为零拷贝读取已经类型化的 reel
  slot，避免同步热路径反复解码整棵数据库。
- 修正架构调用图：由 `get-shared-twig` 读取 reel 数据库/记录数并调用
  `twig-shared`。
