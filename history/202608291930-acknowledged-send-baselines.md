# Acknowledgement-driven WebSocket send baselines

- Upgraded the template to Calcit 0.13.63 and current ecosystem modules,
  including calcit-wss 0.2.23.
- Treat `wss-send!` outcomes as flow control instead of assuming every enqueue
  succeeds.
- Keep the acknowledged store in `*client-caches` and retain an accepted
  pending store separately until its matching revision is acknowledged.
- Requeue backpressured clients from the acknowledged baseline, record slow
  client/outcome state, avoid oversized-payload busy loops, and clear pending
  stores on close, idle, resync, and cache invalidation.
- Added four unit tests for accepted, backpressured, too-large, and closed state
  transitions; both client and server entries preprocess without warnings.
