# 统一客户端生命周期所有权 / Unify client lifecycle ownership

## 中文

- 升级到 Calcit/@calcit-procs `0.13.68`、calcit.std `0.2.28` 与 cumulo-reel `0.0.33`，保持稳定 tag 依赖并消除 strict 依赖分歧。
- 明确 ws-edn 独占 transport reconnect、backoff、generation 与 receive deadline；删除 Calcium 重复的 page-touch reconnect 状态机和相关 JS FFI。
- 应用级 visible/hidden activity 与 30 秒 revision heartbeat 统一复用 cumulo-util `watch-browser-lifecycle!`，并把 cleanup 保存在 typed `Ref<Option<Fn>>` 中；main/hot reload 安装前先清理旧 listener/timer。
- 评估后不把通用 `Coalescer` 强行接入 server：当前 16ms fixed-window single timer 已有界、不会无限延迟，接入 planner 仍保留相同 timer 并增加 clock/state，没有可见的去重收益。
- 用新的 architecture 文件记录 ws-edn、cumulo-util 与 Calcium 的边界，删除已经失效的 manual recovery architecture。

## English

- Upgrade to Calcit/@calcit-procs `0.13.68`, calcit.std `0.2.28`, and cumulo-reel `0.0.33` using stable tags and remove the strict dependency divergence.
- Make ws-edn the exclusive owner of transport reconnect, backoff, generation, and receive deadlines; remove Calcium's duplicate page-touch reconnect state machine and its JS FFI.
- Reuse cumulo-util `watch-browser-lifecycle!` for application-level visible/hidden activity and a 30-second revision heartbeat. Store cleanup in a typed `Ref<Option<Fn>>`, and clean the previous listeners/timer before main or hot reload installs replacements.
- Deliberately do not force the generic `Coalescer` into the server: the existing 16ms fixed-window single timer is bounded and starvation-free, while the planner would retain that timer and add clock/state transitions without measurable deduplication.
- Record the ws-edn, cumulo-util, and Calcium boundary in a new architecture file and remove the obsolete manual-recovery architecture.
