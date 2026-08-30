# ws-edn heartbeat and revision resync / ws-edn 心跳与 revision 重同步

## 中文

- 完整 16-module graph 对齐最新稳定 tags，包括 cumulo-reel `0.0.31`、cumulo-util `0.0.14`、ws-edn `0.0.22`、recollect `0.0.40` 与 calcit-wss `0.2.24`。
- ws-edn 统一管理 visibility/online recovery、generation、bounded backoff 与 75 秒 heartbeat deadline；Calcium 删除重复的 reconnect listener，保留 page-touch 手动加速。
- 服务端对 30 秒 typed heartbeat 返回 typed pong，使健康静默连接续租；超时连接主动关闭后，每次 open 仍先执行 revision resume。

## English

- Align the complete 16-module graph to current stable tags, including cumulo-reel `0.0.31`, cumulo-util `0.0.14`, ws-edn `0.0.22`, recollect `0.0.40`, and calcit-wss `0.2.24`.
- Let ws-edn exclusively own visibility/online recovery, generation, bounded backoff, and the 75-second heartbeat deadline; remove duplicate Calcium reconnect listeners while retaining manual page-touch acceleration.
- Reply to the 30-second typed heartbeat with a typed pong so healthy silent connections renew; after timeout recovery, every open still performs revision resume first.
