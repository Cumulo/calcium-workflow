{}
  :schema-version 1
  :feature 'budgeted-server-sync
  :doc "|Consume Recollect deterministic diff outcomes in Calcium, publishing only complete patches and atomically falling back to snapshots without changing ACK/backpressure ownership."
  :roots $ #{} 'app.server/sync-client! 'app.server/read-sync-metrics
  :definitions $ {}
    'app.server/SyncDiffPlan $ {}
      :mode :ensure
      :kind :data
      :doc "|Atomic server decision. Snapshot variants carry statistics and an optional budget reason but never partial changes."
      :schema $ :: 'EnumDef
      :code $ quote
        defenum SyncDiffPlan
          :snapshot 'recollect.diff/DiffStats (:: 'Option 'recollect.diff/DiffBudgetReason)
          :patch (:: 'List 'recollect.schema/change-op) 'recollect.diff/DiffStats
          :idle 'recollect.diff/DiffStats
    'app.server/sync-diff-visited-limit $ {}
      :mode :ensure
      :kind :data
      :doc "|Visited-node ceiling selected above the measured 10k workload maximum of 40002."
      :schema $ :: 'Number
      :code $ quote (def sync-diff-visited-limit 50000)
    'app.server/sync-diff-emitted-limit $ {}
      :mode :ensure
      :kind :data
      :doc "|Operation-construction ceiling selected above the measured 10k workload maximum of 70001."
      :schema $ :: 'Number
      :code $ quote (def sync-diff-emitted-limit 80000)
    'app.server/sync-diff-budget $ {}
      :mode :ensure
      :kind :data
      :doc "|Deterministic per-client diff budget; snapshot size and transport admission remain independent limits."
      :schema $ :: 'recollect.diff/DiffBudget
      :code $ quote
        def sync-diff-budget $ %{} DiffBudget
          :max-visited $ %some sync-diff-visited-limit
          :max-emitted $ %some sync-diff-emitted-limit
    'app.server/empty-diff-stats $ {}
      :mode :ensure
      :kind :data
      :doc "|Zero work statistics used when an existing recovery state already requires a snapshot and no diff runs."
      :schema $ :: 'recollect.diff/DiffStats
      :code $ quote
        def empty-diff-stats $ %{} DiffStats (:visited-nodes 0) (:emitted-ops 0)
    'app.server/select-sync-diff $ {}
      :mode :ensure
      :kind :fn
      :doc "|Convert one atomic Recollect outcome into patch, snapshot, or idle policy while retaining the existing top-level patch-operation limit."
      :params $ [] 'outcome
      :schema $ :: 'Fn
        {}
          :args $ [] 'recollect.diff/DiffOutcome
          :return 'app.server/SyncDiffPlan
    'app.server/sync-client! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'Number 'cumulo-reel.core/ReelState 'Number
          :return 'Unit
    'app.server/SyncMetrics $ {}
      :mode :external
      :kind :data
      :schema $ :: 'Enum
    'app.server/read-sync-metrics $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {} (:args $ []) (:return 'app.server/SyncMetrics)
  :edges $ #{}
    :: :call 'app.server/sync-diff-budget 'app.server/sync-diff-visited-limit
    :: :call 'app.server/sync-diff-budget 'app.server/sync-diff-emitted-limit
    :: :call 'app.server/sync-client! 'app.server/select-sync-diff
    :: :call 'app.server/sync-client! 'app.server/empty-diff-stats
    :: :type 'app.server/select-sync-diff 'app.server/SyncDiffPlan
