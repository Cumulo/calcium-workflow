{}
  :schema-version 1
  :feature 'sync-observability
  :doc "|Record low-overhead synchronization latency, patch/snapshot wire bytes, deterministic diff work, budget fallback, revision, resync, pending-client, and slow-client metrics."
  :roots $ #{} 'app.server/read-sync-metrics
  :definitions $ {}
    'app.server/SyncMetrics $ {}
      :mode :ensure
      :kind :data
      :doc "|Application-level synchronization latency, wire-byte, deterministic diff-work, budget-fallback, revision, resync, pending-client, and slow-client metrics; pending and slow fields are gauges refreshed on read."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct SyncMetrics (:last-diff-latency-ms 'Number) (:last-patch-bytes 'Number) (:last-snapshot-bytes 'Number) (:last-visited-nodes 'Number) (:last-emitted-ops 'Number) (:budget-fallback-count 'Number) (:pending-clients 'Number) (:slow-clients 'Number) (:resync-count 'Number) (:patch-attempts 'Number) (:snapshot-attempts 'Number) (:last-revision 'Number)
    'app.server/next-sync-metrics $ {}
      :mode :ensure
      :kind :fn
      :doc "|Purely advance synchronization counters for one attempted snapshot or patch send."
      :params $ [] 'metrics 'message-kind 'revision 'diff-latency 'payload 'stats 'budget-fallback?
      :schema $ :: 'Fn $ {}
        :args $ [] 'app.server/SyncMetrics 'Tag 'Number 'Number 'String 'recollect.diff/DiffStats 'Bool
        :return 'app.server/SyncMetrics
      :code $ quote
        defn next-sync-metrics (metrics message-kind revision diff-latency payload stats budget-fallback?)
          struct-with metrics (:last-diff-latency-ms diff-latency)
            :last-patch-bytes $ if (= message-kind :patch) payload.utf8-byte-count (:last-patch-bytes metrics)
            :last-snapshot-bytes $ if (= message-kind :snapshot) payload.utf8-byte-count (:last-snapshot-bytes metrics)
            :last-visited-nodes $ :visited-nodes stats
            :last-emitted-ops $ :emitted-ops stats
            :budget-fallback-count $ if
              and budget-fallback? $ not= revision (:last-revision metrics)
              inc $ :budget-fallback-count metrics
              :budget-fallback-count metrics
            :patch-attempts $ if (= message-kind :patch) (inc $ :patch-attempts metrics) (:patch-attempts metrics)
            :snapshot-attempts $ if (= message-kind :snapshot) (inc $ :snapshot-attempts metrics) (:snapshot-attempts metrics)
            :last-revision revision
    'app.server/record-sync-send! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Record metrics for one synchronization send attempt before transport admission."
      :params $ [] 'message-kind 'revision 'diff-latency 'payload 'stats 'budget-fallback?
      :schema $ :: 'Fn $ {}
        :args $ [] 'Tag 'Number 'Number 'String 'recollect.diff/DiffStats 'Bool
        :return 'Unit
      :code $ quote
        defn record-sync-send! (message-kind revision diff-latency payload stats budget-fallback?)
          swap! *sync-metrics $ fn (metrics) (next-sync-metrics metrics message-kind revision diff-latency payload stats budget-fallback?)
    'app.server/record-resync! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Count one explicit client request for a full synchronization snapshot."
      :params $ []
      :schema $ :: 'Fn $ {}
        :args $ []
        :return 'Unit
      :code $ quote
        defn record-resync! ()
          swap! *sync-metrics update :resync-count inc
    'app.server/read-sync-metrics $ {}
      :mode :ensure
      :kind :fn
      :doc "|Read counters plus pending and slow-client gauges computed from current connection state."
      :params $ []
      :schema $ :: 'Fn $ {}
        :args $ []
        :return 'app.server/SyncMetrics
      :code $ quote
        defn read-sync-metrics ()
          let
              states $ vals @*client-states
              pending-clients $ count $ filter states $ fn (state)
                option:unwrap-or (get state :in-flight?) false
              slow-clients $ count $ filter states $ fn (state)
                option:unwrap-or (get state :slow-client?) false
            merge @*sync-metrics $ {} (:pending-clients pending-clients) (:slow-clients slow-clients)
  :edges $ #{}
    :: :call 'app.server/record-sync-send! 'app.server/next-sync-metrics
