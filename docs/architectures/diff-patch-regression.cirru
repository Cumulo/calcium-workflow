{}
  :schema-version 1
  :feature 'diff-patch-regression
  :doc "|Build deterministic Calcium-shaped keyed workloads and expose one replay/projection/view path to native, generated-JavaScript, and browser correctness runners."
  :roots $ #{} 'app.client/workload-entry! 'app.workload.diff-patch/main! 'app.workload.diff-patch/make-workload-input 'app.workload.diff-patch/replay-domain-ops 'app.workload.diff-patch/project-state 'app.workload.diff-patch/workload-view
  :definitions $ {}
    'app.client/workload-entry! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Reachability adapter that includes the side-effect-free workload in the generated client module graph."
      :params $ []
      :schema $ :: 'Fn $ {}
        :args $ []
        :return 'Unit
    'app.workload.diff-patch/Entity $ {}
      :mode :ensure
      :kind :data
      :doc "|One deterministic keyed entity used by the workload."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct Entity (:id 'String) (:rank 'Number) (:label 'String)
    'app.workload.diff-patch/DomainOp $ {}
      :mode :ensure
      :kind :data
      :doc "|A replayable state transition covering no-op, leaf, insert, remove, reorder, and replacement cases."
      :schema $ :: 'EnumDef
      :code $ quote
        defenum DomainOp (:noop) (:set-label 'String 'String) (:insert 'Entity) (:remove 'String) (:reorder (:: 'List 'String)) (:replace (:: 'List 'Entity))
    'app.workload.diff-patch/WorkloadState $ {}
      :mode :ensure
      :kind :data
      :doc "|Server-side keyed entities plus their explicit presentation order."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct WorkloadState (:entities (:: 'Map 'String 'Entity)) (:order (:: 'List 'String))
    'app.workload.diff-patch/WorkloadInput $ {}
      :mode :ensure
      :kind :data
      :doc "|A fixed seed, base state, and deterministic DomainOp sequence."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct WorkloadInput (:seed 'Number) (:base 'WorkloadState) (:ops (:: 'List 'DomainOp))
    'app.workload.diff-patch/WorkloadStore $ {}
      :mode :ensure
      :kind :data
      :doc "|Client projection consumed by data diff and browser rendering."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct WorkloadStore (:rows (:: 'List 'Entity)) (:count 'Number)
    'app.workload.diff-patch/entity-id $ {}
      :mode :ensure
      :kind :fn
      :doc "|Derive a stable entity key from the fixed seed and index."
      :params $ [] 'seed 'index
      :schema $ :: 'Fn $ {}
        :args $ [] 'Number 'Number
        :return 'String
    'app.workload.diff-patch/make-entity $ {}
      :mode :ensure
      :kind :fn
      :doc "|Construct one deterministic typed entity."
      :params $ [] 'seed 'index
      :schema $ :: 'Fn $ {}
        :args $ [] 'Number 'Number
        :return 'Entity
    'app.workload.diff-patch/entities-by-id $ {}
      :mode :ensure
      :kind :fn
      :doc "|Index an entity list by its stable identifier."
      :params $ [] 'entities
      :schema $ :: 'Fn $ {}
        :args $ [] (:: 'List 'Entity)
        :return $ :: 'Map 'String 'Entity
    'app.workload.diff-patch/main! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Provide a side-effect-free entry for deterministic workload code generation."
      :params $ []
      :schema $ :: 'Fn $ {}
        :args $ []
        :return 'Unit
    'app.workload.diff-patch/make-workload-input $ {}
      :mode :ensure
      :kind :fn
      :doc "|Construct a deterministic workload of the requested size and seed."
      :params $ [] 'size 'seed
      :schema $ :: 'Fn $ {}
        :args $ [] 'Number 'Number
        :return 'WorkloadInput
    'app.workload.diff-patch/apply-domain-op $ {}
      :mode :ensure
      :kind :fn
      :doc "|Apply one DomainOp without mutating the previous WorkloadState."
      :params $ [] 'state 'op
      :schema $ :: 'Fn $ {}
        :args $ [] 'WorkloadState 'DomainOp
        :return 'WorkloadState
    'app.workload.diff-patch/replay-domain-ops $ {}
      :mode :ensure
      :kind :fn
      :doc "|Replay the same DomainOp sequence against a WorkloadState."
      :params $ [] 'state 'ops
      :schema $ :: 'Fn $ {}
        :args $ [] 'WorkloadState (:: 'List 'DomainOp)
        :return 'WorkloadState
    'app.workload.diff-patch/project-state $ {}
      :mode :ensure
      :kind :fn
      :doc "|Project ordered keyed entities into the client WorkloadStore."
      :params $ [] 'state
      :schema $ :: 'Fn $ {}
        :args $ [] 'WorkloadState
        :return 'WorkloadStore
    'app.workload.diff-patch/workload-view $ {}
      :mode :ensure
      :kind :fn
      :doc "|Render keyed rows plus stable focus and listener probes for browser checks."
      :params $ [] 'store
      :schema $ :: 'Fn $ {}
        :args $ [] 'WorkloadStore
        :return 'respo.schema/Element
    'app.workload.diff-patch/workload-ref! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Stable no-op ref callback used to detect unexpected ref churn at the browser FFI boundary."
      :params $ [] 'target
      :schema $ :: 'Fn $ {}
        :args $ [] 'respo.dom/DomElement
        :return 'Unit
        :features $ #{} :js-ffi
  :edges $ #{}
    :: :call 'app.client/workload-entry! 'app.workload.diff-patch/main!
    :: :call 'app.workload.diff-patch/make-entity 'app.workload.diff-patch/entity-id
    :: :call 'app.workload.diff-patch/make-workload-input 'app.workload.diff-patch/make-entity
    :: :call 'app.workload.diff-patch/make-workload-input 'app.workload.diff-patch/entities-by-id
    :: :call 'app.workload.diff-patch/replay-domain-ops 'app.workload.diff-patch/apply-domain-op
    :: :call 'app.workload.diff-patch/workload-view 'app.workload.diff-patch/workload-ref!
    :: :type 'app.workload.diff-patch/make-workload-input 'app.workload.diff-patch/WorkloadInput
    :: :type 'app.workload.diff-patch/project-state 'app.workload.diff-patch/WorkloadStore
