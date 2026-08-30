# 修正文档中的旧生命周期说明 / Resolve stale lifecycle documentation

## 中文

- 根据 PR review 删除 README 中已经失效的 page-touch reconnect policy。
- 明确 ws-edn 独占 transport recovery，Calcium lifecycle watcher 只发送应用 activity 与 revision heartbeat。
- 移除容易过期的 Calcit 版本号，同时保留 `.utf8-byte-count` 能力说明。

## English

- Remove the obsolete page-touch reconnect policy from README after PR review.
- Clarify that ws-edn exclusively owns transport recovery while Calcium's lifecycle watcher only emits application activity and revision heartbeats.
- Remove the quickly stale Calcit version qualifier while retaining the `.utf8-byte-count` capability documentation.
