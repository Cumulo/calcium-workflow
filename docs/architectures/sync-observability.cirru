{}
  :schema-version 1
  :feature 'sync-observability
  :doc "|Record low-overhead synchronization latency, wire bytes, revision, resync, pending-client, and slow-client metrics."
  :roots $ #{} 'app.server/read-sync-metrics
  :definitions $ {}
    'app.server/SyncMetrics $ {}
      :mode :ensure
      :kind :data
      :doc "|Application-level synchronization metrics; pending and slow client fields are gauges refreshed on read."
      :schema $ :: 'Enum
      :code $ quote
        defstruct SyncMetrics (:last-diff-latency-ms 'Number) (:last-patch-bytes 'Number) (:pending-clients 'Number) (:slow-clients 'Number) (:resync-count 'Number) (:patch-attempts 'Number) (:snapshot-attempts 'Number) (:last-revision 'Number)
    'app.server/next-sync-metrics $ {}
      :mode :ensure
      :kind :fn
      :doc "|Purely advance synchronization counters for one attempted snapshot or patch send."
      :params $ [] 'metrics 'message-kind 'revision 'diff-latency 'payload
      :schema $ :: 'Fn $ {}
        :args $ [] 'app.server/SyncMetrics 'Tag 'Number 'Number 'String
        :return 'app.server/SyncMetrics
      :code $ quote
        defn next-sync-metrics (metrics message-kind revision diff-latency payload)
          merge metrics $ {}
            :last-diff-latency-ms diff-latency
            :last-patch-bytes $ if (= message-kind :patch) payload.utf8-byte-count (:last-patch-bytes metrics)
            :patch-attempts $ if (= message-kind :patch) (inc $ :patch-attempts metrics) (:patch-attempts metrics)
            :snapshot-attempts $ if (= message-kind :snapshot) (inc $ :snapshot-attempts metrics) (:snapshot-attempts metrics)
            :last-revision revision
    'app.server/record-sync-send! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Record metrics for one synchronization send attempt before transport admission."
      :params $ [] 'message-kind 'revision 'diff-latency 'payload
      :schema $ :: 'Fn $ {}
        :args $ [] 'Tag 'Number 'Number 'String
        :return 'Unit
      :code $ quote
        defn record-sync-send! (message-kind revision diff-latency payload)
          swap! *sync-metrics $ fn (metrics) (next-sync-metrics metrics message-kind revision diff-latency payload)
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
