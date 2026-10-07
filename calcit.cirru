
{}
  :about "|Machine-generated snapshot. Do not edit directly — changes will be overwritten. Use `calcit query` to inspect and `calcit edit`/`calcit tree` to modify. Run `calcit docs agents --contract` before mutations; use `--full` for first orientation or changed contract digest. Manual edits must follow format and schema conventions, then run `calcit edit format`."
  :package |app
  :entries $ {}
    :default $ {} (:description |) (:init-fn 'app.client/main!) (:mode :js) (:reload-fn 'app.client/reload!) (:target :browser)
      :feature-policy $ {}
      :modules $ [] |respo.calcit/ |recollect/ |respo-ui.calcit/ |ws-edn.calcit/ |cumulo-util.calcit/ |respo-message.calcit/ |cumulo-reel.calcit/ |js-ffi/
      :type-slots $ {} $ :dispatch-op |app.schema/Op
    :server $ {} (:description |) (:init-fn 'app.server/main!) (:mode :native) (:reload-fn 'app.server/reload!) (:target :native)
      :feature-policy $ {}
      :modules $ [] |recollect/ |ws-edn.calcit/ |cumulo-util.calcit/ |cumulo-reel.calcit/ |calcit-wss/ |calcit.std/
      :type-slots $ {} $ :dispatch-op |app.schema/Op
  :files $ {}
    'app.client $ %{} 'FileEntry
      :defs $ {}
        '*activity-cleanup $ %{} 'CodeEntry
          :doc "|Cleanup capability for Calcium application-level browser activity signals."
          :code $ quote $ defatom *activity-cleanup (Option :none)
          :examples $ []
          :schema $ :: 'Ref $ :: 'Option 'Fn
        '*connected? $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *connected? false
          :examples $ []
          :schema $ :: 'Dynamic
        '*partitions $ %{} 'CodeEntry
          :doc "|Validated partition caches keyed by partition; each slot is replaced only by a complete snapshot or atomic delta chain."
          :code $ quote $ defatom *partitions
            assert-type ({}) (:: 'Map 'app.schema/PartitionKey 'app.partition/PartitionSlot)
          :examples $ []
          :schema $ :: 'Ref $ :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionSlot
        '*resources $ %{} 'CodeEntry
          :doc "|Cold callback cache: fetched history pages and open card details."
          :code $ quote $ defatom *resources resource/empty-resources
          :examples $ []
          :schema $ :: 'Ref 'app.resource/Resources
        '*states $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *states
            {} $ :states $ {}
              :cursor $ []
          :examples $ []
          :schema $ :: 'Ref $ :: 'Map 'Tag 'Dynamic
        '*store $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *store (ClientState :loading)
          :examples $ []
          :schema $ :: 'Ref 'app.client/ClientState
        '*sync-revision $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *sync-revision 0
          :examples $ []
          :schema $ :: 'Dynamic
        '*ws-client $ %{} 'CodeEntry
          :doc "|Current nominal ws-edn client, retained across browser recovery events."
          :code $ quote $ defatom *ws-client (Option :none)
          :examples $ []
          :schema $ :: 'Ref $ :: 'Option 'ws-edn.client/WsClient
        'ClientPatchError $ %{} 'CodeEntry
          :doc "|Client-side reason for rejecting a revisioned patch before requesting a full snapshot."
          :code $ quote $ defenum ClientPatchError (:revision-mismatch 'Number 'Number) (:invalid-patch 'recollect.patch/PatchError) (:invalid-result 'String)
          :examples $ []
          :schema $ :: 'EnumDef
        'ClientState $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defenum ClientState (:loading) (:offline) (:ready 'app.schema/Store)
          :examples $ []
          :schema $ :: 'EnumDef
        'ConnectionQueryHost $ %{} 'CodeEntry (:doc |)
          :code $ quote $ deftrait ConnectionQueryHost
            :host $ :: 'JsNullish 'String
            :port $ :: 'JsNullish 'String
          :examples $ []
          :ffi $ {} (:backend :js) (:kind :external-object) (:target :browser)
          :schema $ :: 'Trait
        'ParsedConnectionHost $ %{} 'CodeEntry (:doc |)
          :code $ quote $ deftrait ParsedConnectionHost (:query 'app.client/ConnectionQueryHost)
          :examples $ []
          :ffi $ {} (:backend :js) (:kind :external-object) (:target :browser)
          :schema $ :: 'Trait
        'ack-sync! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn ack-sync! (revision)
            ws-send! $ %:: schema/ClientMessage :sync/ack revision
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number
            :features $ #{} :js-ffi
        'apply-partition-message! $ %{} 'CodeEntry
          :doc "|Apply partition envelopes: snapshots replace the slot, delta chains apply atomically or trigger a partition resync, drops clear caches (dropping the user partition clears private cold data)."
          :code $ quote $ defn apply-partition-message! (message)
            match message
              (:part/snapshot key epoch revision view)
                do
                  swap! *partitions assoc key $ %{} PartitionSlot (:epoch epoch) (:revision revision) (:view view)
                  ws-send! $ schema/ClientMessage :part/ack key epoch revision
                  refresh-stale-details! key
              (:part/patch key epoch deltas)
                match (get @*partitions key)
                  (:none)
                    ws-send! $ schema/ClientMessage :part/resync key
                  (:some slot)
                    match (apply-partition-deltas slot epoch deltas)
                      (:ok next-slot)
                        do (swap! *partitions assoc key next-slot)
                          ws-send! $ schema/ClientMessage :part/ack key epoch $ :revision next-slot
                          refresh-stale-details! key
                      (:err detail)
                        do
                          js/console.warn |Partition-resync (str key) detail
                          swap! *partitions dissoc key
                          ws-send! $ schema/ClientMessage :part/resync key
              (:part/drop key)
                do (swap! *partitions dissoc key)
                  match key
                    (:user _user-id) (reset! *resources resource/empty-resources)
                    _ &unit
              _ &unit
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.schema/ServerMessage
            :features $ #{} :js-ffi
        'apply-server-patch! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn apply-server-patch! (base-revision revision changes)
            match @*store
              (:ready store)
                match (validate-server-patch store @*sync-revision base-revision changes schema/decode-store)
                  (:ok next-store)
                    do
                      reset! *store $ ClientState :ready next-store
                      reset! *sync-revision revision
                      ack-sync! revision
                  (:err error)
                    do
                      match error
                        (:revision-mismatch expected actual) (js/console.warn |Sync-revision-mismatch expected actual)
                        (:invalid-patch patch-error)
                          js/console.error |Failed-to-apply-server-patch $ patch-error-message patch-error
                        (:invalid-result detail) (js/console.error |Invalid-patched-store detail)
                      request-snapshot!
              (:loading) (request-snapshot!)
              (:offline) (request-snapshot!)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'Number $ :: 'List 'recollect.schema/change-op
            :features $ #{} :js-ffi
        'cleanup-activity-lifecycle! $ %{} 'CodeEntry
          :doc "|Run and clear the current application activity cleanup capability."
          :code $ quote $ defn cleanup-activity-lifecycle! ()
            do
              match @*activity-cleanup
                (:some cleanup) (cleanup)
                (:none) &unit
              reset! *activity-cleanup $ Option :none
              , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'connect! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn connect! ()
            let
                url $ connection-url
              reset! *store $ ClientState :loading
              reset! *ws-client $ Option :some $ ws-connect! url
                {}
                  :on-open $ fn (event)
                    do (reset! *connected? true) (request-snapshot!) (send-activity!) (simulate-login!)
                  :on-close $ fn (event) (reset! *connected? false)
                    reset! *store $ ClientState :offline
                    console-error! "|Lost connection!"
                  :on-data on-server-data
                  :heartbeat-timeout-ms 75000
                  :class-mapper $ {} (:Option Option) (:Store schema/Store) (:SessionView schema/SessionView) (:RouterView schema/RouterView) (:AttachedView schema/AttachedView) (:UserView schema/UserView) (:MessageView schema/MessageView) (:ServerMessage schema/ServerMessage) (:change-op patch-schema/change-op) (:CardDetail schema/CardDetail) (:HistoryEvent schema/HistoryEvent) (:HistoryPage schema/HistoryPage) (:QueryReply schema/QueryReply) (:UserSettings schema/UserSettings) (:UserHotView schema/UserHotView) (:Card schema/Card) (:Column schema/Column) (:Board schema/Board) (:BoardBrief schema/BoardBrief) (:LobbyView schema/LobbyView) (:PartitionDelta schema/PartitionDelta) (:PartitionView schema/PartitionView) (:PartitionKey schema/PartitionKey)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'connection-url $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn connection-url ()
            let
                location $ browser/location-host
                parsed $ unsafe-coerce
                  url-parse (location :href) true
                  , 'app.client/ParsedConnectionHost
                query $ parsed :query
                host $ option:unwrap-or
                  js-nullish->option $ query :host
                  location :hostname
                port $ option:unwrap-or
                  js-nullish->option $ query :port
                  str $ option:unwrap $ get config/site :port
              str |ws:// host |: port
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ []
            :features $ #{} :js-ffi
        'dispatch! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn dispatch! (op)
            when
              and config/dev? $ match op
                (:states _ _) false
                _ true
              println |Dispatch op
            match op
              (:states cursor s)
                reset! *states $ assert-type (update-states @*states cursor s) (:: 'Map 'Tag 'Dynamic)
              (:effect/connect) (connect!)
              (:client/load-history append?)
                send-query! $ resource/begin-history-query @*resources append?
              (:client/close-card card-id)
                reset! *resources $ resource/close-detail @*resources card-id
              (:client/open-card board-id card-id)
                send-query! $ resource/begin-detail-query @*resources board-id card-id
              _ $ ws-send! $ %:: schema/ClientMessage :dispatch op
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.schema/Op
        'dispatch-from-respo! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn dispatch-from-respo! (raw-op)
            match (schema/decode-operation raw-op)
              (:ok op) (dispatch! op)
              (:err error)
                raise $ str |Invalid-UI-operation: error
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Input
            :generics $ [] 'Input
        'install-activity-lifecycle! $ %{} 'CodeEntry
          :doc "|Install one cleanup-backed application activity watcher without duplicating ws-edn reconnect ownership."
          :code $ quote $ defn install-activity-lifecycle! ()
            do (cleanup-activity-lifecycle!)
              let
                  cleanup $ watch-browser-lifecycle!
                    fn (signal)
                      cond
                          = signal :visible
                          when @*connected? $ send-activity!
                        (= signal :hidden)
                          when @*connected? $ send-activity!
                        (= signal :heartbeat)
                          when @*connected? $ ws-send! $ schema/ClientMessage :sync/heartbeat @*sync-revision
                        true &unit
                      , &unit
                    Option :some 30000
                reset! *activity-cleanup $ Option :some cleanup
                , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
            :features $ #{} :js-ffi
        'main! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn main! ()
            do
              println "|Running mode:" $ if config/dev? |dev |release
              if config/dev? $ load-console-formatter!
              render-app!
              connect!
              add-watch! *store :changes on-store-change!
              add-watch! *states :changes on-states-change!
              add-watch! *partitions :changes on-states-change!
              add-watch! *resources :changes on-states-change!
              install-activity-lifecycle!
              workload-entry!
              println "|App started!"
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Dynamic)
            :args $ []
            :features $ #{} :js-ffi
        'mount-target $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def mount-target (query-mount-target)
          :examples $ []
          :schema $ :: 'Dynamic
        'on-server-data $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn on-server-data (data)
            match (schema/decode-server-message data)
              (:ok message)
                match message
                  (:snapshot revision store)
                    do
                      reset! *store $ ClientState :ready store
                      reset! *sync-revision revision
                      ack-sync! revision
                  (:patch base-revision revision changes)
                    do
                      when config/dev? $ js/console.log |Changes changes
                      apply-server-patch! base-revision revision changes
                  (:effect/pong) &unit
                  (:part/snapshot _key _epoch _revision _view) (apply-partition-message! message)
                  (:part/patch _key _epoch _deltas) (apply-partition-message! message)
                  (:part/drop _key) (apply-partition-message! message)
                  (:query/reply request-id reply)
                    swap! *resources $ fn (resources)
                      hint-fn $ {}
                        :args $ [] 'app.resource/Resources
                        :return 'app.resource/Resources
                      resource/receive-reply resources request-id reply
              (:err error) (eprintln "|Invalid server message:" error)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Dynamic
            :features $ #{} :js-ffi
        'on-states-change! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn on-states-change! (states prev) (render-app!)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Current 'Previous
            :generics $ [] 'Current 'Previous
        'on-store-change! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn on-store-change! (store prev) (render-app!)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.client/ClientState 'app.client/ClientState
        'query-mount-target $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn query-mount-target ()
            match (browser/query-selector |.app)
              (:none) nil
              (:some host-element) (narrow-element host-element)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ []
            :return $ :: 'JsNullish 'respo.dom/DomElement
        'refresh-stale-details! $ %{} 'CodeEntry
          :doc "|After a board update, refetch only open card details whose hot detail-rev moved forward."
          :code $ quote $ defn refresh-stale-details! (key)
            match key
              (:board _board-id)
                match (get @*partitions key)
                  (:some slot)
                    match (:view slot)
                      (:board board)
                        each (resource/stale-details @*resources board)
                          fn (card-id)
                            hint-fn $ {}
                              :args $ [] 'String
                              :return 'Unit
                            send-query! $ resource/begin-detail-query @*resources (:id board) card-id
                      _ &unit
                  (:none) &unit
              _ &unit
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.schema/PartitionKey
        'reload! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn reload! ()
            if (non-nil? client-errors) (hud! |error client-errors)
              do (hud! |inactive nil) (remove-watch! *store :changes) (remove-watch! *states :changes) (clear-cache!) (render-app!) (add-watch! *store :changes on-store-change!) (add-watch! *states :changes on-states-change!) (install-activity-lifecycle!) (ws-set-on-data! on-server-data) (println "|Code updated.")
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'render-app! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn render-app! ()
            let
                states $ match (get @*states :states)
                  (:some value) value
                  (:none) ({})
                app $ match @*store
                  (:loading)
                    comp-offline $ :: :loading
                  (:offline)
                    comp-offline $ :: :offline
                  (:ready store) (comp-container states store)
              render! mount-target app dispatch-from-respo!
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'request-snapshot! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn request-snapshot! ()
            ws-send! $ %:: schema/ClientMessage :sync/resume @*sync-revision
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'send-activity! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn send-activity! ()
            if (page-visible?)
              ws-send! $ %:: schema/ClientMessage :sync/active @*sync-revision
              ws-send! $ %:: schema/ClientMessage :sync/idle @*sync-revision
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'send-query! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn send-query! (request)
            reset! *resources $ :resources request
            ws-send! $ schema/ClientMessage :query (:request-id request) (:query request)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.resource/QueryRequest
        'simulate-login! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn simulate-login! ()
            match (stored-login)
              (:some pair)
                do (println "|Found storage.")
                  dispatch! $ %:: app.schema/Op :user/log-in
                    option:unwrap $ nth pair 0
                    option:unwrap $ nth pair 1
              (:none) (println "|Found no storage.")
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'stored-login $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn stored-login ()
            let
                storage $ browser/window-local-storage
                key $ assert-type
                  option:unwrap $ get config/site :storage-key
                  , String
              match
                js-nullish->option $ storage .get-item key
                (:none) (Option :none)
                (:some raw)
                  Option :some $ parse-cirru-edn-as raw $ :: 'List 'String
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ []
            :features $ #{} :js-ffi
            :return $ :: 'Option $ :: 'List 'String
        'validate-server-patch $ %{} 'CodeEntry
          :doc "|Validate base revision and apply one patch batch without mutating client state."
          :code $ quote $ defn validate-server-patch (store local-revision base-revision changes decode-result)
            if (= base-revision local-revision)
              match
                .apply-to (patch-batch changes) store
                (:ok next-store)
                  match (decode-result next-store)
                    (:ok validated) (Result :ok validated)
                    (:err detail)
                      Result :err $ ClientPatchError :invalid-result detail
                (:err error)
                  Result :err $ ClientPatchError :invalid-patch error
              Result :err $ ClientPatchError :revision-mismatch base-revision local-revision
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T 'Number 'Number (:: 'List 'recollect.schema/change-op)
              :: 'Fn $ {}
                :args $ [] 'Dynamic
                :return $ :: 'Result 'T 'String
            :generics $ [] 'T
            :return $ :: 'Result 'T 'app.client/ClientPatchError
          :tests $ []
            %{} 'TestEntry (:name |accepts-valid-revisioned-patch)
              :code $ quote $ let
                  decode-result $ fn (value)
                    hint-fn $ {}
                      :args $ [] 'Dynamic
                      :return $ :: 'Result (:: 'Map 'Tag 'Number) 'String
                    try-decode-map-as value $ :: 'Map 'Tag 'Number
                  store $ {} $ :value 1
                  changes $ [] $ %:: patch-schema/change-op :assoc :value 2
                assert=
                  Result :ok $ {} $ :value 2
                  validate-server-patch store 7 7 changes decode-result
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-revision-mismatch)
              :code $ quote $ let
                  decode-result $ fn (value)
                    hint-fn $ {}
                      :args $ [] 'Dynamic
                      :return $ :: 'Result (:: 'Map 'Tag 'Number) 'String
                    try-decode-map-as value $ :: 'Map 'Tag 'Number
                  store $ {} $ :value 1
                  changes $ assert-type ([]) (:: 'List 'recollect.schema/change-op)
                assert=
                  Result :err $ ClientPatchError :revision-mismatch 8 7
                  validate-server-patch store 7 8 changes decode-result
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-invalid-patch-atomically)
              :code $ quote $ let
                  decode-result $ fn (value)
                    hint-fn $ {}
                      :args $ [] 'Dynamic
                      :return $ :: 'Result (:: 'Map 'Tag 'Number) 'String
                    try-decode-map-as value $ :: 'Map 'Tag 'Number
                  store $ {} $ :stable 1
                  changes $ [] (%:: patch-schema/change-op :assoc :temporary 2)
                    %:: patch-schema/change-op :update :missing $ %:: patch-schema/change-op :replace 3
                  expected $ Result :err $ ClientPatchError :invalid-patch
                    PatchError :missing-node $ [] $ PatchPathSegment :field :missing
                assert= expected $ validate-server-patch store 9 9 changes decode-result
                assert=
                  {} $ :stable 1
                  , store
              :tags $ #{} :client
            %{} 'TestEntry (:name |ready-store-retains-nominal-state)
              :code $ quote $ let
                  db app.schema/database
                  shared $ app.twig.container/twig-shared db 0
                  store $ app.twig.container/twig-container db app.schema/session shared
                  changes $ assert-type ([]) (:: 'List 'recollect.schema/change-op)
                  state $ match (validate-server-patch store 7 7 changes app.schema/decode-store)
                    (:ok next-store) (ClientState :ready next-store)
                    (:err error) (raise |Unexpected-patch-error)
                assert= (ClientState :ready store) state
                match state
                  (:ready next-store) (assert= store next-store)
                  _ $ raise |Expected-ready-state
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-type-changing-replacement)
              :code $ quote $ assert= true
                let
                    db app.schema/database
                    store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                    changes $ [] $ patch-schema/change-op :replace |not-a-store
                  match (validate-server-patch store 9 9 changes app.schema/decode-store)
                    (:err error)
                      match error
                        (:invalid-result detail) (= detail |Expected-nominal-Store)
                        _ false
                    _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-corrupt-result-atomically)
              :code $ quote $ let
                  db app.schema/database
                  store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                  original-count $ :count store
                  original-color $ :color store
                  changes $ [] (patch-schema/change-op :assoc :count 2) (patch-schema/change-op :assoc :color 42)
                assert= true $ match (validate-server-patch store 9 9 changes app.schema/decode-store)
                  (:err error)
                    match error
                      (:invalid-result detail) (includes? detail |$.color)
                      _ false
                  _ false
                assert= original-count $ :count store
                assert= original-color $ :color store
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-corrupt-nested-patch)
              :code $ quote $ assert= true
                let
                    db app.schema/database
                    store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                    changes $ [] $ patch-schema/change-op :update :session
                      patch-schema/change-op :assoc :id $ Option :some |not-a-number
                  match (validate-server-patch store 9 9 changes app.schema/decode-store)
                    (:err error)
                      match error
                        (:invalid-result detail) (includes? detail |$.session.id)
                        _ false
                    _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |checks-generic-scalar-result)
              :code $ quote $ let
                  decode-number $ fn (value)
                    hint-fn $ {}
                      :args $ [] 'Dynamic
                      :return $ :: 'Result 'Number 'String
                    try-decode-map-as value 'Number
                  changes $ [] $ patch-schema/change-op :replace |different-type
                assert= true $ match (validate-server-patch 1 9 9 changes decode-number)
                  (:err error)
                    match error
                      (:invalid-result detail) (includes? detail "|expected number, got string")
                      _ false
                  _ false
              :tags $ #{} :client
        'workload-entry! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn workload-entry! () (workload/main!)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.client
          :require
            respo.core :refer $ render! clear-cache! realize-ssr! div <>
            respo.cursor :refer $ update-states
            app.comp.container :refer $ comp-container comp-offline
            app.schema :as schema
            app.schema :refer $ Op
            app.config :as config
            ws-edn.client :refer $ ws-connect! ws-send! ws-set-on-data!
            recollect.patch :refer $ patch-batch patch-error-message PatchError PatchPathSegment
            |url-parse :default url-parse
            |bottom-tip :default hud!
            |./calcit.build-errors.mjs :default client-errors
            recollect.schema :as patch-schema
            cumulo-util.activity :refer $ watch-browser-lifecycle! page-visible?
            app.workload.diff-patch :as workload
            js-ffi.browser :as browser
            respo.ffi.browser :refer $ narrow-element
            js-ffi.shared :refer $ console-error!
            app.partition :refer $ PartitionSlot apply-partition-deltas
            app.resource :as resource
    'app.comp.container $ %{} 'FileEntry
      :defs $ {}
        'comp-container $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-container (states store)
            let
                state $ option:unwrap-or (get states :data)
                  {} $ :demo |
                session $ :session store
                router $ :router store
                router-data $ option:unwrap-or (:data router) ({})
                logged-in? $ :logged-in? store
              div
                {} $ :class-name $ str-spaced css/preset css/global css/fullscreen css/column
                comp-navigation logged-in? $ :count store
                if logged-in?
                  match (:name router)
                    :home $ div
                      {} (:class-name css/expand)
                        :style $ {} $ :padding |8px
                      input $ {} (:class-name css/input)
                        :value $ option:unwrap-or (get state :demo) |
                      =< 8 nil
                      <> "|demo page"
                      pre $ {}
                        :style $ {} (:line-height 1.4) (:padding 4)
                          :border $ str "|1px solid #ddd"
                        :inner-text $ str "|backend data" $ format-cirru-edn store
                    :profile $ comp-profile
                      option:unwrap $ :user store
                      , router-data
                    _ $ <> $ str router
                  comp-login $ >> states :login
                comp-status-color $ :color store
                if dev?
                  comp-inspect |Store store $ {} (:bottom 0) (:left 0) (:max-width |100%)
                  div $ {}
                comp-session-messages $ :messages session
                if dev?
                  comp-reel (:reel-length store) ({})
                  div $ {}
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] (:: 'Map 'Tag 'Dynamic) 'app.schema/Store
        'comp-offline $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-offline (mark)
            div
              {} $ :style $ merge ui/global ui/fullscreen ui/column-dispersive
                {} $ :background-color $ site-theme
              div $ {} $ :style
                {} $ :height 0
              div $ {} $ :style
                {}
                  :background-image $ str "|url(" (site-icon) "|)"
                  :width 128
                  :height 128
                  :background-size :contain
              div
                {}
                  :style $ {} (:cursor :pointer) (:line-height |32px)
                  :on-click $ fn (e d!)
                    d! $ %:: app.schema/Op :effect/connect
                <>
                  match mark
                    (:loading) |Loading...
                    (:offline) "|No connection..."
                  {} (:font-family ui/font-fancy) (:font-size 16)
                    :color $ hsl 0 0 50
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] 'Dynamic
        'comp-session-messages $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-session-messages (messages)
            list->
              {} $ :style $ {} (:position :fixed) (:top 8) (:right 8) (:z-index 1000)
              -> messages
                filter-map-kv $ fn (id message)
                  hint-fn $ {}
                    :args $ [] 'String 'app.schema/MessageView
                    :return $ :: 'MapEntryDecision 'String 'respo.schema/Element
                  %:: MapEntryDecision :keep id $ div
                    {}
                      :style $ {} (:padding 8) (:margin-bottom 8)
                        :background-color $ hsl 0 80 95
                        :border $ str "|1px solid " $ hsl 0 70 80
                        :border-radius 4
                        :cursor :pointer
                      :on-click $ fn (e d!)
                        d! $ %:: schema/Op :session/remove-message $ %{} schema/RemoveMessage (:id id)
                    <> (:text message) nil
                .to-list
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] $ :: 'Map 'String 'app.schema/MessageView
        'comp-status-color $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-status-color (color)
            div $ {} (:class-name css-status-color)
              :style $ let
                  size 24
                {} (:width size) (:height size) (:background-color color)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] 'String
        'css-status-color $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle css-status-color
            {} $ |$0 $ {} (:position :absolute) (:bottom 60) (:left 8) (:border-radius |50%) (:opacity 0.6) (:pointer-events :none)
          :examples $ []
          :schema $ :: 'Dynamic
        'site-icon $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn site-icon ()
            assert-type (&map:get config/site :icon) String
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ []
        'site-theme $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn site-theme ()
            assert-type (&map:get config/site :theme) String
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ []
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.comp.container
          :require
            respo.util.format :refer $ hsl
            respo-ui.core :as ui
            respo-ui.css :as css
            respo.core :refer $ defcomp <> >> div span button input pre list->
            respo.css :refer $ defstyle
            respo.comp.inspect :refer $ comp-inspect
            respo.comp.space :refer $ =<
            app.comp.navigation :refer $ comp-navigation
            app.comp.profile :refer $ comp-profile
            app.comp.login :refer $ comp-login
            cumulo-reel.comp.reel :refer $ comp-reel
            app.config :refer $ dev?
            app.schema :as schema
            app.config :as config
    'app.comp.login $ %{} 'FileEntry
      :defs $ {}
        'comp-login $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-login (states)
            let
                cursor $ option:unwrap-or (get states :cursor) ([])
                state $ option:unwrap-or (get states :data) initial-state
              div
                {} $ :class-name $ str-spaced css/flex css/center
                div ({})
                  div ({})
                    div ({})
                      input $ {} (:placeholder |Username) (:class-name css/input)
                        :value $ option:unwrap-or (get state :username) |
                        :on-input $ fn (e d!)
                          let
                              value $ get e :value
                            d! $ %:: schema/Op :states cursor $ assoc state :username (value .unwrap-or |)
                    =< nil 8
                    div ({})
                      input $ {} (:placeholder |Password) (:class-name css/input)
                        :value $ option:unwrap-or (get state :password) |
                        :on-input $ fn (e d!)
                          let
                              value $ get e :value
                            d! $ %:: schema/Op :states cursor $ assoc state :password (value .unwrap-or |)
                  =< nil 8
                  div
                    {} $ :style $ {} (:text-align :right)
                    span $ {} (:inner-text "|Sign up") (:class-name css/link)
                      :on-click $ on-submit
                        option:unwrap-or (get state :username) |
                        option:unwrap-or (get state :password) |
                        , true
                    =< 8 nil
                    span $ {} (:inner-text "|Log in") (:class-name css/link)
                      :on-click $ on-submit
                        option:unwrap-or (get state :username) |
                        option:unwrap-or (get state :password) |
                        , false
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] $ :: 'Map 'Tag 'Dynamic
        'initial-state $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def initial-state
            {} (:username |) (:password |)
          :examples $ []
          :schema $ :: 'Dynamic
        'on-submit $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn on-submit (username password signup?)
            fn (e dispatch!)
              dispatch! $ if signup? (%:: app.schema/Op :user/sign-up username password) (%:: app.schema/Op :user/log-in username password)
              when (js-present? js/localStorage)
                let
                    storage $ unsafe-coerce js/localStorage 'js-ffi.browser/StorageHost
                  storage .set-item!
                    assert-type
                      option:unwrap $ get config/site :storage-key
                      , 'String
                    format-cirru-edn $ [] username password
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Fn)
            :args $ [] 'String 'String 'Bool
            :features $ #{} :js-ffi
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.comp.login
          :require
            respo.core :refer $ defcomp <> div input button span
            respo.css :refer $ defstyle
            respo.comp.space :refer $ =<
            respo.comp.inspect :refer $ comp-inspect
            respo-ui.core :as ui
            respo-ui.css :as css
            app.schema :as schema
            app.config :as config
    'app.comp.navigation $ %{} 'FileEntry
      :defs $ {}
        'comp-navigation $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-navigation (logged-in? count-members)
            div
              {} $ :class-name $ str-spaced css/row-center css-navigation
              div
                {}
                  :on-click $ fn (e d!)
                    d! $ %:: app.schema/Op :router/change $ %{} app.schema/Router (:name :home)
                      :target $ Option :none
                  :style $ {} $ :cursor :pointer
                <>
                  option:unwrap-or (get config/site :title) |Calcium
                  , nil
              div
                {}
                  :style $ {} $ :cursor |pointer
                  :on-click $ fn (e d!)
                    d! $ %:: app.schema/Op :router/change $ %{} app.schema/Router (:name :profile)
                      :target $ Option :none
                <> $ if logged-in? |Me |Guest
                =< 8 nil
                <> $ str count-members
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] 'Bool 'Number
        'css-navigation $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle css-navigation
            {} $ |$0 $ {} (:height 48) (:justify-content :space-between) (:padding "|0 16px") (:font-size 16)
              :border-bottom $ str "|1px solid " $ hsl 0 0 0 0.1
              :font-family ui/font-fancy
          :examples $ []
          :schema $ :: 'Dynamic
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.comp.navigation
          :require
            respo.util.format :refer $ hsl
            respo-ui.css :as css
            respo-ui.core :as ui
            respo.css :refer $ defstyle
            respo.comp.space :refer $ =<
            respo.core :refer $ defcomp <> span div
            app.config :as config
    'app.comp.profile $ %{} 'FileEntry
      :defs $ {}
        'comp-profile $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-profile (user members)
            div
              {} (:class-name css/flex)
                :style $ {} $ :padding 16
              div
                {} (:class-name css/font-fancy)
                  :style $ {} (:font-size 32) (:font-weight 100)
                <> $ str "|Hello! " $ :name user
              =< nil 16
              div
                {} $ :class-name css/row
                <> |Members:
                =< 8 nil
                list->
                  {} $ :class-name css/row
                  -> members (.to-list)
                    map $ fn (pair)
                      let[] (k username) pair $ [] k $ div
                        {} $ :class-name css-member-label
                        match
                          app.schema/decode-optional-string (Option :some username) |profile.members
                          (:ok name-option)
                            <> $ option:unwrap-or name-option |
                          (:err detail)
                            raise $ str |Invalid-profile-member: detail
              =< nil 48
              div ({})
                button
                  {} (:class-name css/button)
                    :on-click $ fn (e d!)
                      js/location.replace $ str js/location.origin |?time= $ js/Date.now
                      , &unit
                  <> |Refresh
                =< 8 nil
                button
                  {} (:class-name css/button)
                    :style $ {} (:color :red) (:border-color :red)
                    :on-click $ fn (e dispatch!)
                      dispatch! $ %:: app.schema/Op :user/log-out
                      js/localStorage.removeItem $ option:unwrap $ get config/site :storage-key
                      , &unit
                  <> "|Log out"
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] 'app.schema/UserView $ :: 'Map 'K 'V
            :features $ #{} :js-ffi
            :generics $ [] 'K 'V
        'css-member-label $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle css-member-label
            {} $ |$0 $ {} (:padding "|0 8px")
              :border $ str "|1px solid " $ hsl 0 0 80
              :border-radius |16px
              :margin "|0 4px"
          :examples $ []
          :schema $ :: 'Dynamic
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.comp.profile
          :require
            respo.util.format :refer $ hsl
            app.schema :as schema
            respo-ui.core :as ui
            respo-ui.css :as css
            respo.core :refer $ defcomp list-> <> span div button
            respo.css :refer $ defstyle
            respo.comp.space :refer $ =<
            app.config :as config
    'app.config $ %{} 'FileEntry
      :defs $ {}
        'dev? $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def dev?
            = |dev $ option:unwrap-or (get-env |mode) |release
          :examples $ []
          :schema $ :: 'Dynamic
        'site $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def site
            {} (:port 5021) (:title |Calcium) (:icon |https://cdn.tiye.me/logo/cumulo.png) (:theme |#eeeeff) (:storage-key |calcium-storage) (:storage-file |storage.cirru)
          :examples $ []
          :schema $ :: 'Dynamic
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.config
    'app.partition $ %{} 'FileEntry
      :defs $ {}
        'PartitionAction $ %{} 'CodeEntry
          :doc "|One transport action for a connection: drop a revoked partition, or send its snapshot or delta chain."
          :code $ quote $ defenum PartitionAction (:drop 'app.schema/PartitionKey) (:snapshot 'app.partition/PartitionState)
            :deltas 'app.partition/PartitionState $ :: 'List 'app.schema/PartitionDelta
          :examples $ []
          :schema $ :: 'EnumDef
        'PartitionAdvance $ %{} 'CodeEntry
          :doc "|Outcome of projecting a new partition view: no change, one retained delta, or a reset that forces snapshots."
          :code $ quote $ defenum PartitionAdvance (:unchanged) (:delta 'app.schema/PartitionDelta 'recollect.diff/DiffStats) (:reset 'recollect.diff/DiffStats)
          :examples $ []
          :schema $ :: 'EnumDef
        'PartitionProgress $ %{} 'CodeEntry
          :doc "|Per-connection progress for one subscribed partition: acknowledged revision plus at most one unacknowledged send."
          :code $ quote $ defstruct PartitionProgress (:epoch 'Number) (:acked 'Number)
            :in-flight $ :: 'Option 'Number
          :examples $ []
          :schema $ :: 'StructDef
        'PartitionSendPlan $ %{} 'CodeEntry
          :doc "|What one subscriber needs next: nothing, a full snapshot, or the retained contiguous delta chain from its acknowledged revision."
          :code $ quote $ defenum PartitionSendPlan (:idle) (:snapshot)
            :deltas $ :: 'List 'app.schema/PartitionDelta
          :examples $ []
          :schema $ :: 'EnumDef
        'PartitionSlot $ %{} 'CodeEntry
          :doc "|Client cache of one subscribed partition: lineage epoch, applied revision and validated view."
          :code $ quote $ defstruct PartitionSlot (:epoch 'Number) (:revision 'Number)
            :view $ quote app.schema/PartitionView
          :examples $ []
          :schema $ :: 'StructDef
        'PartitionState $ %{} 'CodeEntry
          :doc "|Server-owned hot state of one partition. epoch changes whenever revisions restart, so old acknowledgements never match a new lineage."
          :code $ quote $ defstruct PartitionState
            :key $ quote app.schema/PartitionKey
            :epoch 'Number
            :revision 'Number
            :view $ quote app.schema/PartitionView
            :history $ :: 'List 'app.schema/PartitionDelta
          :examples $ []
          :schema $ :: 'StructDef
        'PartitionStep $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct PartitionStep
            :state $ quote app.partition/PartitionState
            :advance $ quote app.partition/PartitionAdvance
          :examples $ []
          :schema $ :: 'StructDef
        'ack-partition-progress $ %{} 'CodeEntry
          :doc "|Advance the baseline only for the matching epoch and pending revision; stale, duplicate, and reordered ACKs are ignored."
          :code $ quote $ defn ack-partition-progress (progress epoch revision)
            match (:in-flight progress)
              (:some pending)
                if
                  and
                    = epoch $ :epoch progress
                    = revision pending
                  struct-with progress (:acked revision)
                    :in-flight $ Option :none
                  , progress
              (:none) progress
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.partition/PartitionProgress)
            :args $ [] 'app.partition/PartitionProgress 'Number 'Number
          :tests $ [] $ %{} 'TestEntry (:name |single-pending-send-and-stale-acks)
            :code $ quote $ let
                s1 $ new-partition (PartitionKey :lobby) 7 $ test-lobby ([] |a)
                sent $ mark-partition-sent s1 $ Option :none
                s2 $ :state $ advance-partition s1
                  test-lobby $ [] |b
                  , test-budget 8 64
                wrong-epoch $ ack-partition-progress sent 6 1
                wrong-revision $ ack-partition-progress sent 7 2
                acked $ ack-partition-progress sent 7 1
              assert= (Option :some 1) (:in-flight sent)
              assert= (PartitionSendPlan :idle)
                plan-partition-send s2 $ Option :some sent
              assert= sent wrong-epoch
              assert= sent wrong-revision
              assert= 1 $ :acked acked
              assert= (Option :none) (:in-flight acked)
              assert= acked $ ack-partition-progress acked 7 1
              assert=
                PartitionSendPlan :deltas $ :history s2
                plan-partition-send s2 $ Option :some acked
              assert= 0 $ :acked $ release-partition-send sent
              assert= (Option :none)
                :in-flight $ release-partition-send sent
            :tags $ #{} :partition :server
        'advance-partition $ %{} 'CodeEntry
          :doc "|Diff the retained view against a new projection exactly once. Budget or operation overflow resets history instead of emitting a partial patch."
          :code $ quote $ defn advance-partition (state view budget history-limit operation-limit)
            match
              diff-twig-budgeted (:view state) view
                {} $ :key :id
                , budget
              (:budget-exceeded _reason stats) (reset-step state view stats)
              (:complete changes stats)
                cond
                    empty? changes
                    %{} PartitionStep (:state state)
                      :advance $ PartitionAdvance :unchanged
                  (> (count changes) operation-limit)
                    reset-step state view stats
                  true $ let
                      next-revision $ inc $ :revision state
                      delta $ %{} PartitionDelta
                        :base $ :revision state
                        :revision next-revision
                        :changes changes
                    %{} PartitionStep
                      :state $ struct-with state (:revision next-revision) (:view view)
                        :history $ trim-history
                          conj (:history state) delta
                          , history-limit
                      :advance $ PartitionAdvance :delta delta stats
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.partition/PartitionStep)
            :args $ [] 'app.partition/PartitionState 'app.schema/PartitionView 'recollect.diff/DiffBudget 'Number 'Number
          :tests $ []
            %{} 'TestEntry (:name |unchanged-view-keeps-revision)
              :code $ quote $ let
                  state $ new-partition (PartitionKey :lobby) 7 $ test-lobby ([] |a |b)
                  step $ advance-partition state
                    test-lobby $ [] |a |b
                    , test-budget 8 64
                assert= (PartitionAdvance :unchanged) (:advance step)
                assert= 1 $ :revision $ :state step
                assert= ([])
                  :history $ :state step
              :tags $ #{} :partition :server
            %{} 'TestEntry (:name |one-delta-serves-every-subscriber)
              :code $ quote $ let
                  state $ new-partition (PartitionKey :lobby) 7 $ test-lobby ([] |a |b)
                  step $ advance-partition state
                    test-lobby $ [] |a |c
                    , test-budget 8 64
                  next-state $ :state step
                  progress $ %{} PartitionProgress (:epoch 7) (:acked 1)
                    :in-flight $ Option :none
                  plans $ map (range 5)
                    fn (_idx)
                      hint-fn $ {}
                        :args $ [] 'Number
                        :return 'app.partition/PartitionSendPlan
                      plan-partition-send next-state $ Option :some progress
                match (:advance step)
                  (:delta delta _stats)
                    do
                      assert= 1 $ :base delta
                      assert= 2 $ :revision delta
                      assert= 1 $ count $ :history next-state
                      assert= 1 $ count $ distinct plans
                      assert=
                        Option :some $ PartitionSendPlan :deltas $ [] delta
                        first plans
                  _ $ raise |Expected-one-delta
              :tags $ #{} :partition :server
            %{} 'TestEntry (:name |operation-overflow-resets-history)
              :code $ quote $ let
                  s1 $ new-partition (PartitionKey :lobby) 7 $ test-lobby ([] |a)
                  s2 $ :state $ advance-partition s1
                    test-lobby $ [] |b
                    , test-budget 8 64
                  step $ advance-partition s2
                    test-lobby $ [] |x |y |z
                    , test-budget 8 0
                  s3 $ :state step
                match (:advance step)
                  (:reset _stats)
                    do
                      assert= 3 $ :revision s3
                      assert= ([]) (:history s3)
                      assert= (PartitionSendPlan :snapshot)
                        plan-partition-send s3 $ Option :some $ %{} PartitionProgress (:epoch 7) (:acked 2)
                          :in-flight $ Option :none
                  _ $ raise |Expected-reset
              :tags $ #{} :partition :server
        'apply-partition-deltas $ %{} 'CodeEntry
          :doc "|Apply a delta chain atomically: epoch and every base revision must match, and the final view must validate, otherwise the cached slot is left untouched."
          :code $ quote $ defn apply-partition-deltas (slot epoch deltas)
            if
              not= epoch $ :epoch slot
              Result :err $ str "|Partition epoch mismatch: " epoch "| vs " $ :epoch slot
              let
                  applied $ foldl deltas
                    assert-type
                      Result :ok $ [] (:revision slot) (:view slot)
                      :: 'Result (:: 'List 'Dynamic) 'String
                    fn (acc delta)
                      hint-fn $ {}
                        :args $ []
                          :: 'Result (:: 'List 'Dynamic) 'String
                          , 'app.schema/PartitionDelta
                        :return $ :: 'Result (:: 'List 'Dynamic) 'String
                      match acc
                        (:err _) acc
                        (:ok pair)
                          let[] (revision view) pair $ if
                            not= revision $ :base delta
                            Result :err $ str "|Partition base mismatch: " (:base delta) "| vs " revision
                            match
                              .apply-to
                                patch-batch $ :changes delta
                                , view
                              (:ok next-view)
                                Result :ok $ [] (:revision delta) next-view
                              (:err error)
                                Result :err $ patch-error-message error
                match applied
                  (:err detail) (Result :err detail)
                  (:ok pair)
                    let[] (revision view) pair $ match (decode-partition-view view)
                      (:ok typed)
                        Result :ok $ %{} PartitionSlot (:epoch epoch)
                          :revision $ assert-type revision Number
                          :view typed
                      (:err detail) (Result :err detail)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'app.partition/PartitionSlot 'Number $ :: 'List 'app.schema/PartitionDelta
            :return $ :: 'Result 'app.partition/PartitionSlot 'String
          :tests $ [] $ %{} 'TestEntry (:name |atomic-chain-application)
            :code $ quote $ let
                v1 $ test-lobby $ [] |a |b
                s1 $ new-partition (PartitionKey :lobby) 7 v1
                s2 $ :state $ advance-partition s1
                  test-lobby $ [] |a |c
                  , test-budget 8 64
                s3 $ :state $ advance-partition s2
                  test-lobby $ [] |d |c |e
                  , test-budget 8 64
                slot $ %{} PartitionSlot (:epoch 7) (:revision 1) (:view v1)
              assert=
                Result :ok $ %{} PartitionSlot (:epoch 7) (:revision 3)
                  :view $ :view s3
                apply-partition-deltas slot 7 $ :history s3
              assert= true $ match
                apply-partition-deltas slot 8 $ :history s3
                (:err detail) (includes? detail |epoch)
                _ false
              assert= true $ match
                apply-partition-deltas slot 7 $ slice (:history s3) 1 2
                (:err detail) (includes? detail |base)
                _ false
            :tags $ #{} :client :partition :server
        'connection-actions $ %{} 'CodeEntry
          :doc "|Plan one connection's transport work: drops for partitions it may no longer see, then snapshots or retained delta chains for authorized partitions."
          :code $ quote $ defn connection-actions (partitions progress desired)
            let
                drops $ -> (.to-list progress)
                  filter $ fn (pair)
                    hint-fn $ {}
                      :args $ [] 'Dynamic
                      :return 'Bool
                    let[] (key _progress) pair $ not $ includes? desired key
                  map $ fn (pair)
                    hint-fn $ {}
                      :args $ [] 'Dynamic
                      :return 'app.partition/PartitionAction
                    let[] (key _progress) pair $ PartitionAction :drop $ assert-type key app.schema/PartitionKey
                sends $ foldl (.to-list desired) ([])
                  fn (acc key)
                    hint-fn $ {}
                      :args $ [] (:: 'List 'app.partition/PartitionAction) 'app.schema/PartitionKey
                      :return $ :: 'List 'app.partition/PartitionAction
                    match (get partitions key)
                      (:none) acc
                      (:some raw-state)
                        let
                            state $ assert-type raw-state app.partition/PartitionState
                            progress-option $ match (get progress key)
                              (:some raw)
                                Option :some $ assert-type raw app.partition/PartitionProgress
                              (:none) (Option :none)
                          match (plan-partition-send state progress-option)
                            (:idle) acc
                            (:snapshot)
                              conj acc $ PartitionAction :snapshot state
                            (:deltas deltas)
                              conj acc $ PartitionAction :deltas state deltas
              concat drops sends
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'Map 'app.schema/PartitionKey 'app.partition/PartitionState) (:: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress) (:: 'Set 'app.schema/PartitionKey)
            :return $ :: 'List 'app.partition/PartitionAction
          :tests $ [] $ %{} 'TestEntry (:name |drops-revoked-and-plans-authorized)
            :code $ quote $ let
                lobby $ new-partition (PartitionKey :lobby) 7 $ test-lobby ([] |a)
                lobby2 $ :state $ advance-partition lobby
                  test-lobby $ [] |b
                  , test-budget 8 64
                partitions $ assert-type
                  {} $
                    PartitionKey :lobby
                    , lobby2
                  :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionState
                acked $ %{} PartitionProgress (:epoch 7) (:acked 1)
                  :in-flight $ Option :none
                progress $ assert-type
                  {}
                      PartitionKey :lobby
                      , acked
                    (PartitionKey :board |gone) acked
                  :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress
                no-progress $ assert-type ({}) (:: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress)
                actions $ connection-actions partitions progress $ #{} (PartitionKey :lobby) (PartitionKey :user |u1)
              assert= 2 $ count actions
              assert= true $ includes? actions $ PartitionAction :drop (PartitionKey :board |gone)
              assert= true $ includes? actions $ PartitionAction :deltas lobby2 (:history lobby2)
              assert=
                [] $ PartitionAction :snapshot lobby2
                connection-actions partitions no-progress $ #{} $ PartitionKey :lobby
            :tags $ #{} :partition :server
        'decode-partition-view $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn decode-partition-view (value)
            try-decode-map-as (app.schema/struct-tree-input value) 'app.schema/PartitionView
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :return $ :: 'Result 'app.schema/PartitionView 'String
        'delta-chain $ %{} 'CodeEntry
          :doc "|Return the complete retained chain from an acknowledged revision to the current revision, or none when any link was trimmed or reset."
          :code $ quote $ defn delta-chain (history from to)
            match
              find-index history $ fn (delta)
                hint-fn $ {}
                  :args $ [] 'app.schema/PartitionDelta
                  :return 'Bool
                = from $ :base delta
              (:none) (Option :none)
              (:some index)
                let
                    chain $ &list:slice history index
                  match (last chain)
                    (:some tail)
                      if
                        = to $ :revision tail
                        Option :some chain
                        Option :none
                    (:none) (Option :none)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'List 'app.schema/PartitionDelta) 'Number 'Number
            :return $ :: 'Option $ :: 'List 'app.schema/PartitionDelta
          :tests $ [] $ %{} 'TestEntry (:name |replayed-chain-converges)
            :code $ quote $ let
                v1 $ test-lobby $ [] |a |b
                s1 $ new-partition (PartitionKey :lobby) 7 v1
                s2 $ :state $ advance-partition s1
                  test-lobby $ [] |a |c
                  , test-budget 8 64
                s3 $ :state $ advance-partition s2
                  test-lobby $ [] |d |c |e
                  , test-budget 8 64
              match
                delta-chain (:history s3) 1 3
                (:some chain)
                  let
                      replayed $ foldl chain v1 $ fn (acc delta)
                        hint-fn $ {}
                          :args $ [] 'Dynamic 'app.schema/PartitionDelta
                          :return 'Dynamic
                        match
                          .apply-to
                            recollect.patch/patch-batch $ :changes delta
                            , acc
                          (:ok next) next
                          (:err error)
                            raise $ str |Patch-failed: error
                    assert= (:view s3) replayed
                    assert= (Option :none)
                      delta-chain (:history s3) 5 3
                (:none) (raise |Expected-complete-chain)
            :tags $ #{} :partition :server
        'mark-partition-sent $ %{} 'CodeEntry
          :doc "|Record one accepted send of the current revision. The acknowledged baseline only moves when the matching ACK arrives."
          :code $ quote $ defn mark-partition-sent (state progress-option)
            let
                acked $ match progress-option
                  (:some progress)
                    if
                      = (:epoch progress) (:epoch state)
                      :acked progress
                      , 0
                  (:none) 0
              %{} PartitionProgress
                :epoch $ :epoch state
                :acked acked
                :in-flight $ Option :some $ :revision state
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.partition/PartitionProgress)
            :args $ [] 'app.partition/PartitionState $ :: 'Option 'app.partition/PartitionProgress
        'new-partition $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn new-partition (key epoch view)
            %{} PartitionState (:key key) (:epoch epoch) (:revision 1) (:view view)
              :history $ []
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.partition/PartitionState)
            :args $ [] 'app.schema/PartitionKey 'Number 'app.schema/PartitionView
        'plan-partition-send $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn plan-partition-send (state progress-option)
            match progress-option
              (:none) (PartitionSendPlan :snapshot)
              (:some progress)
                cond
                    option:some? $ :in-flight progress
                    PartitionSendPlan :idle
                  (not= (:epoch progress) (:epoch state))
                    PartitionSendPlan :snapshot
                  (= (:acked progress) (:revision state))
                    PartitionSendPlan :idle
                  true $ match
                    delta-chain (:history state) (:acked progress) (:revision state)
                    (:some deltas) (PartitionSendPlan :deltas deltas)
                    (:none) (PartitionSendPlan :snapshot)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.partition/PartitionSendPlan)
            :args $ [] 'app.partition/PartitionState $ :: 'Option 'app.partition/PartitionProgress
          :tests $ []
            %{} 'TestEntry (:name |trimmed-history-falls-back-to-snapshot)
              :code $ quote $ let
                  s1 $ new-partition (PartitionKey :lobby) 7 $ test-lobby ([] |a)
                  s2 $ :state $ advance-partition s1
                    test-lobby $ [] |b
                    , test-budget 2 64
                  s3 $ :state $ advance-partition s2
                    test-lobby $ [] |c
                    , test-budget 2 64
                  s4 $ :state $ advance-partition s3
                    test-lobby $ [] |d
                    , test-budget 2 64
                  at $ fn (acked)
                    hint-fn $ {}
                      :args $ [] 'Number
                      :return 'app.partition/PartitionSendPlan
                    plan-partition-send s4 $ Option :some $ %{} PartitionProgress (:epoch 7) (:acked acked)
                      :in-flight $ Option :none
                assert= 4 $ :revision s4
                assert= 2 $ count $ :history s4
                assert= (PartitionSendPlan :snapshot) (at 1)
                assert=
                  PartitionSendPlan :deltas $ :history s4
                  at 2
                assert= (PartitionSendPlan :idle) (at 4)
                assert= (PartitionSendPlan :snapshot) (at 9)
                assert= (PartitionSendPlan :snapshot)
                  plan-partition-send s4 $ Option :none
              :tags $ #{} :partition :server
            %{} 'TestEntry (:name |epoch-change-forces-snapshot)
              :code $ quote $ let
                  state $ new-partition (PartitionKey :lobby) 8 $ test-lobby ([] |a)
                  stale $ %{} PartitionProgress (:epoch 7) (:acked 1)
                    :in-flight $ Option :none
                assert= (PartitionSendPlan :snapshot)
                  plan-partition-send state $ Option :some stale
                assert= 0 $ :acked $ mark-partition-sent state (Option :some stale)
              :tags $ #{} :partition :server
        'release-partition-send $ %{} 'CodeEntry
          :doc "|Forget a send that the transport did not accept, keeping the acknowledged baseline for the next attempt."
          :code $ quote $ defn release-partition-send (progress)
            struct-with progress $ :in-flight $ Option :none
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.partition/PartitionProgress)
            :args $ [] 'app.partition/PartitionProgress
        'reset-step $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn reset-step (state view stats)
            %{} PartitionStep
              :state $ struct-with state
                :revision $ inc $ :revision state
                :view view
                :history $ []
              :advance $ PartitionAdvance :reset stats
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.partition/PartitionStep)
            :args $ [] 'app.partition/PartitionState 'app.schema/PartitionView 'recollect.diff/DiffStats
        'test-budget $ %{} 'CodeEntry
          :doc "|Generous deterministic budget used by partition engine tests."
          :code $ quote $ def test-budget
            %{} DiffBudget
              :max-visited $ Option :some 10000
              :max-emitted $ Option :some 10000
          :examples $ []
          :schema $ :: 'recollect.diff/DiffBudget
        'test-lobby $ %{} 'CodeEntry
          :doc "|Deterministic lobby projection used by partition engine tests."
          :code $ quote $ defn test-lobby (titles)
            PartitionView :lobby $ %{} app.schema/LobbyView
              :boards $ assert-type
                -> titles
                  map-indexed $ fn (idx title)
                    let
                        id $ str |b idx
                      [] id $ %{} app.schema/BoardBrief (:id id) (:title title) (:card-count idx)
                  pairs-map
                :: 'Map 'String 'app.schema/BoardBrief
              :online $ {}
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/PartitionView)
            :args $ [] $ :: 'List 'String
        'trim-history $ %{} 'CodeEntry
          :doc "|Keep only the newest deltas; subscribers older than the retained chain receive a snapshot."
          :code $ quote $ defn trim-history (history limit)
            let
                size $ count history
              if (> size limit)
                slice history (- size limit) size
                , history
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'List 'app.schema/PartitionDelta) 'Number
            :return $ :: 'List 'app.schema/PartitionDelta
      :ns $ %{} 'NsEntry
        :doc "|Pure partition synchronization engine: one diff per partition revision, bounded delta history, and per-subscriber send planning."
        :code $ quote $ ns app.partition
          :require
            app.schema :refer $ PartitionKey PartitionView PartitionDelta
            recollect.diff :refer $ diff-twig-budgeted DiffBudget DiffStats
            recollect.patch :refer $ patch-batch patch-error-message
    'app.resource $ %{} 'FileEntry
      :defs $ {}
        'DetailResource $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct DetailResource (:board-id 'String)
            :detail $ :: 'Option 'app.schema/CardDetail
            :missing? 'Bool
            :loading? 'Bool
          :examples $ []
          :schema $ :: 'StructDef
        'HistoryResource $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct HistoryResource
            :items $ :: 'List 'app.schema/HistoryEvent
            :next-cursor $ :: 'Option 'Number
            :history-rev 'Number
            :loaded? 'Bool
            :loading? 'Bool
          :examples $ []
          :schema $ :: 'StructDef
        'QueryRequest $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct QueryRequest
            :resources $ quote app.resource/Resources
            :request-id 'String
            :query $ quote app.schema/Query
          :examples $ []
          :schema $ :: 'StructDef
        'QueryTarget $ %{} 'CodeEntry
          :doc "|What a pending request id will update: the history list (append or replace) or one open card detail."
          :code $ quote $ defenum QueryTarget (:history 'Bool) (:detail 'String)
          :examples $ []
          :schema $ :: 'EnumDef
        'Resources $ %{} 'CodeEntry
          :doc "|Cold data the browser has fetched. Only open card details are kept; history pages accumulate until history-rev announces newer events."
          :code $ quote $ defstruct Resources
            :history $ quote app.resource/HistoryResource
            :details $ :: 'Map 'String 'app.resource/DetailResource
            :pending $ :: 'Map 'String 'app.resource/QueryTarget
            :counter 'Number
          :examples $ []
          :schema $ :: 'StructDef
        'begin-detail-query $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn begin-detail-query (resources board-id card-id)
            let
                request-id $ str |q $ inc (:counter resources)
                current $ match
                  get (:details resources) card-id
                  (:some existing) existing
                  (:none)
                    %{} DetailResource (:board-id board-id)
                      :detail $ Option :none
                      :missing? false
                      :loading? false
                pending $ without-target (:pending resources)
                  fn (item)
                    match item
                      (:history _) false
                      (:detail id) (= id card-id)
              %{} QueryRequest (:request-id request-id)
                :query $ Query :card-detail board-id card-id
                :resources $ struct-with resources
                  :counter $ inc $ :counter resources
                  :pending $ assoc pending request-id $ QueryTarget :detail card-id
                  :details $ assoc (:details resources) card-id $ struct-with current (:loading? true)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.resource/QueryRequest)
            :args $ [] 'app.resource/Resources 'String 'String
        'begin-history-query $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn begin-history-query (resources append?)
            let
                history $ :history resources
                request-id $ str |q $ inc (:counter resources)
                target $ QueryTarget :history append?
                pending $ without-target (:pending resources)
                  fn (item)
                    match item
                      (:history _) true
                      (:detail _) false
              %{} QueryRequest (:request-id request-id)
                :query $ Query :history
                  if append? (:next-cursor history) (Option :none)
                  , 20
                :resources $ struct-with resources
                  :counter $ inc $ :counter resources
                  :pending $ assoc pending request-id target
                  :history $ struct-with history $ :loading? true
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.resource/QueryRequest)
            :args $ [] 'app.resource/Resources 'Bool
        'close-detail $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn close-detail (resources card-id)
            struct-with resources
              :details $ dissoc (:details resources) card-id
              :pending $ without-target (:pending resources)
                fn (item)
                  match item
                    (:history _) false
                    (:detail id) (= id card-id)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.resource/Resources)
            :args $ [] 'app.resource/Resources 'String
        'empty-resources $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def empty-resources
            %{} Resources
              :history $ %{} HistoryResource
                :items $ []
                :next-cursor $ Option :none
                :history-rev 0
                :loaded? false
                :loading? false
              :details $ {}
              :pending $ {}
              :counter 0
          :examples $ []
          :schema $ :: 'app.resource/Resources
        'receive-reply $ %{} 'CodeEntry
          :doc "|Apply a reply only if its request id is still pending; closed panels, superseded requests and older content revisions are ignored."
          :code $ quote $ defn receive-reply (resources request-id reply)
            match
              get (:pending resources) request-id
              (:none) resources
              (:some target)
                let
                    base $ struct-with resources $ :pending
                      dissoc (:pending resources) request-id
                  match target
                    (:history append?)
                      let
                          history $ :history base
                        match reply
                          (:history page)
                            struct-with base $ :history $ struct-with history
                              :items $ if append?
                                concat (:items history) (:items page)
                                :items page
                              :next-cursor $ :next-cursor page
                              :history-rev $ :history-rev page
                              :loaded? true
                              :loading? false
                          _ $ struct-with base $ :history
                            struct-with history $ :loading? false
                    (:detail card-id)
                      match
                        get (:details base) card-id
                        (:none) base
                        (:some current)
                          let
                              update! $ fn (next)
                                hint-fn $ {}
                                  :args $ [] 'app.resource/DetailResource
                                  :return 'app.resource/Resources
                                struct-with base $ :details $ assoc (:details base) card-id next
                            match reply
                              (:card-detail detail)
                                if
                                  match (:detail current)
                                    (:some existing)
                                      < (:rev detail) (:rev existing)
                                    (:none) false
                                  update! $ struct-with current $ :loading? false
                                  update! $ struct-with current
                                    :detail $ Option :some detail
                                    :missing? false
                                    :loading? false
                              (:missing _)
                                update! $ struct-with current (:missing? true) (:loading? false)
                              _ $ update! $ struct-with current (:loading? false)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.resource/Resources)
            :args $ [] 'app.resource/Resources 'String 'app.schema/QueryReply
          :tests $ [] $ %{} 'TestEntry (:name |stale-and-versioned-replies)
            :code $ quote $ let
                detail $ fn (rev text)
                  hint-fn $ {}
                    :args $ [] 'Number 'String
                    :return 'app.schema/CardDetail
                  %{} CardDetail (:card-id |c1) (:board-id |b1) (:rev rev) (:description text) (:updated-at 0)
                r1 $ begin-detail-query empty-resources |b1 |c1
                r2 $ begin-detail-query (:resources r1) |b1 |c1
                late $ receive-reply (:resources r2) (:request-id r1)
                  QueryReply :card-detail $ detail 1 |old
                fresh $ receive-reply (:resources r2) (:request-id r2)
                  QueryReply :card-detail $ detail 2 |new
                r3 $ begin-detail-query fresh |b1 |c1
                older $ receive-reply (:resources r3) (:request-id r3)
                  QueryReply :card-detail $ detail 1 |older
                closed $ receive-reply
                  close-detail (:resources r3) |c1
                  :request-id r3
                  QueryReply :card-detail $ detail 3 |x
                description $ fn (resources)
                  hint-fn $ {}
                    :args $ [] 'app.resource/Resources
                    :return $ :: 'Option 'String
                  match
                    get (:details resources) |c1
                    (:some resource)
                      match (:detail resource)
                        (:some d)
                          Option :some $ :description d
                        (:none) (Option :none)
                    (:none) (Option :none)
                h1 $ begin-history-query empty-resources false
                page $ %{} app.schema/HistoryPage
                  :items $ []
                  :next-cursor $ Option :some 3
                  :history-rev 5
                h-done $ receive-reply (:resources h1) (:request-id h1) (QueryReply :history page)
                h2 $ begin-history-query h-done true
              assert= (Option :none) (description late)
              assert= (Option :some |new) (description fresh)
              assert= (Option :some |new) (description older)
              assert= (Option :none) (description closed)
              assert=
                Query :history (Option :none) 20
                :query h1
              assert= 5 $ :history-rev $ :history h-done
              assert=
                Query :history (Option :some 3) 20
                :query h2
              assert= 1 $ count $ :pending (:resources h2)
            :tags $ #{} :client :kanban :server
        'stale-details $ %{} 'CodeEntry
          :doc "|Open card details whose hot detail-rev moved past the cached content revision; only these are refetched, unused content is never downloaded."
          :code $ quote $ defn stale-details (resources board)
            ->
              .to-list $ :details resources
              filter $ fn (pair)
                hint-fn $ {}
                  :args $ [] 'Dynamic
                  :return 'Bool
                let[] (raw-card-id raw-resource) pair $ let
                    card-id $ assert-type raw-card-id String
                    resource $ assert-type raw-resource app.resource/DetailResource
                  and
                    = (:board-id resource) (:id board)
                    not $ :loading? resource
                    match
                      get (:cards board) card-id
                      (:none) false
                      (:some raw-card)
                        let
                            hot-rev $ :detail-rev $ assert-type raw-card app.schema/Card
                          match (:detail resource)
                            (:some detail)
                              > hot-rev $ :rev detail
                            (:none) false
              map $ fn (pair)
                hint-fn $ {}
                  :args $ [] 'Dynamic
                  :return 'String
                assert-type
                  option:unwrap $ nth pair 0
                  , String
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'app.resource/Resources 'app.schema/Board
            :return $ :: 'List 'String
        'without-target $ %{} 'CodeEntry
          :doc "|Forget older requests for the same target so their late replies are ignored."
          :code $ quote $ defn without-target (pending matches?)
            .filter-map-kv pending $ fn (id target)
              hint-fn $ {}
                :args $ [] 'String 'app.resource/QueryTarget
                :return $ :: 'MapEntryDecision 'String 'app.resource/QueryTarget
              if (matches? target) (%:: MapEntryDecision :drop) (%:: MapEntryDecision :keep id target)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'Map 'String 'app.resource/QueryTarget)
              :: 'Fn $ {} (:return 'Bool)
                :args $ [] 'app.resource/QueryTarget
            :return $ :: 'Map 'String 'app.resource/QueryTarget
      :ns $ %{} 'NsEntry
        :doc "|Client cache for cold callback data: request ids, stale-response rejection and content-revision checks."
        :code $ quote $ ns app.resource
          :require $ app.schema :refer $ Query QueryReply HistoryEvent CardDetail
    'app.schema $ %{} 'FileEntry
      :defs $ {}
        'AttachedView $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct AttachedView (:type 'Tag) (:content 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'Board $ %{} 'CodeEntry
          :doc "|Hot board state shared by every authorized subscriber of the board partition."
          :code $ quote $ defstruct Board (:id 'String) (:title 'String) (:created-at 'Number)
            :columns $ :: 'Map 'String 'app.schema/Column
            :cards $ :: 'Map 'String 'app.schema/Card
          :examples $ []
          :schema $ :: 'StructDef
        'BoardBrief $ %{} 'CodeEntry (:doc "|Bounded lobby summary of one board.")
          :code $ quote $ defstruct BoardBrief (:id 'String) (:title 'String) (:card-count 'Number)
          :examples $ []
          :schema $ :: 'StructDef
        'Card $ %{} 'CodeEntry
          :doc "|Hot card summary. The description lives in cold storage; detail-rev tells clients when a cached detail is stale."
          :code $ quote $ defstruct Card (:id 'String) (:column-id 'String) (:rank 'Number) (:title 'String) (:detail-rev 'Number) (:updated-at 'Number) (:updated-by 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'CardDetail $ %{} 'CodeEntry
          :doc "|Cold card content. rev matches Card :detail-rev after the same committed operation."
          :code $ quote $ defstruct CardDetail (:card-id 'String) (:board-id 'String) (:rev 'Number) (:description 'String) (:updated-at 'Number)
          :examples $ []
          :schema $ :: 'StructDef
        'ClientMessage $ %{} 'CodeEntry
          :doc "|Typed messages accepted from a browser connection. part/ack names partition, epoch and revision; part/resync asks for a fresh partition snapshot."
          :code $ quote $ defenum ClientMessage (:sync/active 'Number) (:sync/heartbeat 'Number) (:sync/idle 'Number) (:sync/resume 'Number) (:sync/ack 'Number) (:dispatch 'app.schema/Op) (:part/ack 'app.schema/PartitionKey 'Number 'Number) (:part/resync 'app.schema/PartitionKey) (:query 'String 'app.schema/Query)
          :examples $ []
          :schema $ :: 'EnumDef
        'ColdEffects $ %{} 'CodeEntry
          :doc "|Cold writes derived purely from one committed domain operation."
          :code $ quote $ defstruct ColdEffects
            :history $ :: 'List 'app.schema/HistoryEvent
            :details $ :: 'List 'app.schema/CardDetail
          :examples $ []
          :schema $ :: 'StructDef
        'ColdStore $ %{} 'CodeEntry
          :doc "|Cold data kept outside the hot Db and the Reel: append-only per-user history and versioned card details. Swap for a database-backed store without touching partition sync."
          :code $ quote $ defstruct ColdStore
            :history $ :: 'Map 'String $ :: 'List 'app.schema/HistoryEvent
            :details $ :: 'Map 'String 'app.schema/CardDetail
          :examples $ []
          :schema $ :: 'StructDef
        'Column $ %{} 'CodeEntry
          :doc "|One Kanban column ordered by a numeric rank field, so reordering changes leaves instead of list positions."
          :code $ quote $ defstruct Column (:id 'String) (:title 'String) (:rank 'Number)
          :examples $ []
          :schema $ :: 'StructDef
        'DatabaseDecodeError $ %{} 'CodeEntry
          :doc "|A path-aware failure produced while decoding untrusted or legacy persisted database data."
          :code $ quote $ defenum DatabaseDecodeError (:invalid 'String 'String)
          :examples $ []
          :schema $ :: 'EnumDef
        'Db $ %{} 'CodeEntry
          :doc "|The nominal hot application database used by reducers and partition projections. Cold history and card details live outside it."
          :code $ quote $ defstruct Db
            :sessions $ :: 'Map 'Number 'app.schema/Session
            :users $ :: 'Map 'String 'app.schema/User
            :boards $ :: 'Map 'String 'app.schema/Board
            :settings $ :: 'Map 'String 'app.schema/UserSettings
          :examples $ []
          :schema $ :: 'StructDef
        'DomainOp $ %{} 'CodeEntry
          :doc "|Pure business operations accepted by the database reducer; local and server effects stay outside this enum."
          :code $ quote $ defenum DomainOp (:session/connect) (:session/disconnect) (:session/remove-message 'app.schema/RemoveMessage) (:user/log-in 'String 'String) (:user/sign-up 'String 'String) (:user/log-out) (:router/change 'app.schema/Router) (:kanban 'app.schema/KanbanOp)
          :examples $ []
          :schema $ :: 'EnumDef
        'HistoryEvent $ %{} 'CodeEntry
          :doc "|Cold, append-only personal operation history entry."
          :code $ quote $ defstruct HistoryEvent (:id 'String) (:time 'Number) (:user-id 'String) (:kind 'Tag) (:board-id 'String) (:summary 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'HistoryPage $ %{} 'CodeEntry
          :doc "|Newest-first page of personal history. next-cursor is an exclusive index into the append-only log, stable under appends."
          :code $ quote $ defstruct HistoryPage
            :items $ :: 'List 'app.schema/HistoryEvent
            :next-cursor $ :: 'Option 'Number
            :history-rev 'Number
          :examples $ []
          :schema $ :: 'StructDef
        'KanbanOp $ %{} 'CodeEntry
          :doc "|Business operations of the Kanban demo. The acting user always comes from the session; payloads only name target ids and values."
          :code $ quote $ defenum KanbanOp (:board/create 'String) (:board/rename 'String 'String) (:column/add 'String 'String) (:card/add 'String 'String 'String) (:card/rename 'String 'String 'String) (:card/move 'String 'String 'String) (:card/shift 'String 'String 'Number) (:card/remove 'String 'String) (:card/edit-detail 'String 'String 'String) (:settings/toggle-compact) (:settings/set-accent 'String)
          :examples $ []
          :schema $ :: 'EnumDef
        'LobbyView $ %{} 'CodeEntry
          :doc "|Public hot partition: board briefs and online user names keyed by user id."
          :code $ quote $ defstruct LobbyView
            :boards $ :: 'Map 'String 'app.schema/BoardBrief
            :online $ :: 'Map 'String 'String
          :examples $ []
          :schema $ :: 'StructDef
        'Message $ %{} 'CodeEntry (:doc "|A persisted session message.")
          :code $ quote $ defstruct Message (:id 'String) (:text 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'MessageDecodeError $ %{} 'CodeEntry
          :doc "|Why an untrusted WebSocket value could not become a typed message envelope."
          :code $ quote $ defenum MessageDecodeError (:invalid 'String)
          :examples $ []
          :schema $ :: 'EnumDef
        'MessageView $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct MessageView (:id 'String) (:text 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'Op $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defenum Op (:session/connect) (:session/disconnect) (:session/remove-message 'app.schema/RemoveMessage) (:user/log-in 'String 'String) (:user/sign-up 'String 'String) (:user/log-out) (:router/change 'app.schema/Router) (:effect/persist) (:effect/ping) (:effect/pong) (:effect/connect) (:reel/reset) (:reel/merge) (:kanban 'app.schema/KanbanOp) (:client/open-card 'String 'String) (:client/close-card 'String) (:client/load-history 'Bool)
            :states (:: 'List 'Dynamic) 'Dynamic
          :examples $ []
          :schema $ :: 'EnumDef
        'PartitionDelta $ %{} 'CodeEntry
          :doc "|One retained diff step of a partition, computed once and reused for every subscriber at its base revision."
          :code $ quote $ defstruct PartitionDelta (:base 'Number) (:revision 'Number)
            :changes $ :: 'List 'recollect.schema/change-op
          :examples $ []
          :schema $ :: 'StructDef
        'PartitionKey $ %{} 'CodeEntry
          :doc "|Identity of one synchronization partition. A partition is a visibility boundary: everything inside is visible to all its subscribers."
          :code $ quote $ defenum PartitionKey (:lobby) (:board 'String) (:user 'String)
          :examples $ []
          :schema $ :: 'EnumDef
        'PartitionView $ %{} 'CodeEntry
          :doc "|Typed projection of one partition; :missing marks a deleted or unknown target."
          :code $ quote $ defenum PartitionView (:lobby 'app.schema/LobbyView) (:board 'app.schema/Board) (:user 'app.schema/UserHotView) (:missing)
          :examples $ []
          :schema $ :: 'EnumDef
        'Query $ %{} 'CodeEntry
          :doc "|Cold read requests. Identity always comes from the server session, never from query parameters."
          :code $ quote $ defenum Query
            :history (:: 'Option 'Number) 'Number
            :card-detail 'String 'String
          :examples $ []
          :schema $ :: 'EnumDef
        'QueryReply $ %{} 'CodeEntry
          :doc "|Typed cold read results, distinguishing missing content from denied access."
          :code $ quote $ defenum QueryReply (:history 'app.schema/HistoryPage) (:card-detail 'app.schema/CardDetail) (:missing 'String) (:denied 'String)
          :examples $ []
          :schema $ :: 'EnumDef
        'RemoveMessage $ %{} 'CodeEntry
          :doc "|Concrete payload for removing one session message."
          :code $ quote $ defstruct RemoveMessage (:id 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'Router $ %{} 'CodeEntry
          :doc "|The domain route stored for one session; target names the routed entity such as a board id."
          :code $ quote $ defstruct Router (:name 'Tag)
            :target $ :: 'Option 'String
          :examples $ []
          :schema $ :: 'StructDef
        'RouterView $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct RouterView (:name 'Tag)
            :target $ :: 'Option 'String
            :data $ :: 'Option $ :: 'Map 'Dynamic 'Dynamic
            :router $ :: 'Option $ :: 'Map 'Dynamic 'Dynamic
          :examples $ []
          :schema $ :: 'StructDef
        'ServerMessage $ %{} 'CodeEntry
          :doc "|Typed synchronization and effect messages sent to a browser. part/* messages carry partition epoch and revisions; query/reply answers one cold read by request id."
          :code $ quote $ defenum ServerMessage (:snapshot 'Number 'app.schema/Store)
            :patch 'Number 'Number $ :: 'List 'recollect.schema/change-op
            :effect/pong
            :part/snapshot 'app.schema/PartitionKey 'Number 'Number 'app.schema/PartitionView
            :part/patch 'app.schema/PartitionKey 'Number $ :: 'List 'app.schema/PartitionDelta
            :part/drop 'app.schema/PartitionKey
            :query/reply 'String 'app.schema/QueryReply
          :examples $ []
          :schema $ :: 'EnumDef
        'Session $ %{} 'CodeEntry (:doc "|A connected session in the nominal database.")
          :code $ quote $ defstruct Session
            :user-id $ :: 'Option 'String
            :id 'Number
            :nickname $ :: 'Option 'String
            :router $ quote app.schema/Router
            :messages $ :: 'Map 'String 'app.schema/Message
          :examples $ []
          :schema $ :: 'StructDef
        'SessionView $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct SessionView
            :user-id $ :: 'Option 'String
            :id $ :: 'Option 'Number
            :nickname $ :: 'Option 'String
            :router $ quote app.schema/RouterView
            :messages $ :: 'Map 'String $ quote app.schema/MessageView
          :examples $ []
          :schema $ :: 'StructDef
        'SharedTwig $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct SharedTwig (:reel-length 'Number)
            :attached $ quote app.schema/AttachedView
            :pages $ :: 'Option 'Map
            :members $ :: 'Map 'Number $ :: 'Option 'String
            :session-count 'Number
          :examples $ []
          :schema $ :: 'StructDef
        'Store $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct Store (:logged-in? 'Bool)
            :session $ quote app.schema/SessionView
            :reel-length 'Number
            :attached $ quote app.schema/AttachedView
            :user $ :: 'Option 'app.schema/UserView
            :router $ quote app.schema/RouterView
            :count 'Number
            :color 'String
          :examples $ []
          :schema $ :: 'StructDef
        'User $ %{} 'CodeEntry (:doc "|A persisted application user.")
          :code $ quote $ defstruct User (:name 'String) (:id 'String)
            :nickname $ :: 'Option 'String
            :avatar $ :: 'Option 'String
            :password 'String
          :examples $ []
          :schema $ :: 'StructDef
        'UserHotView $ %{} 'CodeEntry
          :doc "|Private hot partition of one user. history-rev only announces that cold history changed; events are fetched by query."
          :code $ quote $ defstruct UserHotView (:id 'String) (:name 'String)
            :settings $ quote app.schema/UserSettings
            :history-rev 'Number
          :examples $ []
          :schema $ :: 'StructDef
        'UserSettings $ %{} 'CodeEntry
          :doc "|Personal hot preferences synchronized to every connection of the same user."
          :code $ quote $ defstruct UserSettings (:compact? 'Bool) (:accent 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'UserView $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct UserView (:name 'String) (:id 'String)
            :nickname $ :: 'Option 'String
            :avatar $ :: 'Option 'String
          :examples $ []
          :schema $ :: 'StructDef
        'database $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def database
            %{} Db
              :sessions $ {}
              :users $ {}
              :boards $ {}
              :settings $ {}
          :examples $ []
          :schema $ :: 'app.schema/Db
        'decode-client-message $ %{} 'CodeEntry
          :doc "|Validate one untrusted client value and reconstruct a nominal ClientMessage; direct legacy Op enums remain accepted."
          :code $ quote $ defn decode-client-message (data)
            let
                message $ if (enum? data)
                  assoc data 0 $ turn-tag $ option:unwrap (nth data 0)
                  , data
              if (enum? message)
                match message
                  (:sync/active revision)
                    if (number? revision)
                      %:: Result :ok $ %:: ClientMessage :sync/active revision
                      invalid-message $ str "|Expected numeric active revision, got: " revision
                  (:sync/heartbeat revision)
                    if (number? revision)
                      %:: Result :ok $ %:: ClientMessage :sync/heartbeat revision
                      invalid-message $ str "|Expected numeric heartbeat revision, got: " revision
                  (:sync/idle revision)
                    if (number? revision)
                      %:: Result :ok $ %:: ClientMessage :sync/idle revision
                      invalid-message $ str "|Expected numeric idle revision, got: " revision
                  (:sync/resume revision)
                    if (number? revision)
                      %:: Result :ok $ %:: ClientMessage :sync/resume revision
                      invalid-message $ str "|Expected numeric resume revision, got: " revision
                  (:sync/ack revision)
                    if (number? revision)
                      %:: Result :ok $ %:: ClientMessage :sync/ack revision
                      invalid-message $ str "|Expected numeric acknowledgement revision, got: " revision
                  (:dispatch op)
                    match (decode-operation op)
                      (:ok typed-op)
                        %:: Result :ok $ %:: ClientMessage :dispatch typed-op
                      (:err error) (%:: Result :err error)
                  (:query request-id query)
                    if (string? request-id)
                      match (decode-query query)
                        (:ok typed-query)
                          Result :ok $ ClientMessage :query request-id typed-query
                        (:err error) (Result :err error)
                      invalid-message $ str "|Invalid query request id: " message
                  (:part/resync key)
                    match (decode-partition-key key)
                      (:ok typed-key)
                        Result :ok $ ClientMessage :part/resync typed-key
                      (:err error) (Result :err error)
                  (:part/ack key epoch revision)
                    match (decode-partition-key key)
                      (:ok typed-key)
                        if
                          and (number? epoch) (number? revision)
                          Result :ok $ ClientMessage :part/ack typed-key epoch revision
                          invalid-message $ str "|Invalid partition acknowledgement: " message
                      (:err error) (Result :err error)
                  _ $ match (decode-operation message)
                    (:ok typed-op)
                      %:: Result :ok $ %:: ClientMessage :dispatch typed-op
                    (:err error) (%:: Result :err error)
                invalid-message $ str "|Expected-enum-message: " message
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :return $ :: 'Result 'app.schema/ClientMessage 'app.schema/MessageDecodeError
          :tests $ []
            %{} 'TestEntry (:name |decodes-sync-control)
              :code $ quote $ assert=
                %:: Result :ok $ %:: ClientMessage :sync/ack 7
                decode-client-message $ :: :sync/ack 7
              :tags $ #{} :server
            %{} 'TestEntry (:name |accepts-legacy-direct-op)
              :code $ quote $ assert=
                %:: Result :ok $ %:: ClientMessage :dispatch $ %:: Op :effect/ping
                decode-client-message $ %:: Op :effect/ping
              :tags $ #{} :server
            %{} 'TestEntry (:name |rejects-invalid-revision)
              :code $ quote $ match
                decode-client-message $ :: :sync/active |bad
                (:err error)
                  match error $
                    :invalid detail
                    starts-with? detail "|Expected numeric active revision"
                _ false
              :tags $ #{} :server
            %{} 'TestEntry (:name |decodes-named-wire-operation)
              :code $ quote $ assert=
                %:: Result :ok $ %:: ClientMessage :dispatch $ %:: Op :effect/ping
                decode-client-message $ parse-cirru-edn "|%:: 'ClientMessage 'dispatch $ %:: 'Op 'effect/ping"
              :tags $ #{} :server
            %{} 'TestEntry (:name |rejects-non-enum-scalar)
              :code $ quote $ assert= true
                match (decode-client-message 42)
                  (:err _) true
                  _ false
              :tags $ #{} :client :server
            %{} 'TestEntry (:name |rejects-non-enum-map)
              :code $ quote $ assert= true
                match
                  decode-client-message $ {}
                  (:err _) true
                  _ false
              :tags $ #{} :client :server
            %{} 'TestEntry (:name |rejects-non-enum-list)
              :code $ quote $ assert= true
                match
                  decode-client-message $ [] :effect/ping
                  (:err _) true
                  _ false
              :tags $ #{} :client :server
            %{} 'TestEntry (:name |rejects-non-enum-dispatch-payload)
              :code $ quote $ assert= true
                match
                  decode-client-message $ :: :dispatch 42
                  (:err _) true
                  _ false
              :tags $ #{} :client :server
            %{} 'TestEntry (:name |decodes-partition-and-query-messages)
              :code $ quote $ do
                assert=
                  Result :ok $ ClientMessage :part/ack (PartitionKey :board |b1) 7 3
                  decode-client-message $ parse-cirru-edn $ format-cirru-edn
                    ClientMessage :part/ack (PartitionKey :board |b1) 7 3
                assert=
                  Result :ok $ ClientMessage :part/resync $ PartitionKey :lobby
                  decode-client-message $ parse-cirru-edn $ format-cirru-edn
                    ClientMessage :part/resync $ PartitionKey :lobby
                assert=
                  Result :ok $ ClientMessage :query |r1 $ Query :history (Option :some 4) 20
                  decode-client-message $ parse-cirru-edn $ format-cirru-edn
                    ClientMessage :query |r1 $ Query :history (Option :some 4) 20
                assert=
                  Result :ok $ ClientMessage :query |r2 $ Query :history (Option :none) 20
                  decode-client-message $ parse-cirru-edn $ format-cirru-edn
                    ClientMessage :query |r2 $ Query :history (Option :none) 20
                assert= true $ match
                  decode-client-message $ :: :part/ack (:: :board 42) 1 1
                  (:err _) true
                  _ false
                assert= true $ match
                  decode-client-message $ :: :query |r3 $ :: :card-detail |b1 7
                  (:err _) true
                  _ false
              :tags $ #{} :partition :server
        'decode-cold-store $ %{} 'CodeEntry
          :doc "|Validate persisted cold storage before it is used for queries."
          :code $ quote $ defn decode-cold-store (data)
            match
              try-decode-map-as (struct-tree-input data) 'app.schema/ColdStore
              (:ok store) (Result :ok store)
              (:err detail)
                Result :err $ %:: DatabaseDecodeError :invalid |cold detail
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :return $ :: 'Result 'app.schema/ColdStore 'app.schema/DatabaseDecodeError
        'decode-database $ %{} 'CodeEntry
          :doc "|Deeply validate a wire or legacy bare-map database and reconstruct nominal Db, Session, User, Router, and Message values."
          :code $ quote $ defn decode-database (data)
            let
                source $ if
                  = (type-of data) :struct
                  &struct:to-map data
                  , data
              if
                = (type-of source) :map
                let
                    sessions-data $ option:unwrap-or (get source :sessions) ({})
                    users-data $ option:unwrap-or (get source :users) ({})
                    boards-data $ option:unwrap-or (get source :boards) ({})
                    settings-data $ option:unwrap-or (get source :settings) ({})
                  match (decode-sessions sessions-data |db.sessions)
                    (:err error) (Result :err error)
                    (:ok sessions)
                      match (decode-users users-data |db.users)
                        (:err error) (Result :err error)
                        (:ok users)
                          match
                            try-decode-map-as (struct-tree-input boards-data) (:: 'Map 'String 'app.schema/Board)
                            (:err detail)
                              Result :err $ %:: DatabaseDecodeError :invalid |db.boards detail
                            (:ok boards)
                              match
                                try-decode-map-as (struct-tree-input settings-data) (:: 'Map 'String 'app.schema/UserSettings)
                                (:err detail)
                                  Result :err $ %:: DatabaseDecodeError :invalid |db.settings detail
                                (:ok settings)
                                  Result :ok $ %{} Db (:sessions sessions) (:users users) (:boards boards) (:settings settings)
                Result :err $ %:: DatabaseDecodeError :invalid |db "|Expected database map or struct"
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T
            :generics $ [] 'T
            :return $ :: 'Result 'app.schema/Db 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
          :tests $ []
            %{} 'TestEntry (:name |decodes-legacy-bare-map)
              :code $ quote $ let
                  legacy $ {}
                    :sessions $ {} $ 1
                      {} (:id 1) (:user-id |u1) (:nickname nil)
                        :router $ {} $ :name :profile
                        :messages $ {} $ |m1
                          {} (:id |m1) (:text |hello)
                    :users $ {} $ |u1
                      {} (:id |u1) (:name |demo) (:nickname nil) (:avatar nil) (:password |hash)
                match (decode-database legacy)
                  (:ok db)
                    do
                      assert= true $ &struct:matches? db Db
                      assert= true $ &struct:matches?
                        option:unwrap $ get (:sessions db) 1
                        , Session
                      assert= true $ &struct:matches?
                        option:unwrap $ get (:users db) |u1
                        , User
                  (:err error) (raise |Unexpected-decode-failure)
              :tags $ #{} :schema :server
            %{} 'TestEntry (:name |rejects-corrupt-nested-message)
              :code $ quote $ let
                  corrupt $ {}
                    :sessions $ {} $ 1
                      {} (:id 1)
                        :router $ {} $ :name :home
                        :messages $ {} $ |m1
                          {} (:id |m1) (:text 42)
                    :users $ {}
                assert=
                  Result :err $ %:: DatabaseDecodeError :invalid |db.sessions.1.messages.m1.text "|Expected String"
                  decode-database corrupt
              :tags $ #{} :schema :server
            %{} 'TestEntry (:name |rejects-corrupt-nested-user)
              :code $ quote $ let
                  corrupt $ {}
                    :sessions $ {}
                    :users $ {} $ |u1
                      {} (:id |u1) (:name |demo) (:password 42)
                assert=
                  Result :err $ %:: DatabaseDecodeError :invalid |db.users.u1.password "|Expected String"
                  decode-database corrupt
              :tags $ #{} :schema :server
            %{} 'TestEntry (:name |rejects-non-database-value)
              :code $ quote $ assert=
                Result :err $ DatabaseDecodeError :invalid |db "|Expected database map or struct"
                decode-database 42
              :tags $ #{} :server
            %{} 'TestEntry (:name |legacy-storage-gains-empty-kanban)
              :code $ quote $ match
                decode-database $ parse-cirru-edn "|{} (:users ({})) (:sessions ({}))"
                (:ok db)
                  do
                    assert= ({}) (:boards db)
                    assert= ({}) (:settings db)
                (:err error)
                  raise $ str |Expected-legacy-db: error
              :tags $ #{} :schema :server
            %{} 'TestEntry (:name |kanban-roundtrip-and-corrupt-card)
              :code $ quote $ let
                  card $ %{} Card (:id |c1) (:column-id |k1) (:rank 1) (:title |Ship) (:detail-rev 0) (:updated-at 10) (:updated-by |u1)
                  board $ %{} Board (:id |b1) (:title |Demo) (:created-at 1)
                    :columns $ {} $ |k1
                      %{} Column (:id |k1) (:title |Todo) (:rank 1)
                    :cards $ {} $ |c1 card
                  db $ %{} Db
                    :sessions $ {}
                    :users $ {}
                    :boards $ {} $ |b1 board
                    :settings $ {} $ |u1 default-settings
                  bad-rank $ parse-cirru-edn $ format-cirru-edn |high
                  corrupt $ struct-with db $ :boards
                    {} $ |b1 $ struct-with board
                      :cards $ {} $ |c1 (&struct:assoc card :rank bad-rank)
                assert= (Result :ok db)
                  decode-database $ parse-cirru-edn $ format-cirru-edn db
                match
                  decode-database $ parse-cirru-edn $ format-cirru-edn corrupt
                  (:ok _) (raise |Expected-corrupt-card-rejection)
                  (:err error)
                    match error $
                      :invalid path _detail
                      assert= |db.boards path
              :tags $ #{} :schema :server
        'decode-domain-operation $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn decode-domain-operation (data)
            if (enum? data)
              match (decode-operation data)
                (:err error) (Result :err error)
                (:ok op)
                  match op
                    (:session/connect)
                      Result :ok $ DomainOp :session/connect
                    (:session/disconnect)
                      Result :ok $ DomainOp :session/disconnect
                    (:session/remove-message message)
                      Result :ok $ DomainOp :session/remove-message message
                    (:user/log-in username password)
                      Result :ok $ DomainOp :user/log-in username password
                    (:user/sign-up username password)
                      Result :ok $ DomainOp :user/sign-up username password
                    (:user/log-out)
                      Result :ok $ DomainOp :user/log-out
                    (:router/change router)
                      Result :ok $ DomainOp :router/change router
                    (:kanban kanban-op)
                      Result :ok $ DomainOp :kanban kanban-op
                    _ $ invalid-message |Expected-domain-operation
              invalid-message |Expected-domain-operation
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :return $ :: 'Result 'app.schema/DomainOp 'app.schema/MessageDecodeError
          :tests $ []
            %{} 'TestEntry (:name |reconstructs-legacy-router-operation)
              :code $ quote $ assert=
                Result :ok $ DomainOp :router/change $ %{} Router (:name :profile)
                  :target $ Option :none
                decode-domain-operation $ :: :router/change $ {} (:name :profile)
              :tags $ #{} :server
            %{} 'TestEntry (:name |rejects-effects-and-scalars)
              :code $ quote $ do
                assert=
                  Result :err $ MessageDecodeError :invalid |Expected-domain-operation
                  decode-domain-operation $ :: :effect/persist
                assert=
                  Result :err $ MessageDecodeError :invalid |Expected-domain-operation
                  decode-domain-operation 42
              :tags $ #{} :server
        'decode-kanban-op $ %{} 'CodeEntry
          :doc "|Validate one untrusted Kanban operation payload before it reaches the reducer."
          :code $ quote $ defn decode-kanban-op (data)
            let
                op $ if (enum? data)
                  assoc data 0 $ turn-tag $ option:unwrap (nth data 0)
                  , data
                strings? $ fn (values)
                  hint-fn $ {}
                    :args $ [] $ :: 'List 'Dynamic
                    :return 'Bool
                  every? values string?
              if (enum? op)
                match op
                  (:board/create title)
                    if
                      strings? $ [] title
                      Result :ok $ KanbanOp :board/create title
                      invalid-message $ str "|Invalid board/create: " op
                  (:board/rename board-id title)
                    if
                      strings? $ [] board-id title
                      Result :ok $ KanbanOp :board/rename board-id title
                      invalid-message $ str "|Invalid board/rename: " op
                  (:column/add board-id title)
                    if
                      strings? $ [] board-id title
                      Result :ok $ KanbanOp :column/add board-id title
                      invalid-message $ str "|Invalid column/add: " op
                  (:card/add board-id column-id title)
                    if
                      strings? $ [] board-id column-id title
                      Result :ok $ KanbanOp :card/add board-id column-id title
                      invalid-message $ str "|Invalid card/add: " op
                  (:card/rename board-id card-id title)
                    if
                      strings? $ [] board-id card-id title
                      Result :ok $ KanbanOp :card/rename board-id card-id title
                      invalid-message $ str "|Invalid card/rename: " op
                  (:card/move board-id card-id column-id)
                    if
                      strings? $ [] board-id card-id column-id
                      Result :ok $ KanbanOp :card/move board-id card-id column-id
                      invalid-message $ str "|Invalid card/move: " op
                  (:card/shift board-id card-id step)
                    if
                      and
                        strings? $ [] board-id card-id
                        number? step
                      Result :ok $ KanbanOp :card/shift board-id card-id step
                      invalid-message $ str "|Invalid card/shift: " op
                  (:card/remove board-id card-id)
                    if
                      strings? $ [] board-id card-id
                      Result :ok $ KanbanOp :card/remove board-id card-id
                      invalid-message $ str "|Invalid card/remove: " op
                  (:card/edit-detail board-id card-id description)
                    if
                      strings? $ [] board-id card-id description
                      Result :ok $ KanbanOp :card/edit-detail board-id card-id description
                      invalid-message $ str "|Invalid card/edit-detail: " op
                  (:settings/toggle-compact)
                    Result :ok $ KanbanOp :settings/toggle-compact
                  (:settings/set-accent accent)
                    if (string? accent)
                      Result :ok $ KanbanOp :settings/set-accent accent
                      invalid-message $ str "|Invalid settings/set-accent: " op
                  _ $ invalid-message $ str "|Unknown Kanban operation: " op
                invalid-message $ str "|Expected-enum-kanban-op: " op
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :return $ :: 'Result 'app.schema/KanbanOp 'app.schema/MessageDecodeError
          :tests $ [] $ %{} 'TestEntry (:name |accepts-typed-and-rejects-bad-payloads)
            :code $ quote $ do
              assert=
                Result :ok $ KanbanOp :card/move |b1 |c1 |k2
                decode-kanban-op $ parse-cirru-edn "|%:: 'KanbanOp 'card/move |b1 |c1 |k2"
              assert=
                Result :ok $ KanbanOp :card/shift |b1 |c1 -1
                decode-kanban-op $ :: :card/shift |b1 |c1 -1
              assert= true $ match
                decode-kanban-op $ :: :card/shift |b1 |c1 |up
                (:err _) true
                _ false
              assert= true $ match
                decode-kanban-op $ :: :card/add |b1 42 |t
                (:err _) true
                _ false
              assert= true $ match (decode-kanban-op 42)
                (:err _) true
                _ false
            :tags $ #{} :client :schema :server
        'decode-message $ %{} 'CodeEntry (:doc "|Decode and validate one stored message.")
          :code $ quote $ defn decode-message (data path)
            let
                source $ if
                  = (type-of data) :struct
                  &struct:to-map data
                  , data
              if
                = (type-of source) :map
                match (get source :id)
                  (:none)
                    Result :err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected String"
                  (:some id)
                    if-not (string? id)
                      Result :err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected String"
                      match (get source :text)
                        (:none)
                          Result :err $ %:: DatabaseDecodeError :invalid (str path |.text) "|Expected String"
                        (:some text)
                          if (string? text)
                            Result :ok $ %{} Message (:id id) (:text text)
                            Result :err $ %:: DatabaseDecodeError :invalid (str path |.text) "|Expected String"
                Result :err $ %:: DatabaseDecodeError :invalid path "|Expected Message map or struct"
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T 'String
            :generics $ [] 'T
            :return $ :: 'Result 'app.schema/Message 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-messages $ %{} 'CodeEntry
          :doc "|Decode a keyed message collection and validate every nested value."
          :code $ quote $ defn decode-messages (data path)
            if-not
              = (type-of data) :map
              Result :err $ %:: DatabaseDecodeError :invalid path "|Expected message Map"
              foldl (&map:to-list data)
                assert-type
                  Result :ok $ {}
                  :: 'Result (:: 'Map 'String 'app.schema/Message) 'app.schema/DatabaseDecodeError
                fn (acc pair)
                  match acc
                    (:err error) (Result :err error)
                    (:ok messages)
                      let[] (id value) pair $ if-not (string? id)
                        Result :err $ %:: DatabaseDecodeError :invalid path "|Expected String message key"
                        let
                            decoded $ decode-message value $ str path |. id
                          match decoded
                            (:err error) (Result :err error)
                            (:ok message)
                              if
                                = id $ :id message
                                Result :ok $ assoc messages id message
                                Result :err $ %:: DatabaseDecodeError :invalid (str path |. id |.id) "|Message id must match map key"
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T 'String
            :generics $ [] 'T
            :return $ :: 'Result (:: 'Map 'String 'app.schema/Message) 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
          :tests $ [] $ %{} 'TestEntry (:name |rejects-mismatched-message-key)
            :code $ quote $ assert=
              Result :err $ %:: DatabaseDecodeError :invalid |messages.m1.id "|Message id must match map key"
              decode-messages
                {} $ |m1 $ {} (:id |m2) (:text |hello)
                , |messages
            :tags $ #{} :schema :server
        'decode-operation $ %{} 'CodeEntry
          :doc "|Reconstruct a nominal application Op from an untrusted or legacy enum value."
          :code $ quote $ defn decode-operation (data)
            let
                op $ if (enum? data)
                  assoc data 0 $ turn-tag $ option:unwrap (nth data 0)
                  , data
              if (enum? op)
                match op
                  (:session/connect)
                    Result :ok $ %:: Op :session/connect
                  (:session/disconnect)
                    Result :ok $ %:: Op :session/disconnect
                  (:session/remove-message message)
                    if
                      or
                        = (type-of message) :map
                        = (type-of message) :struct
                      let
                          source $ if
                            = (type-of message) :struct
                            &struct:to-map message
                            , message
                        match (get source :id)
                          (:none) (invalid-message "|Invalid remove-message id")
                          (:some id)
                            if (string? id)
                              Result :ok $ %:: Op :session/remove-message $ %{} RemoveMessage (:id id)
                              invalid-message $ str "|Invalid remove-message id: " id
                      invalid-message $ str "|Invalid remove-message payload: " message
                  (:user/log-in username password)
                    if
                      and (string? username) (string? password)
                      Result :ok $ %:: Op :user/log-in username password
                      invalid-message $ str "|Invalid log-in operation: " op
                  (:user/sign-up username password)
                    if
                      and (string? username) (string? password)
                      Result :ok $ %:: Op :user/sign-up username password
                      invalid-message $ str "|Invalid sign-up operation: " op
                  (:user/log-out)
                    Result :ok $ %:: Op :user/log-out
                  (:router/change router-data)
                    let
                        decoded-router $ decode-router router-data |operation.router
                      match decoded-router
                        (:ok typed-router)
                          Result :ok $ %:: Op :router/change typed-router
                        (:err error)
                          invalid-message $ str "|Invalid router operation: " error
                  (:effect/persist)
                    Result :ok $ %:: Op :effect/persist
                  (:effect/ping)
                    Result :ok $ %:: Op :effect/ping
                  (:effect/pong)
                    Result :ok $ %:: Op :effect/pong
                  (:effect/connect)
                    Result :ok $ %:: Op :effect/connect
                  (:reel/reset)
                    Result :ok $ %:: Op :reel/reset
                  (:reel/merge)
                    Result :ok $ %:: Op :reel/merge
                  (:states cursor state)
                    if (list? cursor)
                      Result :ok $ %:: Op :states cursor state
                      invalid-message |Expected-list-state-cursor
                  (:kanban kanban-op)
                    match (decode-kanban-op kanban-op)
                      (:ok typed)
                        Result :ok $ %:: Op :kanban typed
                      (:err error) (Result :err error)
                  (:client/open-card board-id card-id)
                    if
                      and (string? board-id) (string? card-id)
                      Result :ok $ %:: Op :client/open-card board-id card-id
                      invalid-message $ str "|Invalid open-card: " op
                  (:client/close-card card-id)
                    if (string? card-id)
                      Result :ok $ %:: Op :client/close-card card-id
                      invalid-message $ str "|Invalid close-card: " op
                  (:client/load-history append?)
                    if (bool? append?)
                      Result :ok $ %:: Op :client/load-history append?
                      invalid-message $ str "|Invalid load-history: " op
                  _ $ invalid-message $ str "|Unknown application operation: " op
                invalid-message $ str "|Expected-enum-message: " op
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :return $ :: 'Result 'app.schema/Op 'app.schema/MessageDecodeError
          :tests $ []
            %{} 'TestEntry (:name |decodes-concrete-domain-payloads)
              :code $ quote $ do
                assert=
                  Result :ok $ %:: Op :router/change $ %{} Router (:name :profile)
                    :target $ Option :none
                  decode-operation $ :: :router/change $ {} (:name :profile)
                assert=
                  Result :ok $ %:: Op :session/remove-message $ %{} RemoveMessage (:id |m1)
                  decode-operation $ :: :session/remove-message $ {} (:id |m1)
                match
                  decode-operation $ :: :router/change |profile
                  (:ok _) (raise |Expected-invalid-router-payload)
                  (:err _) &unit
                match
                  decode-operation $ :: :session/remove-message $ {} (:id 1)
                  (:ok _) (raise |Expected-invalid-remove-message-payload)
                  (:err _) &unit
              :tags $ #{} :protocol :schema
            %{} 'TestEntry (:name |accepts-mixed-state-cursor)
              :code $ quote $ assert=
                Result :ok $ Op :states ([] :field |id 7) ({})
                decode-operation $ :: :states ([] :field |id 7) ({})
              :tags $ #{} :client :server
            %{} 'TestEntry (:name |rejects-scalar-state-cursor)
              :code $ quote $ assert= true
                match
                  decode-operation $ :: :states 42 $ {}
                  (:err _) true
                  _ false
              :tags $ #{} :client :server
            %{} 'TestEntry (:name |rejects-non-enum-scalar)
              :code $ quote $ assert= true
                match (decode-operation 42)
                  (:err _) true
                  _ false
              :tags $ #{} :client :server
            %{} 'TestEntry (:name |rejects-non-enum-map)
              :code $ quote $ assert= true
                match
                  decode-operation $ {}
                  (:err _) true
                  _ false
              :tags $ #{} :client :server
            %{} 'TestEntry (:name |rejects-non-enum-list)
              :code $ quote $ assert= true
                match
                  decode-operation $ [] :effect/ping
                  (:err _) true
                  _ false
              :tags $ #{} :client :server
        'decode-optional-string $ %{} 'CodeEntry
          :doc "|Normalize a persisted optional string from missing, nil, legacy String, or nominal Option data."
          :code $ quote $ defn decode-optional-string (data path)
            hint-fn $ {}
              :generics $ [] 'T
              :args $ [] 'T 'String
              :return $ :: 'Result (:: 'Option 'String) 'app.schema/DatabaseDecodeError
            match data
              (:none)
                Result :ok $ Option :none
              (:some value)
                if (nil? value)
                  Result :ok $ Option :none
                  if (string? value)
                    Result :ok $ Option :some value
                    if
                      = (type-of value) :enum
                      match value
                        (:none)
                          Result :ok $ Option :none
                        (:some item)
                          if (string? item)
                            Result :ok $ Option :some item
                            Result :err $ %:: DatabaseDecodeError :invalid path "|Expected nil, String, or Option<String>"
                        _ $ Result :err $ %:: DatabaseDecodeError :invalid path "|Expected nil, String, or Option<String>"
                      Result :err $ %:: DatabaseDecodeError :invalid path "|Expected nil, String, or Option<String>"
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T 'String
            :generics $ [] 'T
            :return $ :: 'Result (:: 'Option 'String) 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-partition-key $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn decode-partition-key (data)
            let
                key $ if (enum? data)
                  assoc data 0 $ turn-tag $ option:unwrap (nth data 0)
                  , data
              if (enum? key)
                match key
                  (:lobby)
                    Result :ok $ PartitionKey :lobby
                  (:board id)
                    if (string? id)
                      Result :ok $ PartitionKey :board id
                      invalid-message $ str "|Invalid board partition: " key
                  (:user id)
                    if (string? id)
                      Result :ok $ PartitionKey :user id
                      invalid-message $ str "|Invalid user partition: " key
                  _ $ invalid-message $ str "|Unknown partition: " key
                invalid-message $ str "|Expected-enum-partition: " key
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :return $ :: 'Result 'app.schema/PartitionKey 'app.schema/MessageDecodeError
        'decode-query $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn decode-query (data)
            let
                query $ if (enum? data)
                  assoc data 0 $ turn-tag $ option:unwrap (nth data 0)
                  , data
              if (enum? query)
                match query
                  (:history cursor limit)
                    let
                        typed-cursor $ cond
                            nil? cursor
                            Option :some $ Option :none
                          (number? cursor)
                            Option :some $ Option :some cursor
                          (enum? cursor)
                            match cursor
                              (:none)
                                Option :some $ Option :none
                              (:some position)
                                if (number? position)
                                  Option :some $ Option :some position
                                  Option :none
                              _ $ Option :none
                          true $ Option :none
                      match typed-cursor
                        (:some valid-cursor)
                          if (number? limit)
                            Result :ok $ Query :history valid-cursor limit
                            invalid-message $ str "|Invalid history limit: " query
                        (:none)
                          invalid-message $ str "|Invalid history cursor: " query
                  (:card-detail board-id card-id)
                    if
                      and (string? board-id) (string? card-id)
                      Result :ok $ Query :card-detail board-id card-id
                      invalid-message $ str "|Invalid card-detail query: " query
                  _ $ invalid-message $ str "|Unknown query: " query
                invalid-message $ str "|Expected-enum-query: " query
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :return $ :: 'Result 'app.schema/Query 'app.schema/MessageDecodeError
        'decode-router $ %{} 'CodeEntry (:doc "|Decode and validate one stored route.")
          :code $ quote $ defn decode-router (data path)
            let
                source $ if
                  = (type-of data) :struct
                  &struct:to-map data
                  , data
              if
                = (type-of source) :map
                match (get source :name)
                  (:none)
                    Result :err $ %:: DatabaseDecodeError :invalid (str path |.name) "|Expected Tag"
                  (:some name)
                    if (tag? name)
                      match
                        decode-optional-string (get source :target) (str path |.target)
                        (:ok target)
                          Result :ok $ %{} Router (:name name) (:target target)
                        (:err error) (Result :err error)
                      Result :err $ %:: DatabaseDecodeError :invalid (str path |.name) "|Expected Tag"
                Result :err $ %:: DatabaseDecodeError :invalid path "|Expected Router map or struct"
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T 'String
            :generics $ [] 'T
            :return $ :: 'Result 'app.schema/Router 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-server-message $ %{} 'CodeEntry
          :doc "|Validate one untrusted server value and reconstruct a nominal ServerMessage."
          :code $ quote $ defn decode-server-message (data)
            let
                message $ if (enum? data)
                  assoc data 0 $ turn-tag $ option:unwrap (nth data 0)
                  , data
              if (enum? message)
                match message
                  (:snapshot revision store)
                    if (number? revision)
                      match (decode-store store)
                        (:ok validated)
                          %:: Result :ok $ %:: ServerMessage :snapshot revision validated
                        (:err detail)
                          invalid-message $ str "|Invalid snapshot envelope: " detail
                      invalid-message $ str "|Invalid snapshot envelope: " message
                  (:patch base-revision revision changes)
                    let
                        valid-changes? $ if (list? changes)
                          every? changes $ fn (change)
                            and (enum? change) (enum-definition-matches? change recollect.schema/change-op)
                          , false
                      if
                        and (number? base-revision) (number? revision) valid-changes?
                        match
                          try-decode-map-as changes $ :: 'List 'recollect.schema/change-op
                          (:ok validated)
                            Result :ok $ ServerMessage :patch base-revision revision validated
                          (:err detail)
                            invalid-message $ str "|Invalid patch envelope: " detail
                        invalid-message $ str "|Invalid patch envelope: " message
                  (:effect/pong)
                    %:: Result :ok $ %:: ServerMessage :effect/pong
                  (:query/reply _request-id _reply) (decode-typed-server-message message)
                  (:part/drop _key) (decode-typed-server-message message)
                  (:part/patch _key _epoch _deltas) (decode-typed-server-message message)
                  (:part/snapshot _key _epoch _revision _view) (decode-typed-server-message message)
                  _ $ invalid-message $ str "|Unknown server message: " message
                invalid-message $ str "|Unknown server message: " message
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :features $ #{} :js-ffi
            :return $ :: 'Result 'app.schema/ServerMessage 'app.schema/MessageDecodeError
          :tests $ []
            %{} 'TestEntry (:name |decodes-pong)
              :code $ quote $ assert=
                %:: Result :ok $ %:: ServerMessage :effect/pong
                decode-server-message $ :: :effect/pong
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-invalid-patch-payload)
              :code $ quote $ match
                decode-server-message $ :: :patch 1 2 :bad
                (:err error)
                  match error $
                    :invalid detail
                    starts-with? detail "|Invalid patch envelope"
                _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |decodes-named-wire-pong)
              :code $ quote $ assert=
                %:: Result :ok $ %:: ServerMessage :effect/pong
                decode-server-message $ parse-cirru-edn "|%:: 'ServerMessage 'effect/pong"
              :tags $ #{} :client
            %{} 'TestEntry (:name |validates-nominal-patch-list)
              :code $ quote $ assert=
                %:: Result :ok $ %:: ServerMessage :patch 3 4 $ [] (%:: recollect.schema/change-op :replace 1)
                decode-server-message $ %:: ServerMessage :patch 3 4 $ [] (%:: recollect.schema/change-op :replace 1)
              :tags $ #{} :client
            %{} 'TestEntry (:name |decodes-validated-store-snapshot)
              :code $ quote $ let
                  db app.schema/database
                  store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                assert=
                  Result :ok $ ServerMessage :snapshot 7 store
                  decode-server-message $ :: :snapshot 7 store
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-corrupt-nominal-store-snapshot)
              :code $ quote $ assert= true
                let
                    db app.schema/database
                    store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                  let
                      bad-session $ &struct:assoc (:session store) :id $ Option :some
                        parse-cirru-edn $ format-cirru-edn |not-a-number
                      corrupt $ &struct:assoc store :session bad-session
                    match
                      decode-server-message $ :: :snapshot 7 corrupt
                      (:err error)
                        match error $
                          :invalid detail
                          includes? detail |$.session.id
                      _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-non-enum-envelope)
              :code $ quote $ assert= true
                match (decode-server-message 42)
                  (:err error) true
                  _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-non-enum-patch-entry)
              :code $ quote $ assert= true
                match
                  decode-server-message $ :: :patch 1 2 $ [] 42
                  (:err error) true
                  _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-corrupt-nominal-patch-payload)
              :code $ quote $ assert= true
                match
                  decode-server-message $ :: :patch 1 2 $ []
                    &enum:assoc (%:: recollect.schema/change-op :vec-drop 1) 1 $ parse-cirru-edn $ format-cirru-edn |bad-count
                  (:err error) true
                  _ false
              :tags $ #{} :client
        'decode-session $ %{} 'CodeEntry (:doc "|Decode and deeply validate one stored session.")
          :code $ quote $ defn decode-session (data path)
            let
                source $ if
                  = (type-of data) :struct
                  &struct:to-map data
                  , data
              if
                = (type-of source) :map
                match (get source :id)
                  (:none)
                    Result :err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected Number"
                  (:some id)
                    if-not (number? id)
                      Result :err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected Number"
                      let
                          user-id-result $ decode-optional-string (get source :user-id) (str path |.user-id)
                          nickname-result $ decode-optional-string (get source :nickname) (str path |.nickname)
                          router-data $ option:unwrap-or (get source :router)
                            {} $ :name :home
                          messages-data $ option:unwrap-or (get source :messages) ({})
                          router-result $ decode-router router-data $ str path |.router
                          messages-result $ decode-messages messages-data $ str path |.messages
                        match user-id-result
                          (:err error) (Result :err error)
                          (:ok user-id)
                            match nickname-result
                              (:err error) (Result :err error)
                              (:ok nickname)
                                match router-result
                                  (:err error) (Result :err error)
                                  (:ok typed-router)
                                    match messages-result
                                      (:err error) (Result :err error)
                                      (:ok typed-messages)
                                        Result :ok $ %{} Session (:user-id user-id) (:id id) (:nickname nickname) (:router typed-router) (:messages typed-messages)
                Result :err $ %:: DatabaseDecodeError :invalid path "|Expected Session map or struct"
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T 'String
            :generics $ [] 'T
            :return $ :: 'Result 'app.schema/Session 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-sessions $ %{} 'CodeEntry
          :doc "|Decode a keyed session collection and validate every nested value."
          :code $ quote $ defn decode-sessions (data path)
            if-not
              = (type-of data) :map
              Result :err $ %:: DatabaseDecodeError :invalid path "|Expected session Map"
              foldl (&map:to-list data)
                assert-type
                  Result :ok $ {}
                  :: 'Result (:: 'Map 'Number 'app.schema/Session) 'app.schema/DatabaseDecodeError
                fn (acc pair)
                  match acc
                    (:err error) (Result :err error)
                    (:ok sessions)
                      let[] (id value) pair $ if-not (number? id)
                        Result :err $ %:: DatabaseDecodeError :invalid path "|Expected Number session key"
                        let
                            decoded $ decode-session value $ str path |. id
                          match decoded
                            (:err error) (Result :err error)
                            (:ok session)
                              if
                                = id $ :id session
                                Result :ok $ assoc sessions id session
                                Result :err $ %:: DatabaseDecodeError :invalid (str path |. id |.id) "|Session id must match map key"
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T 'String
            :generics $ [] 'T
            :return $ :: 'Result (:: 'Map 'Number 'app.schema/Session) 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
          :tests $ [] $ %{} 'TestEntry (:name |rejects-mismatched-session-key)
            :code $ quote $ assert=
              Result :err $ DatabaseDecodeError :invalid |sessions.1.id "|Session id must match map key"
              decode-sessions
                {} $ 1 $ {} (:id 2) (:user-id nil) (:nickname nil)
                  :router $ {} $ :name :home
                  :messages $ {}
                , |sessions
            :tags $ #{} :server
        'decode-store $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn decode-store (value)
            if
              and (struct? value) (&struct:matches? value Store)
              try-decode-map-as (store-struct-input value) 'app.schema/Store
              Result :err |Expected-nominal-Store
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Input
            :generics $ [] 'Input
            :return $ :: 'Result 'app.schema/Store 'String
          :tests $ []
            %{} 'TestEntry (:name |accepts-complete-nominal-store)
              :code $ quote $ let
                  db app.schema/database
                  store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                assert= (Result :ok store) (decode-store store)
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-invalid-root)
              :code $ quote $ assert= (Result :err |Expected-nominal-Store) (decode-store |wrong-root)
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-invalid-scalar-field)
              :code $ quote $ assert= true
                let
                    db app.schema/database
                    store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                  match
                    decode-store $ &struct:assoc store :count $ parse-cirru-edn (format-cirru-edn |not-a-number)
                    (:err detail) (includes? detail |$.count)
                    _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-invalid-nested-field)
              :code $ quote $ assert= true
                let
                    db app.schema/database
                    store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                  let
                      bad-session $ &struct:assoc (:session store) :id $ Option :some
                        parse-cirru-edn $ format-cirru-edn |not-a-number
                    match
                      decode-store $ &struct:assoc store :session bad-session
                      (:err detail) (includes? detail |$.session.id)
                      _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-invalid-optional-user)
              :code $ quote $ assert= true
                let
                    db app.schema/database
                    store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                  match
                    decode-store $ &struct:assoc store :user $ parse-cirru-edn (format-cirru-edn |not-an-option)
                    (:err detail) (includes? detail |$.user)
                    _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |preserves-open-router-payload)
              :code $ quote $ let
                  db app.schema/database
                  store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                let
                    payload $ {}
                      :heterogeneous $ [] 1 |text
                      :nominal $ :attached store
                    router $ %{} RouterView (:name :profile)
                      :target $ Option :none
                      :data $ Option :some payload
                      :router $ Option :none
                    updated $ &struct:assoc store :router router
                  assert= (Result :ok updated) (decode-store updated)
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-corrupt-message-field)
              :code $ quote $ assert= true
                let
                    db app.schema/database
                    store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                  let
                      message $ %{} MessageView (:id |m1) (:text |valid)
                      bad-message $ &struct:assoc message :text $ parse-cirru-edn (format-cirru-edn 42)
                      bad-session $ &struct:assoc (:session store) :messages $ {} (|m1 bad-message)
                    match
                      decode-store $ &struct:assoc store :session bad-session
                      (:err detail) (includes? detail |$.session.messages)
                      _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-corrupt-present-user)
              :code $ quote $ assert= true
                let
                    db app.schema/database
                    store $ app.twig.container/twig-container db app.schema/session $ app.twig.container/twig-shared db 0
                  let
                      user $ %{} UserView (:name |name) (:id |id)
                        :nickname $ Option :none
                        :avatar $ Option :none
                      bad-user $ &struct:assoc user :id $ parse-cirru-edn (format-cirru-edn 42)
                    match
                      decode-store $ &struct:assoc store :user $ Option :some bad-user
                      (:err detail) (includes? detail |$.user.id)
                      _ false
              :tags $ #{} :client
        'decode-typed-server-message $ %{} 'CodeEntry
          :doc "|Validate partition and query envelopes against the nominal ServerMessage schema after ws-edn class mapping; nested views, deltas and replies are checked field by field."
          :code $ quote $ defn decode-typed-server-message (message)
            match
              try-decode-map-as (struct-tree-input message) 'app.schema/ServerMessage
              (:ok typed) (Result :ok typed)
              (:err detail)
                invalid-message $ str "|Invalid server message: " detail
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :return $ :: 'Result 'app.schema/ServerMessage 'app.schema/MessageDecodeError
        'decode-user $ %{} 'CodeEntry (:doc "|Decode and validate one stored user.")
          :code $ quote $ defn decode-user (data path)
            let
                source $ if
                  = (type-of data) :struct
                  &struct:to-map data
                  , data
              if
                = (type-of source) :map
                match (get source :name)
                  (:none)
                    Result :err $ %:: DatabaseDecodeError :invalid (str path |.name) "|Expected String"
                  (:some name)
                    if-not (string? name)
                      Result :err $ %:: DatabaseDecodeError :invalid (str path |.name) "|Expected String"
                      match (get source :id)
                        (:none)
                          Result :err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected String"
                        (:some id)
                          if-not (string? id)
                            Result :err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected String"
                            let
                                nickname-result $ decode-optional-string (get source :nickname) (str path |.nickname)
                                avatar-result $ decode-optional-string (get source :avatar) (str path |.avatar)
                              match nickname-result
                                (:err error) (Result :err error)
                                (:ok nickname)
                                  match avatar-result
                                    (:err error) (Result :err error)
                                    (:ok avatar)
                                      match (get source :password)
                                        (:none)
                                          Result :err $ %:: DatabaseDecodeError :invalid (str path |.password) "|Expected String"
                                        (:some password)
                                          if (string? password)
                                            Result :ok $ %{} User (:name name) (:id id) (:nickname nickname) (:avatar avatar) (:password password)
                                            Result :err $ %:: DatabaseDecodeError :invalid (str path |.password) "|Expected String"
                Result :err $ %:: DatabaseDecodeError :invalid path "|Expected User map or struct"
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T 'String
            :generics $ [] 'T
            :return $ :: 'Result 'app.schema/User 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-users $ %{} 'CodeEntry
          :doc "|Decode a keyed user collection and validate every nested value."
          :code $ quote $ defn decode-users (data path)
            if-not
              = (type-of data) :map
              Result :err $ %:: DatabaseDecodeError :invalid path "|Expected user Map"
              foldl (&map:to-list data)
                assert-type
                  Result :ok $ {}
                  :: 'Result (:: 'Map 'String 'app.schema/User) 'app.schema/DatabaseDecodeError
                fn (acc pair)
                  match acc
                    (:err error) (Result :err error)
                    (:ok users)
                      let[] (id value) pair $ if-not (string? id)
                        Result :err $ %:: DatabaseDecodeError :invalid path "|Expected String user key"
                        let
                            decoded $ decode-user value $ str path |. id
                          match decoded
                            (:err error) (Result :err error)
                            (:ok user)
                              if
                                = id $ :id user
                                Result :ok $ assoc users id user
                                Result :err $ %:: DatabaseDecodeError :invalid (str path |. id |.id) "|User id must match map key"
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T 'String
            :generics $ [] 'T
            :return $ :: 'Result (:: 'Map 'String 'app.schema/User) 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
          :tests $ [] $ %{} 'TestEntry (:name |rejects-mismatched-user-key)
            :code $ quote $ assert=
              Result :err $ DatabaseDecodeError :invalid |users.u1.id "|User id must match map key"
              decode-users
                {} $ |u1 $ {} (:id |u2) (:name |demo) (:nickname nil) (:avatar nil) (:password |hash)
                , |users
            :tags $ #{} :server
        'default-settings $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def default-settings
            %{} UserSettings (:compact? false) (:accent |#2a8bd6)
          :examples $ []
          :schema $ :: 'app.schema/UserSettings
        'empty-cold-store $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def empty-cold-store
            %{} ColdStore
              :history $ {}
              :details $ {}
          :examples $ []
          :schema $ :: 'app.schema/ColdStore
        'enum-definition-matches? $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn enum-definition-matches? (value target)
            match (enum-definition value)
              (:none) false
              (:some found) (= found target)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Bool)
            :args $ [] 'Enum 'EnumDef
          :tests $ []
            %{} 'TestEntry (:name |matches-definition-across-option-variants)
              :code $ quote $ do
                assert= true $ enum-definition-matches? (Option :none) Option
                assert= true $ enum-definition-matches? (Option :some 1) Option
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-anonymous-and-foreign-same-tag)
              :code $ quote $ let
                  Foreign $ defenum Foreign (:none) (:some 'Dynamic)
                assert= false $ enum-definition-matches? (:: :none) Option
                assert= false $ enum-definition-matches? (%:: Foreign :none) Option
              :tags $ #{} :client
        'invalid-message $ %{} 'CodeEntry
          :doc "|Build a typed decode failure while preserving the expected success type."
          :code $ quote $ defn invalid-message (detail)
            %:: Result :err $ %:: MessageDecodeError :invalid detail
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'String
            :generics $ [] 'T
            :return $ :: 'Result 'T 'app.schema/MessageDecodeError
        'router $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def router
            %{} Router (:name :home)
              :target $ Option :none
          :examples $ []
          :schema $ :: 'app.schema/Router
        'session $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def session
            %{} Session
              :user-id $ Option :none
              :id 0
              :nickname $ Option :none
              :router router
              :messages $ {}
          :examples $ []
          :schema $ :: 'app.schema/Session
        'store-message-input $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn store-message-input (value)
            if (map? value)
              filter-map-kv
                decode-map-as value $ :: 'Map 'Dynamic 'Dynamic
                fn (key item)
                  hint-fn $ {}
                    :args $ [] 'Dynamic 'Dynamic
                    :return $ :: 'MapEntryDecision 'Dynamic 'Dynamic
                  MapEntryDecision :keep key $ store-struct-input item
              , value
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Dynamic)
            :args $ [] 'Dynamic
        'store-struct-input $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn store-struct-input (value)
            if (struct? value)
              cond
                  &struct:matches? value Store
                  -> (&struct:to-map value) (update :session store-struct-input) (update :attached store-struct-input) (update :router store-struct-input) (update :user store-user-input)
                (&struct:matches? value SessionView)
                  -> (&struct:to-map value) (update :router store-struct-input) (update :messages store-message-input)
                (or (&struct:matches? value RouterView) (&struct:matches? value UserView) (&struct:matches? value AttachedView) (&struct:matches? value MessageView))
                  &struct:to-map value
                true value
              , value
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Dynamic)
            :args $ [] 'Dynamic
        'store-user-input $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn store-user-input (value)
            if
              and (enum? value) (enum-definition-matches? value Option)
              match value
                (:some user)
                  Option :some $ store-struct-input user
                (:none) value
                _ value
              , value
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Dynamic)
            :args $ [] 'Dynamic
        'struct-tree-input $ %{} 'CodeEntry
          :doc "|Recursively turn untrusted struct trees, including struct payloads inside nominal enums, into maps so try-decode-map-as can validate them against a nominal schema."
          :code $ quote $ defn struct-tree-input (value)
            cond
                struct? value
                struct-tree-input $ &struct:to-map value
              (map? value)
                filter-map-kv
                  decode-map-as value $ :: 'Map 'Dynamic 'Dynamic
                  fn (key item)
                    hint-fn $ {}
                      :args $ [] 'Dynamic 'Dynamic
                      :return $ :: 'MapEntryDecision 'Dynamic 'Dynamic
                    MapEntryDecision :keep key $ struct-tree-input item
              (list? value)
                map
                  decode-map-as value $ :: 'List 'Dynamic
                  , struct-tree-input
              (enum? value)
                foldl
                  range 1 $ count value
                  , value $ fn (acc idx)
                    hint-fn $ {}
                      :args $ [] 'Dynamic 'Number
                      :return 'Dynamic
                    assoc acc idx $ struct-tree-input $ option:unwrap (nth value idx)
              true value
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Dynamic)
            :args $ [] 'Dynamic
          :tests $ [] $ %{} 'TestEntry (:name |nominal-enum-payloads-decode)
            :code $ quote $ let
                mapper $ {} (:Option Option) (:PartitionView PartitionView) (:Board Board) (:Column Column) (:Card Card)
                board $ %{} Board (:id |b1) (:title |T) (:created-at 1)
                  :columns $ {} $ |k
                    %{} Column (:id |k) (:title |K) (:rank 1)
                  :cards $ {}
                view $ PartitionView :board board
                raw $ parse-cirru-edn (format-cirru-edn view) mapper
                bad-title $ parse-cirru-edn $ format-cirru-edn 42
                bad $ parse-cirru-edn
                  format-cirru-edn $ PartitionView :board $ &struct:assoc board :title bad-title
                  , mapper
              assert= (Result :ok view)
                try-decode-map-as (struct-tree-input raw) 'app.schema/PartitionView
              assert= true $ match
                try-decode-map-as (struct-tree-input bad) 'app.schema/PartitionView
                (:err detail) (includes? detail |title)
                _ false
            :tags $ #{} :client :schema :server
        'user $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def user
            %{} User (:name ||) (:id ||)
              :nickname $ Option :none
              :avatar $ Option :none
              :password ||
          :examples $ []
          :schema $ :: 'app.schema/User
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.schema
    'app.server $ %{} 'FileEntry
      :defs $ {}
        '*client-caches $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *client-caches ({})
          :examples $ []
          :schema $ :: 'Ref $ :: 'Map 'Number 'Dynamic
        '*client-states $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *client-states ({})
          :examples $ []
          :schema $ :: 'Ref $ :: 'Map 'Number (:: 'Map 'Tag 'Dynamic)
        '*cold-store $ %{} 'CodeEntry
          :doc "|Cold history and card details. They are written by committed operations and read only through queries."
          :code $ quote $ defatom *cold-store
            if (path-exists? cold-storage-file)
              match
                read-cold-store $ read-file cold-storage-file
                (:ok store) store
                (:err error)
                  do (eprintln "|Invalid cold storage, starting empty:" error) schema/empty-cold-store
              , schema/empty-cold-store
          :examples $ []
          :schema $ :: 'Ref 'app.schema/ColdStore
        '*dirty-clients $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *dirty-clients (#{})
          :examples $ []
          :schema $ :: 'Ref $ :: 'Set 'Number
        '*dirty-partitions $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *dirty-partitions
            assert-type (#{}) (:: 'Set 'app.schema/PartitionKey)
          :examples $ []
          :schema $ :: 'Ref $ :: 'Set 'app.schema/PartitionKey
        '*initial-db $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *initial-db
            if
              path-exists? $ w-log storage-file
              do (println "|Found local EDN data")
                match
                  read-persisted-database $ read-file storage-file
                  (:ok db) db
                  (:err error)
                    do (eprintln "|Invalid persisted database, starting empty:" error) schema/database
              do (println "|Found no data") schema/database
          :examples $ []
          :schema $ :: 'Ref 'app.schema/Db
        '*partition-epoch $ %{} 'CodeEntry
          :doc "|Monotonic epoch source seeded from process start; a recreated partition never reuses an old revision lineage."
          :code $ quote $ defatom *partition-epoch (unix-time-ms)
          :examples $ []
          :schema $ :: 'Ref 'Number
        '*partition-metrics $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *partition-metrics empty-partition-metrics
          :examples $ []
          :schema $ :: 'Ref 'app.server/PartitionMetrics
        '*partition-payloads $ %{} 'CodeEntry
          :doc "|Encoded single-delta patch per partition, reused by every subscriber at the previous revision."
          :code $ quote $ defatom *partition-payloads
            assert-type ({}) (:: 'Map 'app.schema/PartitionKey 'app.server/CachedPayload)
          :examples $ []
          :schema $ :: 'Ref $ :: 'Map 'app.schema/PartitionKey 'app.server/CachedPayload
        '*partition-progress $ %{} 'CodeEntry
          :doc "|Per-connection subscription progress: acknowledged revision and pending send for each partition."
          :code $ quote $ defatom *partition-progress
            assert-type ({})
              :: 'Map 'Number $ :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress
          :examples $ []
          :schema $ :: 'Ref $ :: 'Map 'Number (:: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress)
        '*partitions $ %{} 'CodeEntry
          :doc "|Live partitions with at least one subscribed connection; each keeps one view, revision and bounded delta history."
          :code $ quote $ defatom *partitions
            assert-type ({}) (:: 'Map 'app.schema/PartitionKey 'app.partition/PartitionState)
          :examples $ []
          :schema $ :: 'Ref $ :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionState
        '*reader-reel $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *reader-reel @*reel
          :examples $ []
          :schema $ :: 'Dynamic
        '*reel $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *reel
            %{} cumulo-reel.core/ReelState (:base @*initial-db) (:db @*initial-db)
              :records $ []
              :merged? false
          :examples $ []
          :schema $ :: 'Ref $ :: 'cumulo-reel.core/ReelState 'app.schema/Db
        '*shared-twig-cache $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *shared-twig-cache
            {} (:revision -1) (:value nil)
          :examples $ []
          :schema $ :: 'Dynamic
        '*sync-metrics $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *sync-metrics
            %{} SyncMetrics (:last-diff-latency-ms 0) (:last-patch-bytes 0) (:last-snapshot-bytes 0) (:last-visited-nodes 0) (:last-emitted-ops 0) (:budget-fallback-count 0) (:pending-clients 0) (:slow-clients 0) (:resync-count 0) (:patch-attempts 0) (:snapshot-attempts 0) (:last-revision 0)
          :examples $ []
          :schema $ :: 'Dynamic
        '*sync-retry-scheduled? $ %{} 'CodeEntry
          :doc "|Whether a slower backpressure retry callback is pending."
          :code $ quote $ defatom *sync-retry-scheduled? false
          :examples $ []
          :schema $ :: 'Ref 'Bool
        '*sync-revision $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defatom *sync-revision 0
          :examples $ []
          :schema $ :: 'Ref 'Number
        '*sync-scheduled? $ %{} 'CodeEntry
          :doc "|Whether a fast coalesced server sync callback is pending."
          :code $ quote $ defatom *sync-scheduled? false
          :examples $ []
          :schema $ :: 'Ref 'Bool
        'CachedPayload $ %{} 'CodeEntry
          :doc "|Encoded latest single-delta patch of one partition lineage and revision."
          :code $ quote $ defstruct CachedPayload (:epoch 'Number) (:revision 'Number) (:payload 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'PartitionMetrics $ %{} 'CodeEntry
          :doc "|Partition sync counters. diffs counts partition diff computations, independent of subscriber count; sends count per-connection fan-out."
          :code $ quote $ defstruct PartitionMetrics (:advances 'Number) (:diffs 'Number) (:resets 'Number) (:snapshot-sends 'Number) (:delta-sends 'Number) (:reused-payloads 'Number) (:drops 'Number) (:queries 'Number) (:live-partitions 'Number)
          :examples $ []
          :schema $ :: 'StructDef
        'SyncDiffPlan $ %{} 'CodeEntry
          :doc "|Atomic server decision. Snapshot variants carry statistics and an optional budget reason but never partial changes."
          :code $ quote $ defenum SyncDiffPlan
            :snapshot 'recollect.diff/DiffStats $ :: 'Option 'recollect.diff/DiffBudgetReason
            :patch (:: 'List 'recollect.schema/change-op) 'recollect.diff/DiffStats
            :idle 'recollect.diff/DiffStats
          :examples $ []
          :schema $ :: 'EnumDef
        'SyncMetrics $ %{} 'CodeEntry
          :doc "|Application-level synchronization latency, wire-byte, deterministic diff-work, budget-fallback, revision, resync, pending-client, and slow-client metrics; pending and slow fields are gauges refreshed on read."
          :code $ quote $ defstruct SyncMetrics (:last-diff-latency-ms 'Number) (:last-patch-bytes 'Number) (:last-snapshot-bytes 'Number) (:last-visited-nodes 'Number) (:last-emitted-ops 'Number) (:budget-fallback-count 'Number) (:pending-clients 'Number) (:slow-clients 'Number) (:resync-count 'Number) (:patch-attempts 'Number) (:snapshot-attempts 'Number) (:last-revision 'Number)
          :examples $ []
          :schema $ :: 'StructDef
        'ack-partition! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn ack-partition! (sid key epoch revision)
            update-progress! sid $ fn (progress)
              match (get progress key)
                (:some current)
                  assoc progress key $ ack-partition-progress current epoch revision
                (:none) progress
            request-sync!
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'app.schema/PartitionKey 'Number 'Number
        'ack-partition-progress-for! $ %{} 'CodeEntry
          :doc "|Apply the acknowledgement a client sends after applying the given partition state's revision; used by ack-partition! and regression tests."
          :code $ quote $ defn ack-partition-progress-for! (sid state)
            update-progress! sid $ fn (progress)
              match
                get progress $ :key state
                (:some current)
                  assoc progress (:key state)
                    ack-partition-progress current (:epoch state) (:revision state)
                (:none) progress
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'app.partition/PartitionState
        'acknowledge-client! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn acknowledge-client! (sid revision)
            let
                state $ option:unwrap $ get @*client-states sid
              when
                = revision $ option:unwrap-or (get state :sent-rev) -1
                let
                    sent-store $ option:unwrap $ get state :sent-store
                  swap! *client-caches assoc sid sent-store
                swap! *client-states update sid $ fn (current) (next-sync-ack-state current revision)
                when
                  >
                    option:unwrap-or (get state :dirty-rev) 0
                    , revision
                  swap! *dirty-clients include sid
                  request-sync!
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'Number
        'assoc-client-state-field $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn assoc-client-state-field (states sid field value)
            assoc states sid $ assoc
              option:unwrap-or (get states sid) ({})
              , field value
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ []
              :: 'Map 'Number $ :: 'Map 'Tag 'Dynamic
              , 'Number 'Tag 'Dynamic
            :return $ :: 'Map 'Number $ :: 'Map 'Tag 'Dynamic
          :tests $ []
            %{} 'TestEntry
              :name |updates-one-client-without-changing-other-fields
              :code $ quote $ let
                  state $ {} (:status :active)
                    :opaque $ [] 1 |text
                    :dirty-rev 3
                  other $ {} $ :status :idle
                  states $ {} (1 state) (2 other)
                assert=
                  {}
                    1 $ {} (:status :active)
                      :opaque $ [] 1 |text
                      :dirty-rev 7
                    2 other
                  assoc-client-state-field states 1 :dirty-rev 7
                assert= (Option :some state) (get states 1)
              :tags $ #{} :server
            %{} 'TestEntry (:name |creates-missing-client-state-map)
              :code $ quote $ assert=
                {} $ 9 $ {} (:last-heartbeat 123)
                assoc-client-state-field ({}) 9 :last-heartbeat 123
              :tags $ #{} :server
        'cold-history-limit $ %{} 'CodeEntry
          :doc "|Per-user bound of the in-process cold history log used by this template."
          :code $ quote $ def cold-history-limit 2000
          :examples $ []
          :schema $ :: 'Number
        'cold-storage-file $ %{} 'CodeEntry
          :doc "|File holding cold history and card details, separate from the hot database snapshot."
          :code $ quote $ def cold-storage-file
            if (empty? calcit-dirname) |cold-storage.cirru $ str calcit-dirname |/cold-storage.cirru
          :examples $ []
          :schema $ :: 'String
        'collect-partitions! $ %{} 'CodeEntry
          :doc "|Reclaim partitions no connection subscribes to, bounding live partition count and memory; a later subscriber gets a fresh epoch."
          :code $ quote $ defn collect-partitions! ()
            let
                live $ foldl (.to-list @*partition-progress)
                  assert-type (#{}) (:: 'Set 'app.schema/PartitionKey)
                  fn (acc pair)
                    hint-fn $ {}
                      :args $ [] (:: 'Set 'app.schema/PartitionKey) 'Dynamic
                      :return $ :: 'Set 'app.schema/PartitionKey
                    let[] (_sid raw-progress) pair $ union acc $ keys
                      assert-type raw-progress $ :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress
              swap! *partitions $ fn (partitions)
                hint-fn $ {}
                  :args $ [] $ :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionState
                  :return $ :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionState
                .filter-map-kv partitions $ fn (key state)
                  hint-fn $ {}
                    :args $ [] 'app.schema/PartitionKey 'app.partition/PartitionState
                    :return $ :: 'MapEntryDecision 'app.schema/PartitionKey 'app.partition/PartitionState
                  if (includes? live key) (%:: MapEntryDecision :keep key state) (%:: MapEntryDecision :drop)
              , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'count-partition-event! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn count-partition-event! (kind)
            swap! *partition-metrics $ fn (m)
              hint-fn $ {}
                :args $ [] 'app.server/PartitionMetrics
                :return 'app.server/PartitionMetrics
              match kind
                :advance $ struct-with m $ :advances
                  inc $ :advances m
                :diff $ struct-with m $ :diffs
                  inc $ :diffs m
                :reset $ struct-with m $ :resets
                  inc $ :resets m
                :snapshot $ struct-with m $ :snapshot-sends
                  inc $ :snapshot-sends m
                :delta $ struct-with m $ :delta-sends
                  inc $ :delta-sends m
                :reuse $ struct-with m $ :reused-payloads
                  inc $ :reused-payloads m
                :drop $ struct-with m $ :drops
                  inc $ :drops m
                :query $ struct-with m $ :queries
                  inc $ :queries m
                _ m
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Tag
        'dispatch! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn dispatch! (op sid)
            let
                op-id $ generate-id!
                op-time $ now-ms
              if config/dev? $ println |Dispatch! (str op) sid
              match op
                (:effect/persist) (persist-db!)
                (:effect/ping)
                  wss-send! sid $ format-cirru-edn $ %:: schema/ServerMessage :effect/pong
                (:reel/reset)
                  do
                    reset! *reel $ struct-with @*reel
                      :db $ :base @*reel
                      :records $ []
                    mark-all-partitions-dirty!
                    request-sync!
                (:reel/merge)
                  do
                    reset! *reel $ struct-with @*reel
                      :base $ :db @*reel
                      :records $ []
                      :merged? true
                    mark-all-partitions-dirty!
                    request-sync!
                (:session/connect)
                  dispatch-domain! (%:: schema/DomainOp :session/connect) sid op-id op-time
                (:session/disconnect)
                  dispatch-domain! (%:: schema/DomainOp :session/disconnect) sid op-id op-time
                (:session/remove-message data)
                  dispatch-domain! (%:: schema/DomainOp :session/remove-message data) sid op-id op-time
                (:user/log-in username password)
                  dispatch-domain! (%:: schema/DomainOp :user/log-in username password) sid op-id op-time
                (:user/sign-up username password)
                  dispatch-domain! (%:: schema/DomainOp :user/sign-up username password) sid op-id op-time
                (:user/log-out)
                  dispatch-domain! (%:: schema/DomainOp :user/log-out) sid op-id op-time
                (:router/change data)
                  dispatch-domain! (%:: schema/DomainOp :router/change data) sid op-id op-time
                (:kanban kanban-op)
                  dispatch-domain! (%:: schema/DomainOp :kanban kanban-op) sid op-id op-time
                _ $ do (eprintln "|Ignoring client-local operation on server:" op) &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Dynamic)
            :args $ [] 'app.schema/Op 'Number
          :tests $ [] $ %{} 'TestEntry (:name |reset-and-merge-preserve-reel-boundaries)
            :code $ quote $ let
                saved-reel @*reel
                saved-scheduled? @*sync-scheduled?
                base $ %{} schema/Db
                  :sessions $ {}
                  :users $ {}
                  :boards $ {}
                  :settings $ {}
                current $ struct-with base $ :users
                  {} $ |one schema/user
                fixture $ %{} cumulo-reel.core/ReelState (:base base) (:db current)
                  :records $ [] $ [] |record
                  :merged? false
              do (reset! *sync-scheduled? true) (reset! *reel fixture)
                dispatch! (%:: schema/Op :reel/reset) 0
                let
                    reset-result @*reel
                  do (reset! *reel fixture)
                    dispatch! (%:: schema/Op :reel/merge) 0
                    let
                        merge-result @*reel
                      do (reset! *reel saved-reel) (reset! *sync-scheduled? saved-scheduled?)
                        assert= base $ :db reset-result
                        assert= base $ :base reset-result
                        assert= ([]) (:records reset-result)
                        assert= false $ :merged? reset-result
                        assert= current $ :db merge-result
                        assert= current $ :base merge-result
                        assert= ([]) (:records merge-result)
                        assert= true $ :merged? merge-result
            :tags $ #{} :server
        'dispatch-domain! $ %{} 'CodeEntry
          :doc "|Commit one domain operation to hot state, append its cold effects, then mark only the partitions it can affect before publication."
          :code $ quote $ defn dispatch-domain! (op sid op-id op-time)
            let
                db-before $ reel-db @*reel
              reset! *reel $ reel-reducer @*reel updater op sid op-id op-time config/dev?
              match op
                (:kanban kanban-op)
                  swap! *cold-store $ fn (cold)
                    hint-fn $ {}
                      :args $ [] 'app.schema/ColdStore
                      :return 'app.schema/ColdStore
                    apply-cold-effects cold
                      kanban-effects db-before (reel-db @*reel) kanban-op sid op-id op-time
                      , cold-history-limit
                _ &unit
              mark-partitions-dirty! $ affected-partitions db-before op sid
              request-sync!
              , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.schema/DomainOp 'Number 'String 'Number
        'empty-diff-stats $ %{} 'CodeEntry
          :doc "|Zero work statistics used when an existing recovery state already requires a snapshot and no diff runs."
          :code $ quote $ def empty-diff-stats
            %{} DiffStats (:visited-nodes 0) (:emitted-ops 0)
          :examples $ []
          :schema $ :: 'recollect.diff/DiffStats
        'empty-partition-metrics $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def empty-partition-metrics
            %{} PartitionMetrics (:advances 0) (:diffs 0) (:resets 0) (:snapshot-sends 0) (:delta-sends 0) (:reused-payloads 0) (:drops 0) (:queries 0) (:live-partitions 0)
          :examples $ []
          :schema $ :: 'app.server/PartitionMetrics
        'ensure-partition! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn ensure-partition! (db cold key)
            when
              option:none? $ get @*partitions key
              swap! *partitions assoc key $ new-partition key (next-partition-epoch!) (project-partition db cold key)
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.schema/Db 'app.schema/ColdStore 'app.schema/PartitionKey
        'get-backup-path! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn get-backup-path! ()
            join-path calcit-dirname |backups $ str (unix-time-ms) |-snapshot.cirru
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ []
        'get-shared-twig $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn get-shared-twig (reel revision)
            let
                cached @*shared-twig-cache
              if
                = revision $ option:unwrap $ get cached :revision
                option:unwrap $ get cached :value
                let
                    value $ twig-shared (reel-db reel) (reel-record-count reel)
                  reset! *shared-twig-cache $ {} (:revision revision) (:value value)
                  , value
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/SharedTwig)
            :args $ [] (:: 'cumulo-reel.core/ReelState 'app.schema/Db) 'Number
        'handle-client-message! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn handle-client-message! (message sid)
            match message
              (:sync/active client-revision) (mark-client-active! sid client-revision false)
              (:sync/heartbeat client-revision)
                do (touch-client! sid client-revision)
                  wss-send! sid $ format-cirru-edn $ %:: schema/ServerMessage :effect/pong
                  , &unit
              (:sync/idle client-revision) (mark-client-idle! sid client-revision)
              (:sync/resume client-revision)
                do (record-resync!) (mark-client-active! sid client-revision true)
              (:sync/ack revision) (acknowledge-client! sid revision)
              (:dispatch op) (dispatch! op sid)
              (:query request-id query) (handle-query! sid request-id query)
              (:part/resync key) (resync-partition! sid key)
              (:part/ack key epoch revision) (ack-partition! sid key epoch revision)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.schema/ClientMessage 'Number
        'handle-partition-send! $ %{} 'CodeEntry
          :doc "|Only an accepted send records a pending revision; backpressure retries later from the unchanged acknowledged baseline."
          :code $ quote $ defn handle-partition-send! (sid state outcome)
            match outcome
              (:accepted)
                update-progress! sid $ fn (progress)
                  assoc progress (:key state)
                    mark-partition-sent state $ get progress $ :key state
              (:backpressured)
                do (swap! *dirty-clients include sid) (request-sync-retry!)
              (:too-large)
                do
                  eprintln "|Partition payload is too large for client:" sid $ :key state
                  , &unit
              (:closed) &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'app.partition/PartitionState 'wss.core/WssSendOutcome
        'handle-query! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn handle-query! (sid request-id query) (count-partition-event! :query)
            wss-send! sid $ format-cirru-edn $ schema/ServerMessage :query/reply request-id
              query-reply (reel-db @*reel) @*cold-store sid query
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'String 'app.schema/Query
        'handle-sync-send! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn handle-sync-send! (sid revision new-store outcome)
            swap! *client-states update sid $ fn (current) (next-sync-send-state current revision new-store outcome)
            match outcome
              (:accepted) &unit
              (:backpressured)
                do (swap! *dirty-clients include sid) (request-sync-retry!)
              (:too-large) (println "|WebSocket sync payload is too large for client:" sid)
              (:closed) &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'Number 'app.schema/Store 'wss.core/WssSendOutcome
        'heartbeat-timeout $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def heartbeat-timeout 12000
          :examples $ []
          :schema $ :: 'Dynamic
        'invalidate-sync-caches! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn invalidate-sync-caches! ()
            reset! *shared-twig-cache $ {} (:revision -1) (:value nil)
            reset! *client-caches $ {}
            each (keys @*client-states)
              fn (sid)
                swap! *client-states update sid $ fn (state)
                  dissoc
                    merge state $ {} (:needs-snapshot? true) (:in-flight? false)
                    , :sent-rev :sent-store
                when
                  = :active $ option:unwrap $ get
                    option:unwrap $ get @*client-states sid
                    , :status
                  swap! *dirty-clients include sid
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'main! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn main! ()
            do
              println "|Running mode:" $ if config/dev? |dev |release
              let
                  port $ resolve-port
                do (run-server! port)
                  println $ str "|Server started on port:" port
              do
                ; "|Initialize lazy definitions before starting background callbacks."
                identity @*reader-reel
              set-interval 5000 $ fn () $ sweep-idle-clients!
              set-interval 600000 $ fn () $ persist-db!
              on-control-c on-exit!
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'mark-all-partitions-dirty! $ %{} 'CodeEntry
          :doc "|Used when the whole database may have changed (reel reset/merge, hot reload)."
          :code $ quote $ defn mark-all-partitions-dirty! ()
            mark-partitions-dirty! $ keys @*partitions
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'mark-client-active! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn mark-client-active! (sid client-revision force-snapshot?)
            let
                state $ option:unwrap-or (get @*client-states sid) ({})
                resumed? $ or force-snapshot? $ not= :active
                  option:unwrap-or (get state :status) :idle
                next-state-base $ merge
                  {} (:status :active)
                    :last-heartbeat $ now-ms
                    :acked-rev client-revision
                    :dirty-rev @*sync-revision
                    :in-flight? false
                    :needs-snapshot? true
                  , state $ {} (:status :active)
                    :last-heartbeat $ now-ms
                    :acked-rev $ if resumed? client-revision $ option:unwrap-or (get state :acked-rev) client-revision
                    :in-flight? $ if resumed? false $ option:unwrap-or (get state :in-flight?) false
                    :needs-snapshot? $ or resumed? $ option:unwrap-or (get state :needs-snapshot?) false
                next-state $ if resumed? (dissoc next-state-base :sent-rev :sent-store) next-state-base
              swap! *client-states assoc sid next-state
              when resumed? (swap! *client-caches remove-client-cache sid) (swap! *dirty-clients include sid) (release-partition-sends! sid) (request-sync!)
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'Number 'Bool
        'mark-client-idle! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn mark-client-idle! (sid client-revision)
            when
              option:some? $ get @*client-states sid
              swap! *client-states update sid $ fn (state)
                dissoc
                  merge state $ {} (:status :idle) (:acked-rev client-revision) (:in-flight? false) (:needs-snapshot? true)
                  , :sent-rev :sent-store
              swap! *client-caches remove-client-cache sid
              swap! *dirty-clients remove-dirty-client sid
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'Number
        'mark-clients-dirty! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn mark-clients-dirty! (revision)
            each (keys @*client-states)
              fn (sid)
                let
                    state $ option:unwrap $ get @*client-states sid
                  swap! *client-states assoc-client-state-field sid :dirty-rev revision
                  when
                    = :active $ option:unwrap $ get state :status
                    swap! *dirty-clients include sid
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number
        'mark-partitions-dirty! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn mark-partitions-dirty! (partition-keys)
            swap! *dirty-partitions $ fn (dirty)
              hint-fn $ {}
                :args $ [] $ :: 'Set 'app.schema/PartitionKey
                :return $ :: 'Set 'app.schema/PartitionKey
              union dirty partition-keys
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] $ :: 'Set 'app.schema/PartitionKey
        'next-partition-epoch! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn next-partition-epoch! () (swap! *partition-epoch inc) @*partition-epoch
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Number)
            :args $ []
        'next-sync-ack-state $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn next-sync-ack-state (current revision)
            dissoc
              merge current $ {} (:acked-rev revision) (:in-flight? false)
              , :sent-rev :sent-store
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'Map 'Tag 'Dynamic) 'Number
            :return $ :: 'Map 'Tag 'Dynamic
          :tests $ []
            %{} 'TestEntry
              :name |repeated-backpressure-converges-to-latest-revision
              :code $ quote $ let
                  initial $ {} (:status :active) (:acked-rev 3) (:dirty-rev 4) (:in-flight? false) (:needs-snapshot? false)
                  after-first-backpressure $ next-sync-send-state initial 4
                    {} $ :value 4
                    %:: wss.core/WssSendOutcome :backpressured
                  after-latest-backpressure $ next-sync-send-state (assoc after-first-backpressure :dirty-rev 7) 7
                    {} $ :value 7
                    %:: wss.core/WssSendOutcome :backpressured
                  accepted-latest $ next-sync-send-state (assoc after-latest-backpressure :dirty-rev 9) 9
                    {} $ :value 9
                    %:: wss.core/WssSendOutcome :accepted
                assert=
                  {} (:status :active) (:acked-rev 9) (:dirty-rev 9) (:in-flight? false) (:needs-snapshot? false) (:slow-client? false) (:last-send-outcome :accepted)
                  next-sync-ack-state accepted-latest 9
              :tags $ #{} :server
            %{} 'TestEntry (:name |preserves-extra-state-fields)
              :code $ quote $ let
                  extra $ {} $ :heterogeneous ([] 1 |text)
                  current $ {} (:opaque extra) (:status :active) (:sent-rev 7)
                    :sent-store $ [] |pending
                    :in-flight? true
                assert=
                  {} (:opaque extra) (:status :active) (:acked-rev 7) (:in-flight? false)
                  next-sync-ack-state current 7
              :tags $ #{} :server
        'next-sync-metrics $ %{} 'CodeEntry
          :doc "|Purely advance synchronization counters for one attempted snapshot or patch send."
          :code $ quote $ defn next-sync-metrics (metrics message-kind revision diff-latency payload stats budget-fallback?)
            struct-with metrics (:last-diff-latency-ms diff-latency)
              :last-patch-bytes $ if (= message-kind :patch) payload.utf8-byte-count $ :last-patch-bytes metrics
              :last-snapshot-bytes $ if (= message-kind :snapshot) payload.utf8-byte-count $ :last-snapshot-bytes metrics
              :last-visited-nodes $ :visited-nodes stats
              :last-emitted-ops $ :emitted-ops stats
              :budget-fallback-count $ if
                and budget-fallback? $ not= revision $ :last-revision metrics
                inc $ :budget-fallback-count metrics
                :budget-fallback-count metrics
              :patch-attempts $ if (= message-kind :patch)
                inc $ :patch-attempts metrics
                :patch-attempts metrics
              :snapshot-attempts $ if (= message-kind :snapshot)
                inc $ :snapshot-attempts metrics
                :snapshot-attempts metrics
              :last-revision revision
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.server/SyncMetrics)
            :args $ [] 'app.server/SyncMetrics 'Tag 'Number 'Number 'String 'recollect.diff/DiffStats 'Bool
          :tests $ [] $ %{} 'TestEntry (:name |advances-patch-and-snapshot-counters)
            :code $ quote $ let
                initial $ %{} SyncMetrics (:last-diff-latency-ms 0) (:last-patch-bytes 0) (:last-snapshot-bytes 0) (:last-visited-nodes 0) (:last-emitted-ops 0) (:budget-fallback-count 0) (:pending-clients 0) (:slow-clients 0) (:resync-count 0) (:patch-attempts 0) (:snapshot-attempts 0) (:last-revision 0)
                patch-stats $ %{} DiffStats (:visited-nodes 7) (:emitted-ops 3)
                snapshot-stats $ %{} DiffStats (:visited-nodes 9) (:emitted-ops 4)
                after-patch $ next-sync-metrics initial :patch 7 3 "|A😀" patch-stats false
                after-fallback $ next-sync-metrics after-patch :snapshot 8 2 |ignored snapshot-stats true
                after-retry $ next-sync-metrics after-fallback :snapshot 8 2 |ignored snapshot-stats true
              do
                assert=
                  %{} SyncMetrics (:last-diff-latency-ms 2) (:last-patch-bytes 5) (:last-snapshot-bytes 7) (:last-visited-nodes 9) (:last-emitted-ops 4) (:budget-fallback-count 1) (:pending-clients 0) (:slow-clients 0) (:resync-count 0) (:patch-attempts 1) (:snapshot-attempts 1) (:last-revision 8)
                  , after-fallback
                assert= 1 $ :budget-fallback-count after-retry
                assert= 2 $ :budget-fallback-count $ next-sync-metrics after-retry :snapshot 9 2 |ignored snapshot-stats true
            :tags $ #{} :server
        'next-sync-send-state $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn next-sync-send-state (current revision new-store outcome)
            match outcome
              (:accepted)
                merge current $ {} (:sent-rev revision) (:sent-store new-store) (:in-flight? true) (:needs-snapshot? false) (:slow-client? false) (:last-send-outcome :accepted)
              (:backpressured)
                merge current $ {}
                  :dirty-rev $ let
                      current-dirty $ option:unwrap-or (get current :dirty-rev) 0
                    if (> revision current-dirty) revision current-dirty
                  :slow-client? true
                  :last-send-outcome :backpressured
              (:too-large)
                merge current $ {} (:needs-snapshot? true) (:slow-client? true) (:last-send-outcome :too-large)
              (:closed)
                dissoc
                  merge current $ {} (:status :idle) (:in-flight? false) (:last-send-outcome :closed)
                  , :sent-rev :sent-store
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'Map 'Tag 'Dynamic) 'Number 'U 'wss.core/WssSendOutcome
            :generics $ [] 'U
            :return $ :: 'Map 'Tag 'Dynamic
          :tests $ []
            %{} 'TestEntry (:name |accepted-records-pending-store)
              :code $ quote $ assert=
                {} (:status :active) (:sent-rev 7)
                  :sent-store $ {} $ :value 1
                  :in-flight? true
                  :needs-snapshot? false
                  :slow-client? false
                  :last-send-outcome :accepted
                next-sync-send-state
                  {} $ :status :active
                  , 7
                    {} $ :value 1
                    %:: wss.core/WssSendOutcome :accepted
              :tags $ #{} :server
            %{} 'TestEntry (:name |oversized-payload-requires-snapshot)
              :code $ quote $ assert=
                {} (:status :active) (:needs-snapshot? true) (:slow-client? true) (:last-send-outcome :too-large)
                next-sync-send-state
                  {} $ :status :active
                  , 7
                    {} $ :value 1
                    %:: wss.core/WssSendOutcome :too-large
              :tags $ #{} :server
            %{} 'TestEntry (:name |closed-clears-pending-send)
              :code $ quote $ assert=
                {} (:status :idle) (:in-flight? false) (:last-send-outcome :closed)
                next-sync-send-state
                  {} (:status :active) (:in-flight? true) (:sent-rev 7)
                    :sent-store $ {} $ :value 1
                  , 7
                    {} $ :value 1
                    %:: wss.core/WssSendOutcome :closed
              :tags $ #{} :server
            %{} 'TestEntry (:name |backpressure-preserves-latest-dirty-revision)
              :code $ quote $ assert=
                {} (:status :active) (:acked-rev 5) (:dirty-rev 7) (:slow-client? true) (:last-send-outcome :backpressured)
                next-sync-send-state
                  {} (:status :active) (:acked-rev 5) (:dirty-rev 6)
                  , 7
                    {} $ :value 1
                    %:: wss.core/WssSendOutcome :backpressured
              :tags $ #{} :server
            %{} 'TestEntry (:name |preserves-extra-fields-and-newer-dirty-revision)
              :code $ quote $ let
                  extra $ {} $ :heterogeneous ([] 1 |text)
                  current $ {} (:opaque extra) (:status :active) (:dirty-rev 12)
                assert=
                  {} (:opaque extra) (:status :active) (:dirty-rev 12) (:slow-client? true) (:last-send-outcome :backpressured)
                  next-sync-send-state current 7 ([] |new-store) (wss.core/WssSendOutcome :backpressured)
              :tags $ #{} :server
        'now-ms $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn now-ms () (unix-time-ms)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Number)
            :args $ []
        'on-exit! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn on-exit! () (persist-db!) (; println "|exit code is...") (quit! 0)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Dynamic)
            :args $ []
        'partition-history-limit $ %{} 'CodeEntry
          :doc "|Retained deltas per partition; slower subscribers fall back to one bounded partition snapshot."
          :code $ quote $ def partition-history-limit 32
          :examples $ []
          :schema $ :: 'Number
        'partition-patch-payload $ %{} 'CodeEntry
          :doc "|Encode the latest single-delta patch once per partition revision; longer catch-up chains are encoded per send."
          :code $ quote $ defn partition-patch-payload (state deltas)
            let
                key $ :key state
                encode! $ fn ()
                  hint-fn $ {}
                    :args $ []
                    :return 'String
                  let
                      payload $ format-cirru-edn $ schema/ServerMessage :part/patch key (:epoch state) deltas
                    when
                      = 1 $ count deltas
                      swap! *partition-payloads assoc key $ %{} CachedPayload
                        :epoch $ :epoch state
                        :revision $ :revision state
                        :payload payload
                    , payload
              match (get @*partition-payloads key)
                (:some cached)
                  if
                    and
                      = 1 $ count deltas
                      = (:epoch cached) (:epoch state)
                      = (:revision cached) (:revision state)
                    do (count-partition-event! :reuse) (:payload cached)
                    encode!
                (:none) (encode!)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ [] 'app.partition/PartitionState $ :: 'List 'app.schema/PartitionDelta
        'patch-operation-limit $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def patch-operation-limit 64
          :examples $ []
          :schema $ :: 'Dynamic
        'persist-db! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn persist-db! ()
            let
                file-content $ format-cirru-edn $ struct-with (reel-db @*reel)
                  :sessions $ {}
                storage-path storage-file
                backup-path $ get-backup-path!
              do (check-write-file! storage-path file-content) (check-write-file! backup-path file-content)
                check-write-file! cold-storage-file $ format-cirru-edn @*cold-store
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'progress-of $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn progress-of (sid)
            match (get @*partition-progress sid)
              (:some progress) progress
              (:none)
                assert-type ({}) (:: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Number
            :return $ :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress
        'query-reply $ %{} 'CodeEntry
          :doc "|Answer one cold read using the session identity; history is always the caller's own."
          :code $ quote $ defn query-reply (db cold sid query)
            match (session-user-id db sid)
              (:none) (schema/QueryReply :denied |login-required)
              (:some user-id)
                match query
                  (:history cursor limit)
                    schema/QueryReply :history $ history-page cold user-id cursor limit
                  (:card-detail board-id card-id) (card-detail-reply db cold board-id card-id)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/QueryReply)
            :args $ [] 'app.schema/Db 'app.schema/ColdStore 'Number 'app.schema/Query
          :tests $ [] $ %{} 'TestEntry (:name |identity-comes-from-session)
            :code $ quote $ let
                db $ app.updater.kanban/apply-kanban app.updater.kanban/fixture-db (schema/KanbanOp :board/create |Plan) 1 |b1 1
                cold $ apply-cold-effects schema/empty-cold-store
                  kanban-effects app.updater.kanban/fixture-db db (schema/KanbanOp :board/create |Plan) 1 |b1 1
                  , 100
              assert= (schema/QueryReply :denied |login-required)
                query-reply db cold 2 $ schema/Query :history (Option :none) 10
              match
                query-reply db cold 1 $ schema/Query :history (Option :none) 10
                (:history page)
                  assert= 1 $ :history-rev page
                _ $ raise |Expected-history-page
            :tags $ #{} :kanban :server
        'read-cold-store $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn read-cold-store (content)
            try
              schema/decode-cold-store $ parse-cirru-edn content
              fn (error)
                Result :err $ %:: schema/DatabaseDecodeError :invalid |cold $ str "|Malformed cold Cirru EDN: " error
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'String
            :return $ :: 'Result 'app.schema/ColdStore 'app.schema/DatabaseDecodeError
          :tests $ [] $ %{} 'TestEntry (:name |rejects-malformed-and-roundtrips)
            :code $ quote $ do
              assert= true $ match (read-cold-store "|{} (:history")
                (:err _) true
                _ false
              assert= (Result :ok schema/empty-cold-store)
                read-cold-store $ format-cirru-edn schema/empty-cold-store
            :tags $ #{} :kanban :server
        'read-partition-metrics $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn read-partition-metrics ()
            struct-with @*partition-metrics $ :live-partitions $ count @*partitions
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.server/PartitionMetrics)
            :args $ []
        'read-persisted-database $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn read-persisted-database (content)
            try
              schema/decode-database $ parse-cirru-edn content
              fn (error)
                Result :err $ %:: schema/DatabaseDecodeError :invalid |db $ str "|Malformed persisted Cirru EDN: " error
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'String
            :return $ :: 'Result 'app.schema/Db 'app.schema/DatabaseDecodeError
          :tests $ [] $ %{} 'TestEntry (:name |rejects-malformed-cirru-edn)
            :code $ quote $ match (read-persisted-database "|{} (:sessions")
              (:ok _) (raise |Expected-malformed-storage-error)
              (:err _) &unit
            :tags $ #{} :schema :server
        'read-sync-metrics $ %{} 'CodeEntry
          :doc "|Read counters plus pending and slow-client gauges computed from current connection state."
          :code $ quote $ defn read-sync-metrics ()
            let
                states $ distinct-values @*client-states
                pending-clients $ count $ filter states
                  fn (state)
                    option:unwrap-or (get state :in-flight?) false
                slow-clients $ count $ filter states
                  fn (state)
                    option:unwrap-or (get state :slow-client?) false
              struct-with @*sync-metrics (:pending-clients pending-clients) (:slow-clients slow-clients)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.server/SyncMetrics)
            :args $ []
          :tests $ [] $ %{} 'TestEntry
            :name |preserves-counters-and-derives-connection-gauges
            :code $ quote $ let
                saved-states @*client-states
                saved-metrics @*sync-metrics
              do
                reset! *client-states $ {}
                  1 $ {} (:in-flight? true) (:slow-client? false)
                  2 $ {} (:in-flight? false) (:slow-client? true)
                  3 $ {} (:in-flight? true) (:slow-client? true)
                reset! *sync-metrics $ struct-with saved-metrics (:resync-count 7) (:patch-attempts 11)
                let
                    result $ read-sync-metrics
                    unchanged? $ = @*sync-metrics $ struct-with saved-metrics (:resync-count 7) (:patch-attempts 11)
                  do (reset! *client-states saved-states) (reset! *sync-metrics saved-metrics)
                    assert= 2 $ :pending-clients result
                    assert= 2 $ :slow-clients result
                    assert= 7 $ :resync-count result
                    assert= 11 $ :patch-attempts result
                    assert= true unchanged?
            :tags $ #{} :server
        'record-resync! $ %{} 'CodeEntry
          :doc "|Count one explicit client request for a full synchronization snapshot."
          :code $ quote $ defn record-resync! ()
            swap! *sync-metrics $ fn (metrics)
              hint-fn $ {} (:return 'app.server/SyncMetrics)
                :args $ [] 'app.server/SyncMetrics
              struct-with metrics $ :resync-count $ inc (:resync-count metrics)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
          :tests $ [] $ %{} 'TestEntry
            :name |increments-resync-without-changing-other-counters
            :code $ quote $ let
                saved @*sync-metrics
              do (record-resync!) (record-resync!)
                let
                    result @*sync-metrics
                  do (reset! *sync-metrics saved)
                    assert= result $ struct-with saved $ :resync-count
                      + 2 $ :resync-count saved
            :tags $ #{} :server
        'record-sync-send! $ %{} 'CodeEntry
          :doc "|Record metrics for one synchronization send attempt before transport admission."
          :code $ quote $ defn record-sync-send! (message-kind revision diff-latency payload stats budget-fallback?)
            swap! *sync-metrics $ fn (metrics)
              hint-fn $ {}
                :args $ [] 'app.server/SyncMetrics
                :return 'app.server/SyncMetrics
              next-sync-metrics metrics message-kind revision diff-latency payload stats budget-fallback?
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Tag 'Number 'Number 'String 'recollect.diff/DiffStats 'Bool
        'reel-db $ %{} 'CodeEntry
          :doc "|Named adapter for the legacy generic ReelState database slot."
          :code $ quote $ defn reel-db (reel) (:db reel)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] $ :: 'cumulo-reel.core/ReelState 'app.schema/Db
          :tests $ [] $ %{} 'TestEntry (:name |decodes-generic-reel-slot)
            :code $ quote $ let
                reel $ assert-type
                  %{} cumulo-reel.core/ReelState (:db schema/database) (:base schema/database)
                    :records $ []
                    :merged? false
                  :: 'cumulo-reel.core/ReelState 'app.schema/Db
              assert= schema/database $ reel-db reel
              assert= 0 $ reel-record-count reel
            :tags $ #{} :server
        'reel-record-count $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn reel-record-count (reel)
            &list:count $ :records reel
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Number)
            :args $ [] $ :: 'cumulo-reel.core/ReelState 'app.schema/Db
          :tests $ []
            %{} 'TestEntry (:name |counts-heterogeneous-records)
              :code $ quote $ let
                  reel $ assert-type
                    %{} cumulo-reel.core/ReelState (:db schema/database) (:base schema/database)
                      :records $ [] ([] :first 1 |op-1 10) ([] :second 2 |op-2 20)
                      :merged? false
                    :: 'cumulo-reel.core/ReelState 'app.schema/Db
                assert= 2 $ reel-record-count reel
              :tags $ #{} :server
            %{} 'TestEntry (:name |rejects-non-list-record-slot)
              :code $ quote $ let
                  reel $ assert-type
                    %{} cumulo-reel.core/ReelState (:db schema/database) (:base schema/database)
                      :records $ []
                      :merged? false
                    :: 'cumulo-reel.core/ReelState 'app.schema/Db
                  corrupt $ &struct:assoc reel :records $ parse-cirru-edn "|{} (:wrong |container)"
                assert= true $ try
                  do (reel-record-count corrupt) false
                  fn (detail) (includes? detail |list)
              :tags $ #{} :server
        'refresh-domain-reel $ %{} 'CodeEntry
          :doc "|Replay callbacks accept heterogeneous historical values; updater-from-reel decodes operation, session, ID and time before calling the typed domain updater. Validate the merged base before replay."
          :code $ quote $ defn refresh-domain-reel (reel base replay-updater)
            let
                next-base $ if (:merged? reel)
                  match
                    schema/decode-database $ :base reel
                    (:ok validated) validated
                    (:err error)
                      raise $ str |Invalid-reel-base: error
                  , base
                next-db $ cumulo-reel.core/play-records next-base (:records reel) replay-updater
              struct-with reel (:base next-base) (:db next-db)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'cumulo-reel.core/ReelState)
            :args $ [] 'cumulo-reel.core/ReelState 'app.schema/Db $ :: 'Fn
              {} (:return 'app.schema/Db)
                :args $ [] 'app.schema/Db 'Dynamic 'Dynamic 'Dynamic 'Dynamic
          :tests $ []
            %{} 'TestEntry (:name |rejects-invalid-merged-base)
              :code $ quote $ assert= true
                try
                  do
                    refresh-domain-reel
                      %{} cumulo-reel.core/ReelState (:base 42) (:db schema/database)
                        :records $ []
                        :merged? true
                      , schema/database updater-from-reel
                    , false
                  fn (error) (starts-with? error |Invalid-reel-base:)
              :tags $ #{} :server
            %{} 'TestEntry (:name |fresh-base-ignores-unmerged-old-base)
              :code $ quote $ let
                  base schema/database
                  reel $ %{} cumulo-reel.core/ReelState (:base 42) (:db schema/database)
                    :records $ []
                    :merged? false
                  refreshed $ refresh-domain-reel reel base updater-from-reel
                assert= base $ :base refreshed
                assert= base $ :db refreshed
                assert= ([]) (:records refreshed)
                assert= false $ :merged? refreshed
              :tags $ #{} :server
        'refresh-partitions! $ %{} 'CodeEntry
          :doc "|Advance each dirty live partition with exactly one projection and one bounded diff, before any connection is planned."
          :code $ quote $ defn refresh-partitions! (db cold)
            let
                dirty @*dirty-partitions
              reset! *dirty-partitions $ assert-type (#{}) (:: 'Set 'app.schema/PartitionKey)
              each dirty $ fn (key)
                hint-fn $ {}
                  :args $ [] 'app.schema/PartitionKey
                  :return 'Unit
                match (get @*partitions key)
                  (:none) &unit
                  (:some raw-state)
                    let
                        state $ assert-type raw-state app.partition/PartitionState
                        step $ advance-partition state (project-partition db cold key) sync-diff-budget partition-history-limit patch-operation-limit
                      swap! *partitions assoc key $ :state step
                      count-partition-event! :diff
                      match (:advance step)
                        (:unchanged) &unit
                        (:delta _delta _stats) (count-partition-event! :advance)
                        (:reset _stats) (count-partition-event! :reset)
              , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.schema/Db 'app.schema/ColdStore
        'release-partition-sends! $ %{} 'CodeEntry
          :doc "|When a connection resumes after idling, forget sends whose ACK may have been lost; clients reject mismatched bases and resync."
          :code $ quote $ defn release-partition-sends! (sid)
            update-progress! sid $ fn (progress)
              .filter-map-kv progress $ fn (key item)
                hint-fn $ {}
                  :args $ [] 'app.schema/PartitionKey 'app.partition/PartitionProgress
                  :return $ :: 'MapEntryDecision 'app.schema/PartitionKey 'app.partition/PartitionProgress
                %:: MapEntryDecision :keep key $ release-partition-send item
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number
        'reload! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn reload! () (println "|Code updated..")
            if (not config/dev?) (raise "|reloading only happens in dev mode")
            clear-twig-caches!
            invalidate-sync-caches!
            mark-all-partitions-dirty!
            reset! *reel $ refresh-domain-reel @*reel @*initial-db updater-from-reel
            render-loop!
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'remove-client-cache $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn remove-client-cache (caches sid) (dissoc caches sid)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'Map 'Number 'T) 'Number
            :generics $ [] 'T
            :return $ :: 'Map 'Number 'T
        'remove-dirty-client $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn remove-dirty-client (clients sid) (exclude clients sid)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'Set 'Number) 'Number
            :return $ :: 'Set 'Number
        'render-loop! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn render-loop! ()
            when
              not $ identical? @*reader-reel @*reel
              reset! *reader-reel @*reel
              swap! *sync-revision inc
              mark-clients-dirty! @*sync-revision
            sync-clients! @*reader-reel
            sync-partitions! $ reel-db @*reader-reel
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'request-sync! $ %{} 'CodeEntry
          :doc "|Request one bounded, coalesced server sync callback."
          :code $ quote $ defn request-sync! ()
            if @*sync-scheduled? &unit $ do (reset! *sync-scheduled? true)
              set-timeout sync-coalesce-delay $ fn () (reset! *sync-scheduled? false) (render-loop!)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'request-sync-retry! $ %{} 'CodeEntry
          :doc "|Request one slower retry without blocking new fast sync requests."
          :code $ quote $ defn request-sync-retry! ()
            if @*sync-retry-scheduled? &unit $ do (reset! *sync-retry-scheduled? true)
              set-timeout sync-retry-delay $ fn () (reset! *sync-retry-scheduled? false)
                when
                  not $ empty? @*dirty-clients
                  request-sync!
                , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'resolve-port $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn resolve-port ()
            hint-fn $ {}
              :args $ []
              :return 'Number
            match (get-env |port)
              (:some value)
                match (parse-float value)
                  (:ok parsed) parsed
                  (:err _) (site-port)
              (:none) (site-port)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Number)
            :args $ []
        'resync-partition! $ %{} 'CodeEntry
          :doc "|Forget progress for one partition so the next flush sends a fresh snapshot."
          :code $ quote $ defn resync-partition! (sid key)
            update-progress! sid $ fn (progress) (dissoc progress key)
            request-sync!
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'app.schema/PartitionKey
        'run-server! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn run-server! (port)
            wss-serve!
              {} $ :port port
              fn (data)
                hint-fn $ {}
                  :args $ [] 'wss.core/WssEvent
                  :return 'Unit
                match data
                  (:connect sid)
                    do
                      swap! *client-states assoc sid $ {} (:status :idle)
                        :last-heartbeat $ now-ms
                        :acked-rev 0
                        :dirty-rev @*sync-revision
                        :in-flight? false
                        :needs-snapshot? true
                      dispatch! (schema/Op :session/connect) sid
                      println "|New client."
                  (:message sid msg)
                    match
                      schema/decode-client-message $ parse-cirru-edn msg
                      (:ok message) (handle-client-message! message sid)
                      (:err error) (eprintln "|Invalid client message:" sid error)
                  (:disconnect sid)
                    do (println "|Client closed!")
                      dispatch! (%:: schema/Op :session/disconnect) sid
                      swap! *client-caches remove-client-cache sid
                      swap! *client-states dissoc sid
                      swap! *dirty-clients remove-dirty-client sid
                      swap! *partition-progress dissoc sid
                  _ $ println "|unknown data:" data
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number
        'select-sync-diff $ %{} 'CodeEntry
          :doc "|Convert one atomic Recollect outcome into patch, snapshot, or idle policy while retaining the existing top-level patch-operation limit."
          :code $ quote $ defn select-sync-diff (outcome)
            match outcome
              (:budget-exceeded reason stats)
                %:: SyncDiffPlan :snapshot stats $ Option :some reason
              (:complete changes stats)
                cond
                    empty? changes
                    %:: SyncDiffPlan :idle stats
                  (> (count changes) patch-operation-limit)
                    %:: SyncDiffPlan :snapshot stats $ Option :none
                  true $ %:: SyncDiffPlan :patch changes stats
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.server/SyncDiffPlan)
            :args $ [] 'recollect.diff/DiffOutcome
          :tests $ []
            %{} 'TestEntry (:name |budget-exceeded-discards-partial-path)
              :code $ quote $ let
                  stats $ %{} DiffStats (:visited-nodes 3) (:emitted-ops 1)
                  reason $ %:: recollect.diff/DiffBudgetReason :visited-nodes
                  outcome $ %:: recollect.diff/DiffOutcome :budget-exceeded reason stats
                assert=
                  %:: SyncDiffPlan :snapshot stats $ Option :some reason
                  select-sync-diff outcome
              :tags $ #{} :server
            %{} 'TestEntry
              :name |complete-selects-idle-patch-and-operation-fallback
              :code $ quote $ let
                  stats $ %{} DiffStats (:visited-nodes 1) (:emitted-ops 1)
                  change $ %:: recollect.schema/change-op :replace 2
                  idle-outcome $ %:: recollect.diff/DiffOutcome :complete ([]) stats
                  patch-outcome $ %:: recollect.diff/DiffOutcome :complete ([] change) stats
                  large-outcome $ %:: recollect.diff/DiffOutcome :complete (repeat change 65) stats
                do
                  assert= (%:: SyncDiffPlan :idle stats) (select-sync-diff idle-outcome)
                  assert=
                    %:: SyncDiffPlan :patch ([] change) stats
                    select-sync-diff patch-outcome
                  assert=
                    %:: SyncDiffPlan :snapshot stats $ Option :none
                    select-sync-diff large-outcome
              :tags $ #{} :server
            %{} 'TestEntry (:name |real-budget-overflow-is-atomic)
              :code $ quote $ let
                  budget $ %{} DiffBudget
                    :max-visited $ Option :some 3
                    :max-emitted $ Option :none
                  outcome $ diff-twig-budgeted ([] 1 2 3) ([] 1 2 4) ({}) budget
                  plan $ select-sync-diff outcome
                match plan
                  (:snapshot stats reason)
                    do
                      assert= 3 $ :visited-nodes stats
                      assert=
                        Option :some $ %:: recollect.diff/DiffBudgetReason :visited-nodes
                        , reason
                  _ $ assert |overflow-must-select-snapshot false
              :tags $ #{} :server
        'send-partition-action! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn send-partition-action! (sid action)
            match action
              (:drop key)
                do
                  update-progress! sid $ fn (progress) (dissoc progress key)
                  count-partition-event! :drop
                  wss-send! sid $ format-cirru-edn $ schema/ServerMessage :part/drop key
                  , &unit
              (:snapshot state)
                do (count-partition-event! :snapshot)
                  handle-partition-send! sid state $ wss-send! sid $ format-cirru-edn
                    schema/ServerMessage :part/snapshot (:key state) (:epoch state) (:revision state) (:view state)
              (:deltas state deltas)
                do (count-partition-event! :delta)
                  handle-partition-send! sid state $ wss-send! sid $ partition-patch-payload state deltas
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'app.partition/PartitionAction
        'site-port $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn site-port ()
            assert-type (&map:get config/site :port) Number
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Number)
            :args $ []
        'site-storage-file $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn site-storage-file ()
            assert-type (&map:get config/site :storage-file) String
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ []
        'storage-file $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def storage-file
            if (empty? calcit-dirname)
              str calcit-dirname $ site-storage-file
              str calcit-dirname |/ $ site-storage-file
          :examples $ []
          :schema $ :: 'String
        'sweep-idle-clients! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn sweep-idle-clients! ()
            let
                current-time $ now-ms
              each (keys @*client-states)
                fn (sid)
                  let
                      state $ option:unwrap $ get @*client-states sid
                      last-heartbeat $ option:unwrap-or (get state :last-heartbeat) 0
                    when
                      and
                        = :active $ option:unwrap $ get state :status
                        > (- current-time last-heartbeat) heartbeat-timeout
                      mark-client-idle! sid $ option:unwrap-or (get state :acked-rev) 0
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'sync-client! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn sync-client! (sid reel revision) (swap! *dirty-clients remove-dirty-client sid)
            let
                state $ option:unwrap $ get @*client-states sid
              when
                and
                  = :active $ option:unwrap $ get state :status
                  not $ option:unwrap-or (get state :in-flight?) false
                let
                    db $ reel-db reel
                  if-let
                    raw-session $ get (:sessions db) sid
                    let
                        session-data $ assert-type raw-session app.schema/Session
                        shared $ get-shared-twig reel revision
                        old-store-option $ get @*client-caches sid
                        new-store $ twig-container db session-data shared
                        needs-snapshot? $ or
                          option:unwrap-or (get state :needs-snapshot?) true
                          option:none? old-store-option
                        diff-start $ now-ms
                        diff-plan $ if needs-snapshot?
                          %:: SyncDiffPlan :snapshot empty-diff-stats $ Option :none
                          select-sync-diff $ diff-twig-budgeted (option:unwrap old-store-option) new-store
                            {} $ :key :id
                            , sync-diff-budget
                        diff-latency $ - (now-ms) diff-start
                        base-revision $ option:unwrap-or (get state :acked-rev) 0
                      match diff-plan
                        (:snapshot stats budget-reason)
                          let
                              payload $ format-cirru-edn $ %:: schema/ServerMessage :snapshot revision new-store
                            record-sync-send! :snapshot revision diff-latency payload stats $ option:some? budget-reason
                            handle-sync-send! sid revision new-store $ wss-send! sid payload
                        (:patch changes stats)
                          let
                              payload $ format-cirru-edn $ %:: schema/ServerMessage :patch base-revision revision changes
                            record-sync-send! :patch revision diff-latency payload stats false
                            handle-sync-send! sid revision new-store $ wss-send! sid payload
                        (:idle _stats) &unit
                    do (eprintln |Missing-typed-session-during-sync: sid) &unit
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number (:: 'cumulo-reel.core/ReelState 'app.schema/Db) 'Number
        'sync-clients! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn sync-clients! (reel)
            when
              not $ empty? @*dirty-clients
              begin-twig-frame!
              let
                  revision @*sync-revision
                  clients @*dirty-clients
                each clients $ fn (sid)
                  when
                    option:some? $ get @*client-states sid
                    sync-client! sid reel revision
              finish-twig-frame!
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] $ :: 'cumulo-reel.core/ReelState 'app.schema/Db
        'sync-coalesce-delay $ %{} 'CodeEntry
          :doc "|Maximum coalescing delay in milliseconds for ordinary state updates."
          :code $ quote $ def sync-coalesce-delay 16
          :examples $ []
          :schema $ :: 'Number
        'sync-diff-budget $ %{} 'CodeEntry
          :doc "|Deterministic per-client diff budget; snapshot size and transport admission remain independent limits."
          :code $ quote $ def sync-diff-budget
            %{} DiffBudget
              :max-visited $ Option :some sync-diff-visited-limit
              :max-emitted $ Option :some sync-diff-emitted-limit
          :examples $ []
          :schema $ :: 'recollect.diff/DiffBudget
        'sync-diff-emitted-limit $ %{} 'CodeEntry
          :doc "|Operation-construction ceiling selected above the measured 10k workload maximum of 70001."
          :code $ quote $ def sync-diff-emitted-limit 80000
          :examples $ []
          :schema $ :: 'Number
        'sync-diff-visited-limit $ %{} 'CodeEntry
          :doc "|Visited-node ceiling selected above the measured 10k workload maximum of 40002."
          :code $ quote $ def sync-diff-visited-limit 50000
          :examples $ []
          :schema $ :: 'Number
        'sync-partitions! $ %{} 'CodeEntry
          :doc "|Partition synchronization over the WebSocket transport."
          :code $ quote $ defn sync-partitions! (db) (sync-partitions-with! db send-partition-action!)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.schema/Db
        'sync-partitions-with! $ %{} 'CodeEntry
          :doc "|Advance dirty partitions once, then plan each active connection from its authorized partition set through an injectable transport; diff count is independent of subscriber count."
          :code $ quote $ defn sync-partitions-with! (db send!)
            let
                cold @*cold-store
              refresh-partitions! db cold
              each (keys @*client-states)
                fn (sid)
                  hint-fn $ {}
                    :args $ [] 'Number
                    :return 'Unit
                  let
                      state $ option:unwrap $ get @*client-states sid
                    when
                      = :active $ option:unwrap-or (get state :status) :idle
                      match
                        get (:sessions db) sid
                        (:none) &unit
                        (:some raw-session)
                          let
                              desired $ session-partitions db $ assert-type raw-session app.schema/Session
                            each desired $ fn (key)
                              hint-fn $ {}
                                :args $ [] 'app.schema/PartitionKey
                                :return 'Unit
                              ensure-partition! db cold key
                            each
                              connection-actions @*partitions (progress-of sid) desired
                              fn (action)
                                hint-fn $ {}
                                  :args $ [] 'app.partition/PartitionAction
                                  :return 'Unit
                                send! sid action
                    , &unit
              collect-partitions!
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'app.schema/Db $ :: 'Fn
              {} (:return 'Unit)
                :args $ [] 'Number 'app.partition/PartitionAction
          :tests $ [] $ %{} 'TestEntry (:name |one-diff-for-many-subscribers)
            :code $ quote $ let
                saved-partitions @*partitions
                saved-progress @*partition-progress
                saved-dirty @*dirty-partitions
                saved-metrics @*partition-metrics
                saved-clients @*client-states
                saved-cold @*cold-store
                saved-payloads @*partition-payloads
                sids $ [] 1 2 3 4 5
                user $ fn (sid)
                  hint-fn $ {}
                    :args $ [] 'Number
                    :return 'app.schema/User
                  %{} schema/User
                    :id $ str |u sid
                    :name $ str |user sid
                    :nickname $ Option :none
                    :avatar $ Option :none
                    :password |hash
                session $ fn (sid)
                  hint-fn $ {}
                    :args $ [] 'Number
                    :return 'app.schema/Session
                  %{} schema/Session (:id sid)
                    :user-id $ Option :some $ str |u sid
                    :nickname $ Option :none
                    :router $ %{} schema/Router (:name :board)
                      :target $ Option :some |b1
                    :messages $ {}
                base $ %{} schema/Db
                  :sessions $ assert-type
                    pairs-map $ map sids $ fn (sid)
                      [] sid $ session sid
                    :: 'Map 'Number 'app.schema/Session
                  :users $ assert-type
                    pairs-map $ map sids $ fn (sid)
                      [] (str |u sid) (user sid)
                    :: 'Map 'String 'app.schema/User
                  :boards $ {}
                  :settings $ {}
                db1 $ app.updater.kanban/apply-kanban base (schema/KanbanOp :board/create |Plan) 1 |b1 1
                add-op $ schema/DomainOp :kanban $ schema/KanbanOp :card/add |b1 |b1-todo |Ship
                db2 $ app.updater.kanban/apply-kanban db1 (schema/KanbanOp :card/add |b1 |b1-todo |Ship) 1 |c1 2
                *sent $ atom $ assert-type ([]) (:: 'List 'app.partition/PartitionAction)
                record! $ fn (sid action)
                  hint-fn $ {}
                    :args $ [] 'Number 'app.partition/PartitionAction
                    :return 'Unit
                  swap! *sent conj action
                  match action
                    (:drop _key) &unit
                    (:snapshot state)
                      do
                        handle-partition-send! sid state $ wss.core/WssSendOutcome :accepted
                        ack-partition-progress-for! sid state
                    (:deltas state deltas)
                      do (partition-patch-payload state deltas)
                        handle-partition-send! sid state $ wss.core/WssSendOutcome :accepted
                        ack-partition-progress-for! sid state
                sends-of $ fn (tag)
                  hint-fn $ {}
                    :args $ [] 'Tag
                    :return 'Number
                  count $ filter @*sent $ fn (action)
                    hint-fn $ {}
                      :args $ [] 'app.partition/PartitionAction
                      :return 'Bool
                    = tag $ match action
                      (:snapshot _state) :snapshot
                      (:deltas _state _deltas) :deltas
                      (:drop _key) :drop
                board-deltas $ fn ()
                  hint-fn $ {}
                    :args $ []
                    :return $ :: 'List $ :: 'List 'app.schema/PartitionDelta
                  foldl @*sent
                    assert-type ([])
                      :: 'List $ :: 'List 'app.schema/PartitionDelta
                    fn (acc action)
                      hint-fn $ {}
                        :args $ []
                          :: 'List $ :: 'List 'app.schema/PartitionDelta
                          , 'app.partition/PartitionAction
                        :return $ :: 'List $ :: 'List 'app.schema/PartitionDelta
                      match action
                        (:deltas state deltas)
                          if
                            = (:key state) (schema/PartitionKey :board |b1)
                            conj acc deltas
                            , acc
                        _ acc
              reset! *partitions $ assert-type ({}) (:: 'Map 'app.schema/PartitionKey 'app.partition/PartitionState)
              reset! *partition-progress $ assert-type ({})
                :: 'Map 'Number $ :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress
              reset! *dirty-partitions $ assert-type (#{}) (:: 'Set 'app.schema/PartitionKey)
              reset! *partition-metrics empty-partition-metrics
              reset! *partition-payloads $ assert-type ({}) (:: 'Map 'app.schema/PartitionKey 'app.server/CachedPayload)
              reset! *cold-store schema/empty-cold-store
              reset! *client-states $ assert-type
                pairs-map $ map sids $ fn (sid)
                  [] sid $ {} $ :status :active
                :: 'Map 'Number $ :: 'Map 'Tag 'Dynamic
              sync-partitions-with! db1 record!
              let
                  initial-snapshots $ sends-of :snapshot
                  initial-partitions $ count @*partitions
                reset! *sent $ assert-type ([]) (:: 'List 'app.partition/PartitionAction)
                mark-partitions-dirty! $ affected-partitions db1 add-op 1
                sync-partitions-with! db2 record!
                let
                    metrics $ read-partition-metrics
                    deltas $ board-deltas
                    snapshots $ sends-of :snapshot
                    delta-sends $ sends-of :deltas
                  reset! *partitions saved-partitions
                  reset! *partition-progress saved-progress
                  reset! *dirty-partitions saved-dirty
                  reset! *partition-metrics saved-metrics
                  reset! *client-states saved-clients
                  reset! *cold-store saved-cold
                  reset! *partition-payloads saved-payloads
                  assert= 15 initial-snapshots
                  assert= 7 initial-partitions
                  assert= 3 $ :diffs metrics
                  assert= 0 snapshots
                  assert= 10 delta-sends
                  assert= 5 $ count deltas
                  assert= 1 $ count $ distinct deltas
                  assert= 8 $ :reused-payloads metrics
            :tags $ #{} :partition :server
        'sync-retry-delay $ %{} 'CodeEntry
          :doc "|Retry delay in milliseconds after WebSocket backpressure."
          :code $ quote $ def sync-retry-delay 200
          :examples $ []
          :schema $ :: 'Number
        'touch-client! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn touch-client! (sid client-revision)
            let
                state $ option:unwrap $ get @*client-states sid
              if
                = :active $ option:unwrap $ get state :status
                swap! *client-states assoc-client-state-field sid :last-heartbeat $ now-ms
                mark-client-active! sid client-revision true
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number 'Number
        'update-progress! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn update-progress! (sid f)
            swap! *partition-progress assoc sid $ f $ progress-of sid
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Number $ :: 'Fn
              {}
                :args $ [] $ :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress
                :return $ :: 'Map 'app.schema/PartitionKey 'app.partition/PartitionProgress
        'updater-from-reel $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn updater-from-reel (db op sid op-id op-time)
            let
                typed-sid $ decode-map-as sid 'Number
                typed-op-id $ decode-map-as op-id 'String
                typed-op-time $ decode-map-as op-time 'Number
              match (schema/decode-domain-operation op)
                (:err error)
                  raise $ str |Invalid-reel-operation: error
                (:ok typed-op) (updater db typed-op typed-sid typed-op-id typed-op-time)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'Input 'Sid 'OpId 'Time
            :generics $ [] 'Sid 'OpId 'Time 'Input
          :tests $ []
            %{} 'TestEntry (:name |live-reducer-matches-business-updater)
              :code $ quote $ let
                  base schema/database
                  connect-op $ schema/DomainOp :session/connect
                  reel $ assert-type
                    %{} cumulo-reel.core/ReelState (:db base) (:base base)
                      :records $ []
                      :merged? false
                    :: 'cumulo-reel.core/ReelState 'app.schema/Db
                  updated $ reel-reducer reel updater connect-op 1 |op-1 10 true
                assert= (updater base connect-op 1 |op-1 10) (:db updated)
                assert=
                  [] $ [] connect-op 1 |op-1 10
                  :records updated
              :tags $ #{} :server
            %{} 'TestEntry (:name |replays-legacy-operations-in-order)
              :code $ quote $ let
                  base schema/database
                  connect-op $ schema/DomainOp :session/connect
                  reel $ assert-type
                    %{} cumulo-reel.core/ReelState (:db base) (:base base)
                      :records $ []
                      :merged? false
                    :: 'cumulo-reel.core/ReelState 'app.schema/Db
                  router $ %{} schema/Router (:name :profile)
                    :target $ Option :none
                  expected $ updater (updater base connect-op 1 |op-1 10) (schema/DomainOp :router/change router) 1 |op-2 20
                  records $ []
                    [] (:: :session/connect) 1 |op-1 10
                    []
                      :: :router/change $ {} $ :name :profile
                      , 1 |op-2 20
                  replayed $ refresh-domain-reel (assoc reel :records records) base updater-from-reel
                assert= expected $ :db replayed
                assert= records $ :records replayed
              :tags $ #{} :server
            %{} 'TestEntry (:name |preserves-reset-and-merged-replay-base)
              :code $ quote $ let
                  base schema/database
                  connect-op $ schema/DomainOp :session/connect
                  reel $ assert-type
                    %{} cumulo-reel.core/ReelState (:db base) (:base base)
                      :records $ []
                      :merged? false
                    :: 'cumulo-reel.core/ReelState 'app.schema/Db
                  updated $ reel-reducer reel updater connect-op 1 |op-1 10 true
                  control-updater $ fn (db op sid op-id op-time)
                    hint-fn $ {}
                      :args $ [] 'app.schema/Db 'app.schema/Op 'Number 'String 'Number
                      :return 'app.schema/Db
                    raise |Updater-must-not-run
                  reset $ reel-reducer updated control-updater (schema/Op :reel/reset) 1 |reset 20 true
                  merged $ reel-reducer updated control-updater (schema/Op :reel/merge) 1 |merge 30 true
                  refreshed $ refresh-domain-reel merged base updater-from-reel
                assert= base $ :db reset
                assert= ([]) (:records reset)
                assert= (:db updated) (:base merged)
                assert= (:db updated) (:db refreshed)
                assert= ([]) (:records merged)
              :tags $ #{} :server
            %{} 'TestEntry (:name |rejects-effect-record-during-replay)
              :code $ quote $ let
                  base schema/database
                  connect-op $ schema/DomainOp :session/connect
                  reel $ assert-type
                    %{} cumulo-reel.core/ReelState (:db base) (:base base)
                      :records $ []
                      :merged? false
                    :: 'cumulo-reel.core/ReelState 'app.schema/Db
                  records $ [] $ [] (:: :effect/persist) 1 |op-1 10
                assert= true $ try
                  do
                    refresh-domain-reel (assoc reel :records records) base updater-from-reel
                    , false
                  fn (detail) (includes? detail |Invalid-reel-operation:)
              :tags $ #{} :server
            %{} 'TestEntry (:name |rejects-invalid-record-metadata)
              :code $ quote $ let
                  base schema/database
                  reel $ assert-type
                    %{} cumulo-reel.core/ReelState (:db base) (:base base)
                      :records $ []
                      :merged? false
                    :: 'cumulo-reel.core/ReelState 'app.schema/Db
                  records $ [] $ [] (:: :session/connect) |not-a-number |op-1 10
                assert= true $ try
                  do
                    refresh-domain-reel (assoc reel :records records) base updater-from-reel
                    , false
                  fn (detail) (includes? detail "|expected number, got string")
              :tags $ #{} :server
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.server
          :require (app.schema :as schema)
            app.schema :refer $ Op
            app.updater :refer $ updater
            cumulo-reel.core :refer $ reel-reducer refresh-reel reel-schema
            app.config :as config
            app.twig.container :refer $ twig-container twig-shared
            recollect.diff :refer $ diff-twig-budgeted DiffBudget DiffStats
            wss.core :refer $ wss-serve! wss-send!
            recollect.twig :refer $ clear-twig-caches!
            app.$meta :refer $ calcit-dirname
            calcit.std.fs :refer $ path-exists? check-write-file!
            calcit.std.time :refer $ set-timeout set-interval
            calcit.std.date :refer $ Date get-time! get-timestamp extract-time
            calcit.std.path :refer $ join-path
            recollect.memo :refer $ begin-twig-frame! finish-twig-frame!
            app.partition :refer $ PartitionState PartitionProgress advance-partition new-partition connection-actions mark-partition-sent ack-partition-progress release-partition-send
            app.twig.partition :refer $ project-partition session-partitions affected-partitions
            app.updater.kanban :refer $ kanban-effects apply-cold-effects history-page card-detail-reply session-user-id
    'app.twig.container $ %{} 'FileEntry
      :defs $ {}
        'twig-container $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn twig-container (db session-data shared)
            let
                user-id-option $ :user-id session-data
                logged-in? $ option:some? user-id-option
                router-data $ :router session-data
                router-name $ :name router-data
                router-view-data $ if logged-in?
                  match router-name
                    :home $ :pages shared
                    :profile $ Option :some $ :members shared
                    _ $ Option :none
                  Option :none
                router-view $ %{} RouterView (:name router-name)
                  :target $ :target router-data
                  :data router-view-data
                  :router $ Option :none
                messages-view $ .filter-map-kv (:messages session-data)
                  fn (id message)
                    hint-fn $ {}
                      :args $ [] 'String 'app.schema/Message
                      :return $ :: 'MapEntryDecision 'String 'app.schema/MessageView
                    %:: MapEntryDecision :keep id $ %{} app.schema/MessageView
                      :id $ :id message
                      :text $ :text message
                session-view $ %{} SessionView (:user-id user-id-option)
                  :id $ Option :some $ :id session-data
                  :nickname $ :nickname session-data
                  :router $ %{} RouterView (:name router-name)
                    :target $ :target router-data
                    :data $ Option :none
                    :router $ Option :none
                  :messages messages-view
                user-option $ match user-id-option
                  (:none) (Option :none)
                  (:some user-id)
                    match
                      get (:users db) user-id
                      (:some user-data)
                        Option :some $ twig-user user-data
                      (:none) (Option :none)
              %{} Store (:logged-in? logged-in?) (:session session-view)
                :reel-length $ :reel-length shared
                :attached $ :attached shared
                :user user-option
                :router router-view
                :count $ if logged-in? (:session-count shared) 0
                :color $ if logged-in? |#aaa |transparent
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Store)
            :args $ [] 'app.schema/Db 'app.schema/Session 'app.schema/SharedTwig
          :tests $ []
            %{} 'TestEntry (:name |typed-store-roundtrip)
              :code $ quote $ let
                  message $ %{} app.schema/Message (:id |m1) (:text |hello)
                  session-data $ %{} app.schema/Session
                    :user-id $ Option :none
                    :id 1
                    :nickname $ Option :none
                    :router $ %{} app.schema/Router (:name :home)
                      :target $ Option :none
                    :messages $ {} $ |m1 message
                  db $ %{} app.schema/Db
                    :sessions $ {} $ 1 session-data
                    :users $ {}
                    :boards $ {}
                    :settings $ {}
                  shared $ twig-shared db 0
                  store $ twig-container db session-data shared
                  decoded $ parse-cirru-edn $ format-cirru-edn store
                  session-view $ :session store
                  raw-message $ option:unwrap $ get (:messages session-view) |m1
                  typed-message $ assert-type raw-message app.schema/MessageView
                assert= true $ &struct:matches? store Store
                assert= true $ &struct:matches? decoded Store
                assert= true $ &struct:matches? typed-message MessageView
                assert= 0 $ :count store
                assert= |hello $ :text typed-message
              :tags $ #{} :twig :type
            %{} 'TestEntry (:name |session-none-fields)
              :code $ quote $ let
                  db app.schema/database
                  session-data app.schema/session
                  shared $ twig-shared db 0
                  projected $ twig-container db session-data shared
                  view $ :session projected
                assert= (Option :some 0) (:id view)
                assert= (Option :none) (:user-id view)
                assert= (Option :none) (:nickname view)
                assert= view $ parse-cirru-edn (format-cirru-edn view)
                  {} (:Option Option) (:SessionView view)
                    :RouterView $ :router view
              :tags $ #{} :client :server :twig :type
            %{} 'TestEntry (:name |session-some-fields)
              :code $ quote $ let
                  user-data $ %{} app.schema/User (:id |u1) (:name |demo)
                    :nickname $ Option :none
                    :avatar $ Option :none
                    :password |hash
                  session-data $ %{} app.schema/Session (:id 0)
                    :user-id $ Option :some |u1
                    :nickname $ Option :some ||
                    :router $ %{} app.schema/Router (:name :home)
                      :target $ Option :none
                    :messages $ {}
                  db $ %{} app.schema/Db
                    :sessions $ {} $ 0 session-data
                    :users $ {} $ |u1 user-data
                    :boards $ {}
                    :settings $ {}
                  shared $ twig-shared db 0
                  projected $ twig-container db session-data shared
                  view $ :session projected
                assert= (Option :some 0) (:id view)
                assert= (Option :some |u1) (:user-id view)
                assert= (Option :some ||) (:nickname view)
                assert= true $ :logged-in? projected
                assert= view $ parse-cirru-edn (format-cirru-edn view)
                  {} (:Option Option) (:SessionView view)
                    :RouterView $ :router view
              :tags $ #{} :client :server :twig :type
            %{} 'TestEntry (:name |missing-user-retains-session)
              :code $ quote $ let
                  session-data $ %{} app.schema/Session (:id 0)
                    :user-id $ Option :some |u1
                    :nickname $ Option :some ||
                    :router $ %{} app.schema/Router (:name :home)
                      :target $ Option :none
                    :messages $ {}
                  db $ %{} app.schema/Db
                    :sessions $ {} $ 0 session-data
                    :users $ {}
                    :boards $ {}
                    :settings $ {}
                  shared $ twig-shared db 0
                  projected $ twig-container db session-data shared
                  view $ :session projected
                assert= (Option :some 0) (:id view)
                assert= (Option :some |u1) (:user-id view)
                assert= (Option :some ||) (:nickname view)
                assert= true $ :logged-in? projected
                assert= view $ parse-cirru-edn (format-cirru-edn view)
                  {} (:Option Option) (:SessionView view)
                    :RouterView $ :router view
                assert= (Option :none) (:user projected)
              :tags $ #{} :client :server :twig :type
        'twig-members $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn twig-members (sessions users)
            -> sessions (.to-list)
              map $ fn (pair)
                let[] (sid raw-session) pair $ let
                    session-data $ assert-type raw-session app.schema/Session
                  [] sid $ match (:user-id session-data)
                    (:none) (Option :none)
                    (:some user-id)
                      if-let
                        raw-user $ get users user-id
                        let
                            user-data $ assert-type raw-user app.schema/User
                          Option :some $ :name user-data
                        Option :none
              pairs-map
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'Map 'Number 'app.schema/Session) (:: 'Map 'String 'app.schema/User)
            :return $ :: 'Map 'Number $ :: 'Option 'String
        'twig-shared $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn twig-shared (db record-count)
            %{} SharedTwig (:reel-length record-count)
              :attached $ %{} AttachedView (:type :msg) (:content "|SOME data")
              :pages $ Option :none
              :members $ twig-members (:sessions db) (:users db)
              :session-count $ count $ :sessions db
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/SharedTwig)
            :args $ [] 'app.schema/Db 'Number
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.twig.container
          :require
            app.twig.user :refer $ twig-user
            recollect.memo :refer $ memo-twig-by1
            app.schema :refer $ AttachedView MessageView RouterView SessionView SharedTwig Store
    'app.twig.partition $ %{} 'FileEntry
      :defs $ {}
        'affected-partitions $ %{} 'CodeEntry
          :doc "|Partitions whose projection may change after one operation, computed from the database before the operation (so log-out still dirties the old user). Only live partitions are re-projected; route changes only alter subscriptions."
          :code $ quote $ defn affected-partitions (db op sid)
            let
                user-keys $ match (app.updater.kanban/session-user-id db sid)
                  (:some user-id)
                    #{} $ PartitionKey :user user-id
                  (:none)
                    assert-type (#{}) (:: 'Set 'app.schema/PartitionKey)
              match op
                (:kanban kanban-op)
                  let
                      board-key $ fn (board-id)
                        hint-fn $ {}
                          :args $ [] 'String
                          :return $ :: 'Set 'app.schema/PartitionKey
                        include
                          include user-keys $ PartitionKey :lobby
                          PartitionKey :board board-id
                    match kanban-op
                      (:board/create _title)
                        include user-keys $ PartitionKey :lobby
                      (:board/rename board-id _title) (board-key board-id)
                      (:column/add board-id _title) (board-key board-id)
                      (:card/add board-id _column-id _title) (board-key board-id)
                      (:card/rename board-id _card-id _title) (board-key board-id)
                      (:card/move board-id _card-id _column-id) (board-key board-id)
                      (:card/shift board-id _card-id _step) (board-key board-id)
                      (:card/remove board-id _card-id) (board-key board-id)
                      (:card/edit-detail board-id _card-id _description) (board-key board-id)
                      (:settings/toggle-compact) user-keys
                      (:settings/set-accent _accent) user-keys
                (:router/change _router)
                  assert-type (#{}) (:: 'Set 'app.schema/PartitionKey)
                (:session/remove-message _message)
                  assert-type (#{}) (:: 'Set 'app.schema/PartitionKey)
                _ $ include user-keys $ PartitionKey :lobby
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'app.schema/Db 'app.schema/DomainOp 'Number
            :return $ :: 'Set 'app.schema/PartitionKey
        'project-lobby $ %{} 'CodeEntry
          :doc "|Bounded public lobby: board briefs and online user names. Passwords and per-session data never enter it."
          :code $ quote $ defn project-lobby (db)
            %{} LobbyView
              :boards $ .filter-map-kv (:boards db)
                fn (id board)
                  hint-fn $ {}
                    :args $ [] 'String 'app.schema/Board
                    :return $ :: 'MapEntryDecision 'String 'app.schema/BoardBrief
                  %:: MapEntryDecision :keep id $ %{} BoardBrief (:id id)
                    :title $ :title board
                    :card-count $ count $ :cards board
              :online $ foldl
                .to-list $ :sessions db
                {}
                fn (acc pair)
                  hint-fn $ {}
                    :args $ [] (:: 'Map 'String 'String) 'Dynamic
                    :return $ :: 'Map 'String 'String
                  let[] (_sid raw-session) pair $ let
                      session $ assert-type raw-session app.schema/Session
                    match (:user-id session)
                      (:none) acc
                      (:some user-id)
                        match
                          get (:users db) user-id
                          (:some raw-user)
                            assoc acc user-id $ :name $ assert-type raw-user app.schema/User
                          (:none) acc
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/LobbyView)
            :args $ [] 'app.schema/Db
        'project-partition $ %{} 'CodeEntry
          :doc "|Project one partition from hot state. The user partition only carries history-rev from cold storage, never the events themselves."
          :code $ quote $ defn project-partition (db cold key)
            match key
              (:lobby)
                PartitionView :lobby $ project-lobby db
              (:board board-id)
                match (board-of db board-id)
                  (:some board) (PartitionView :board board)
                  (:none) (PartitionView :missing)
              (:user user-id)
                match
                  get (:users db) user-id
                  (:none) (PartitionView :missing)
                  (:some raw-user)
                    let
                        user $ assert-type raw-user app.schema/User
                      PartitionView :user $ %{} UserHotView (:id user-id)
                        :name $ :name user
                        :settings $ match
                          get (:settings db) user-id
                          (:some raw) (assert-type raw app.schema/UserSettings)
                          (:none) app.schema/default-settings
                        :history-rev $ match
                          get (:history cold) user-id
                          (:some events) (count events)
                          (:none) 0
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/PartitionView)
            :args $ [] 'app.schema/Db 'app.schema/ColdStore 'app.schema/PartitionKey
        'session-partitions $ %{} 'CodeEntry
          :doc "|Server-side authorization: only signed-in sessions subscribe, only to their own user partition, and to the board they currently route to. Logging out drops every partition."
          :code $ quote $ defn session-partitions (db session)
            match (:user-id session)
              (:none) (#{})
              (:some user-id)
                let
                    router $ :router session
                    base $ #{} (PartitionKey :lobby) (PartitionKey :user user-id)
                  if
                    = :board $ :name router
                    match (:target router)
                      (:some board-id)
                        if
                          option:some? $ board-of db board-id
                          include base $ PartitionKey :board board-id
                          , base
                      (:none) base
                    , base
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'app.schema/Db 'app.schema/Session
            :return $ :: 'Set 'app.schema/PartitionKey
          :tests $ [] $ %{} 'TestEntry (:name |authorization-follows-session)
            :code $ quote $ let
                db0 $ struct-with app.updater.kanban/fixture-db $ :users
                  {} $ |u1 $ %{} app.schema/User (:id |u1) (:name |Ann)
                    :nickname $ Option :none
                    :avatar $ Option :none
                    :password |hash
                db $ app.updater.kanban/apply-kanban db0 (app.schema/KanbanOp :board/create |Plan) 1 |b1 1
                session $ fn (sid)
                  hint-fn $ {}
                    :args $ [] 'Number
                    :return 'app.schema/Session
                  assert-type
                    option:unwrap $ get (:sessions db) sid
                    , app.schema/Session
                on-board $ fn (target)
                  hint-fn $ {}
                    :args $ [] 'String
                    :return 'app.schema/Session
                  struct-with (session 1)
                    :router $ %{} app.schema/Router (:name :board)
                      :target $ Option :some target
              assert= (#{})
                session-partitions db $ session 2
              assert=
                #{} (PartitionKey :lobby) (PartitionKey :user |u1)
                session-partitions db $ session 1
              assert=
                #{} (PartitionKey :lobby) (PartitionKey :user |u1) (PartitionKey :board |b1)
                session-partitions db $ on-board |b1
              assert=
                #{} (PartitionKey :lobby) (PartitionKey :user |u1)
                session-partitions db $ on-board |nope
              match
                project-partition db app.schema/empty-cold-store $ PartitionKey :lobby
                (:lobby lobby)
                  do
                    assert=
                      {} $ |u1 |Ann
                      :online lobby
                    assert= 0 $ :card-count $ option:unwrap
                      get (:boards lobby) |b1
                _ $ raise |Expected-lobby
              assert= (PartitionView :missing)
                project-partition db app.schema/empty-cold-store $ PartitionKey :board |nope
              match
                project-partition db app.schema/empty-cold-store $ PartitionKey :user |u1
                (:user view)
                  do
                    assert= app.schema/default-settings $ :settings view
                    assert= 0 $ :history-rev view
                _ $ raise |Expected-user-view
              assert=
                #{} (PartitionKey :lobby) (PartitionKey :user |u1) (PartitionKey :board |b1)
                affected-partitions db
                  app.schema/DomainOp :kanban $ app.schema/KanbanOp :card/move |b1 |c1 |k1
                  , 1
              assert=
                #{} $ PartitionKey :user |u1
                affected-partitions db
                  app.schema/DomainOp :kanban $ app.schema/KanbanOp :settings/toggle-compact
                  , 1
              assert= (#{})
                affected-partitions db
                  app.schema/DomainOp :router/change $ %{} app.schema/Router (:name :home)
                    :target $ Option :none
                  , 1
            :tags $ #{} :partition :server
      :ns $ %{} 'NsEntry
        :doc "|Pure partition projections, server-side subscription authorization, and per-operation dirty partition derivation."
        :code $ quote $ ns app.twig.partition
          :require
            app.schema :refer $ PartitionKey PartitionView LobbyView BoardBrief UserHotView
            app.updater.kanban :refer $ board-of board-cards
    'app.twig.user $ %{} 'FileEntry
      :defs $ {} $ 'twig-user
        %{} 'CodeEntry (:doc |)
          :code $ quote $ defn twig-user (user-data)
            %{} UserView
              :name $ :name user-data
              :id $ :id user-data
              :nickname $ :nickname user-data
              :avatar $ :avatar user-data
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/UserView)
            :args $ [] 'app.schema/User
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.twig.user
          :require $ app.schema :refer $ UserView
    'app.updater $ %{} 'FileEntry
      :defs $ {} $ 'updater
        %{} 'CodeEntry (:doc |)
          :code $ quote $ defn updater (db op sid op-id op-time)
            match op
              (:session/connect) (session/connect db sid op-id op-time)
              (:session/disconnect) (session/disconnect db sid op-id op-time)
              (:session/remove-message data) (session/remove-message db data sid op-id op-time)
              (:user/log-in username password) (user/log-in db username password sid op-id op-time)
              (:user/sign-up username password) (user/sign-up db username password sid op-id op-time)
              (:user/log-out) (user/log-out db sid op-id op-time)
              (:router/change data) (router/change db data sid op-id op-time)
              (:kanban kanban-op) (kanban/apply-kanban db kanban-op sid op-id op-time)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'app.schema/DomainOp 'Number 'String 'Number
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.updater
          :require (app.updater.session :as session) (app.updater.user :as user) (app.updater.router :as router) (app.schema :as schema)
            app.schema :refer $ Op
            respo-message.updater :refer $ update-messages
            app.updater.kanban :as kanban
    'app.updater.kanban $ %{} 'FileEntry
      :defs $ {}
        'add-card $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn add-card (board column-id title user-id op-id op-time)
            if
              option:some? $ get (:columns board) column-id
              struct-with board $ :cards $ assoc (:cards board) op-id
                %{} Card (:id op-id) (:column-id column-id)
                  :rank $ next-rank $ column-card-ranks board column-id
                  :title title
                  :detail-rev 0
                  :updated-at op-time
                  :updated-by user-id
              , board
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Board)
            :args $ [] 'app.schema/Board 'String 'String 'String 'String 'Number
        'apply-cold-effects $ %{} 'CodeEntry
          :doc "|Append history and replace card details. Per-user history is bounded; trimming shifts cursors, so clients re-read the first page after history-rev changes."
          :code $ quote $ defn apply-cold-effects (cold effects history-limit)
            let
                history $ foldl (:history effects) (:history cold)
                  fn (acc event)
                    hint-fn $ {}
                      :args $ []
                        :: 'Map 'String $ :: 'List 'app.schema/HistoryEvent
                        , 'app.schema/HistoryEvent
                      :return $ :: 'Map 'String $ :: 'List 'app.schema/HistoryEvent
                    let
                        user-id $ :user-id event
                        events $ match (get acc user-id)
                          (:some existing) (conj existing event)
                          (:none) ([] event)
                        size $ count events
                      assoc acc user-id $ if (> size history-limit)
                        slice events (- size history-limit) size
                        , events
                details $ foldl (:details effects) (:details cold)
                  fn (acc detail)
                    hint-fn $ {}
                      :args $ [] (:: 'Map 'String 'app.schema/CardDetail) 'app.schema/CardDetail
                      :return $ :: 'Map 'String 'app.schema/CardDetail
                    assoc acc (:card-id detail) detail
              struct-with cold (:history history) (:details details)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/ColdStore)
            :args $ [] 'app.schema/ColdStore 'app.schema/ColdEffects 'Number
        'apply-kanban $ %{} 'CodeEntry
          :doc "|Pure Kanban reducer. Anonymous sessions and invalid targets leave the database unchanged."
          :code $ quote $ defn apply-kanban (db op sid op-id op-time)
            match (session-user-id db sid)
              (:none) db
              (:some user-id)
                match op
                  (:board/create title)
                    if (blank? title) db $ create-board db (trim title) op-id op-time
                  (:board/rename board-id title)
                    if (blank? title) db $ update-board db board-id $ fn (board)
                      struct-with board $ :title $ trim title
                  (:column/add board-id title)
                    if (blank? title) db $ update-board db board-id $ fn (board)
                      struct-with board $ :columns $ assoc (:columns board) op-id
                        %{} Column (:id op-id)
                          :title $ trim title
                          :rank $ next-rank $ map (board-columns board)
                            fn (column)
                              hint-fn $ {}
                                :args $ [] 'app.schema/Column
                                :return 'Number
                              :rank column
                  (:card/add board-id column-id title)
                    if (blank? title) db $ update-board db board-id $ fn (board)
                      add-card board column-id (trim title) user-id op-id op-time
                  (:card/rename board-id card-id title)
                    if (blank? title) db $ update-board db board-id $ fn (board)
                      update-card board card-id $ fn (card)
                        touch-card
                          struct-with card $ :title $ trim title
                          , user-id op-time
                  (:card/move board-id card-id column-id)
                    update-board db board-id $ fn (board) (move-card board card-id column-id user-id op-time)
                  (:card/shift board-id card-id step)
                    update-board db board-id $ fn (board) (shift-card board card-id step)
                  (:card/remove board-id card-id)
                    update-board db board-id $ fn (board)
                      struct-with board $ :cards $ dissoc (:cards board) card-id
                  (:card/edit-detail board-id card-id _description)
                    update-board db board-id $ fn (board)
                      update-card board card-id $ fn (card)
                        touch-card
                          struct-with card $ :detail-rev $ inc (:detail-rev card)
                          , user-id op-time
                  (:settings/toggle-compact)
                    update-settings db user-id $ fn (settings)
                      struct-with settings $ :compact? $ not (:compact? settings)
                  (:settings/set-accent accent)
                    update-settings db user-id $ fn (settings)
                      struct-with settings $ :accent accent
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'app.schema/KanbanOp 'Number 'String 'Number
          :tests $ [] $ %{} 'TestEntry (:name |board-card-lifecycle)
            :code $ quote $ let
                db0 fixture-db
                anon $ apply-kanban db0 (KanbanOp :board/create |Nope) 2 |bx 1
                db1 $ apply-kanban db0 (KanbanOp :board/create "| Plan ") 1 |b1 1
                db2 $ apply-kanban db1 (KanbanOp :card/add |b1 |b1-todo |A) 1 |c1 2
                db3 $ apply-kanban db2 (KanbanOp :card/add |b1 |b1-todo |B) 1 |c2 3
                db4 $ apply-kanban db3 (KanbanOp :card/shift |b1 |c2 -1) 1 |o4 4
                db5 $ apply-kanban db4 (KanbanOp :card/move |b1 |c1 |b1-done) 1 |o5 5
                blank $ apply-kanban db5 (KanbanOp :card/add |b1 |b1-todo "|  ") 1 |o6 6
                bad-column $ apply-kanban db5 (KanbanOp :card/move |b1 |c2 |missing) 1 |o7 7
                card-in $ fn (db card-id)
                  hint-fn $ {}
                    :args $ [] 'app.schema/Db 'String
                    :return 'app.schema/Card
                  match (board-of db |b1)
                    (:some board)
                      assert-type
                        option:unwrap $ get (:cards board) card-id
                        , app.schema/Card
                    (:none) (raise |Missing-board)
              assert= db0 anon
              assert= |Plan $ :title $ option:unwrap (board-of db1 |b1)
              assert= 3 $ count $ :columns
                option:unwrap $ board-of db1 |b1
              assert= 1 $ :rank $ card-in db2 |c1
              assert= 2 $ :rank $ card-in db3 |c2
              assert= 2 $ :rank $ card-in db4 |c1
              assert= 1 $ :rank $ card-in db4 |c2
              assert= |b1-done $ :column-id $ card-in db5 |c1
              assert= 1 $ :rank $ card-in db5 |c1
              assert= |u1 $ :updated-by $ card-in db5 |c1
              assert= db5 blank
              assert= db5 bad-column
            :tags $ #{} :kanban :server
        'board-cards $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn board-cards (board)
            map
              .to-list $ :cards board
              fn (pair)
                let[] (_id raw-card) pair $ assert-type raw-card app.schema/Card
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'app.schema/Board
            :return $ :: 'List 'app.schema/Card
        'board-columns $ %{} 'CodeEntry (:doc "|Columns ordered by rank.")
          :code $ quote $ defn board-columns (board)
            ->
              .to-list $ :columns board
              map $ fn (pair)
                let[] (_id raw-column) pair $ assert-type raw-column app.schema/Column
              .sort-by $ fn (column)
                hint-fn $ {}
                  :args $ [] 'app.schema/Column
                  :return 'Number
                :rank column
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'app.schema/Board
            :return $ :: 'List 'app.schema/Column
        'board-of $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn board-of (db board-id)
            match
              get (:boards db) board-id
              (:some raw)
                Option :some $ assert-type raw app.schema/Board
              (:none) (Option :none)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'app.schema/Db 'String
            :return $ :: 'Option 'app.schema/Board
        'card-column $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn card-column (board-option card-id)
            match board-option
              (:some board)
                match
                  get (:cards board) card-id
                  (:some raw)
                    :column-id $ assert-type raw app.schema/Card
                  (:none) |
              (:none) |
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ [] (:: 'Option 'app.schema/Board) 'String
        'card-detail-reply $ %{} 'CodeEntry
          :doc "|Read cold card content only while the hot card exists; the returned rev lets clients drop stale responses."
          :code $ quote $ defn card-detail-reply (db cold board-id card-id)
            match (board-of db board-id)
              (:none) (app.schema/QueryReply :missing board-id)
              (:some board)
                match
                  get (:cards board) card-id
                  (:none) (app.schema/QueryReply :missing card-id)
                  (:some _)
                    app.schema/QueryReply :card-detail $ match
                      get (:details cold) card-id
                      (:some raw) (assert-type raw app.schema/CardDetail)
                      (:none)
                        %{} CardDetail (:card-id card-id) (:board-id board-id) (:rev 0) (:description |) (:updated-at 0)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/QueryReply)
            :args $ [] 'app.schema/Db 'app.schema/ColdStore 'String 'String
        'card-title $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn card-title (board-option card-id)
            match board-option
              (:some board)
                match
                  get (:cards board) card-id
                  (:some raw)
                    :title $ assert-type raw app.schema/Card
                  (:none) card-id
              (:none) card-id
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ [] (:: 'Option 'app.schema/Board) 'String
        'column-card-ranks $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn column-card-ranks (board column-id)
            map (column-cards board column-id)
              fn (card)
                hint-fn $ {}
                  :args $ [] 'app.schema/Card
                  :return 'Number
                :rank card
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'app.schema/Board 'String
            :return $ :: 'List 'Number
        'column-cards $ %{} 'CodeEntry (:doc "|Cards of one column ordered by rank.")
          :code $ quote $ defn column-cards (board column-id)
            -> (board-cards board)
              filter $ fn (card)
                hint-fn $ {}
                  :args $ [] 'app.schema/Card
                  :return 'Bool
                = column-id $ :column-id card
              .sort-by $ fn (card)
                hint-fn $ {}
                  :args $ [] 'app.schema/Card
                  :return 'Number
                :rank card
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'app.schema/Board 'String
            :return $ :: 'List 'app.schema/Card
        'column-title $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn column-title (board-option column-id)
            match board-option
              (:some board)
                match
                  get (:columns board) column-id
                  (:some raw)
                    :title $ assert-type raw app.schema/Column
                  (:none) column-id
              (:none) column-id
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ [] (:: 'Option 'app.schema/Board) 'String
        'create-board $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn create-board (db title op-id op-time)
            let
                column $ fn (suffix label rank)
                  hint-fn $ {}
                    :args $ [] 'String 'String 'Number
                    :return 'Dynamic
                  let
                      id $ str op-id |- suffix
                    [] id $ %{} Column (:id id) (:title label) (:rank rank)
                columns $ assert-type
                  pairs-map $ [] (column |todo |Todo 1) (column |doing |Doing 2) (column |done |Done 3)
                  :: 'Map 'String 'app.schema/Column
              struct-with db $ :boards $ assoc (:boards db) op-id
                %{} Board (:id op-id) (:title title) (:created-at op-time) (:columns columns)
                  :cards $ {}
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'String 'String 'Number
        'fixture-db $ %{} 'CodeEntry
          :doc "|Deterministic database with one signed-in session (1) and one anonymous session (2) for reducer tests."
          :code $ quote $ def fixture-db
            %{} app.schema/Db
              :sessions $ {}
                1 $ %{} app.schema/Session (:id 1)
                  :user-id $ Option :some |u1
                  :nickname $ Option :none
                  :router app.schema/router
                  :messages $ {}
                2 $ %{} app.schema/Session (:id 2)
                  :user-id $ Option :none
                  :nickname $ Option :none
                  :router app.schema/router
                  :messages $ {}
              :users $ {}
              :boards $ {}
              :settings $ {}
          :examples $ []
          :schema $ :: 'app.schema/Db
        'history-page $ %{} 'CodeEntry
          :doc "|Newest-first page ending before an exclusive cursor into the append-only log; page size is clamped to 1..50."
          :code $ quote $ defn history-page (cold user-id cursor limit)
            let
                events $ match
                  get (:history cold) user-id
                  (:some existing) existing
                  (:none)
                    assert-type ([]) (:: 'List 'app.schema/HistoryEvent)
                total $ count events
                page-size $ if (< limit 1) 1 $ if (> limit 50) 50 limit
                end $ match cursor
                  (:some position)
                    if (< position 0) 0 $ if (> position total) total position
                  (:none) total
                start $ if (> end page-size) (- end page-size) 0
              %{} app.schema/HistoryPage
                :items $ reverse $ slice events start end
                :next-cursor $ if (> start 0) (Option :some start) (Option :none)
                :history-rev total
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/HistoryPage)
            :args $ [] 'app.schema/ColdStore 'String (:: 'Option 'Number) 'Number
          :tests $ [] $ %{} 'TestEntry (:name |stable-cursor-paging-and-bound)
            :code $ quote $ let
                event $ fn (id)
                  hint-fn $ {}
                    :args $ [] 'String
                    :return 'app.schema/HistoryEvent
                  %{} HistoryEvent (:id id) (:time 0) (:user-id |u1) (:kind :card/add) (:board-id |b1) (:summary id)
                effects $ %{} ColdEffects
                  :history $ map ([] |e1 |e2 |e3 |e4) event
                  :details $ []
                cold $ apply-cold-effects app.schema/empty-cold-store effects 3
                first-page $ history-page cold |u1 (Option :none) 2
                second-page $ history-page cold |u1 (:next-cursor first-page) 2
                ids $ fn (page)
                  hint-fn $ {}
                    :args $ [] 'app.schema/HistoryPage
                    :return $ :: 'List 'String
                  map (:items page)
                    fn (item)
                      hint-fn $ {}
                        :args $ [] 'app.schema/HistoryEvent
                        :return 'String
                      :id item
              assert= 3 $ :history-rev first-page
              assert= ([] |e4 |e3) (ids first-page)
              assert= (Option :some 1) (:next-cursor first-page)
              assert= ([] |e2) (ids second-page)
              assert= (Option :none) (:next-cursor second-page)
              assert= ([])
                :items $ history-page cold |nobody (Option :none) 10
            :tags $ #{} :kanban :server
        'kanban-effects $ %{} 'CodeEntry
          :doc "|Derive cold writes from a committed operation by comparing the touched board before and after; rejected or no-op operations produce no history."
          :code $ quote $ defn kanban-effects (db-before db-after op sid op-id op-time)
            let
                none $ %{} ColdEffects
                  :history $ []
                  :details $ []
                event $ fn (user-id kind board-id summary)
                  hint-fn $ {}
                    :args $ [] 'String 'Tag 'String 'String
                    :return 'app.schema/HistoryEvent
                  %{} HistoryEvent (:id op-id) (:time op-time) (:user-id user-id) (:kind kind) (:board-id board-id) (:summary summary)
                board-change $ fn (board-id)
                  hint-fn $ {}
                    :args $ [] 'String
                    :return $ :: 'Option $ :: 'List 'app.schema/Board
                  let
                      before $ board-of db-before board-id
                      after $ board-of db-after board-id
                    if (= before after) (Option :none)
                      Option :some $ []
                only $ fn (user-id kind board-id summary)
                  hint-fn $ {}
                    :args $ [] 'String 'Tag 'String 'String
                    :return 'app.schema/ColdEffects
                  match (board-change board-id)
                    (:none) none
                    (:some _)
                      %{} ColdEffects
                        :history $ [] $ event user-id kind board-id summary
                        :details $ []
              match (session-user-id db-before sid)
                (:none) none
                (:some user-id)
                  let
                      before-of $ fn (board-id)
                        hint-fn $ {}
                          :args $ [] 'String
                          :return $ :: 'Option 'app.schema/Board
                        board-of db-before board-id
                      after-of $ fn (board-id)
                        hint-fn $ {}
                          :args $ [] 'String
                          :return $ :: 'Option 'app.schema/Board
                        board-of db-after board-id
                    match op
                      (:board/create title)
                        only user-id :board/create op-id $ str "|created board " title
                      (:board/rename board-id title)
                        only user-id :board/rename board-id $ str "|renamed board to " title
                      (:column/add board-id title)
                        only user-id :column/add board-id $ str "|added column " title
                      (:card/add board-id column-id title)
                        only user-id :card/add board-id $ str "|added card " title "| to " $ column-title (after-of board-id) column-id
                      (:card/rename board-id card-id title)
                        only user-id :card/rename board-id $ str "|renamed card "
                          card-title (before-of board-id) card-id
                          , "| to " title
                      (:card/move board-id card-id column-id)
                        only user-id :card/move board-id $ str "|moved "
                          card-title (before-of board-id) card-id
                          , "| from "
                            column-title (before-of board-id)
                              card-column (before-of board-id) card-id
                            , "| to " $ column-title (after-of board-id) column-id
                      (:card/shift board-id card-id _step)
                        only user-id :card/shift board-id $ str "|reordered " $ card-title (before-of board-id) card-id
                      (:card/remove board-id card-id)
                        only user-id :card/remove board-id $ str "|removed card " $ card-title (before-of board-id) card-id
                      (:card/edit-detail board-id card-id description)
                        match (after-of board-id)
                          (:none) none
                          (:some board)
                            match
                              get (:cards board) card-id
                              (:none) none
                              (:some raw-card)
                                let
                                    card $ assert-type raw-card app.schema/Card
                                  %{} ColdEffects
                                    :history $ [] $ event user-id :card/edit-detail board-id
                                      str "|edited description of " $ :title card
                                    :details $ [] $ %{} CardDetail (:card-id card-id) (:board-id board-id)
                                      :rev $ :detail-rev card
                                      :description description
                                      :updated-at op-time
                      (:settings/toggle-compact) none
                      (:settings/set-accent _accent) none
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/ColdEffects)
            :args $ [] 'app.schema/Db 'app.schema/Db 'app.schema/KanbanOp 'Number 'String 'Number
          :tests $ [] $ %{} 'TestEntry (:name |history-and-versioned-detail)
            :code $ quote $ let
                db1 $ apply-kanban fixture-db (KanbanOp :board/create |Plan) 1 |b1 1
                db2 $ apply-kanban db1 (KanbanOp :card/add |b1 |b1-todo |A) 1 |c1 2
                move-op $ KanbanOp :card/move |b1 |c1 |b1-done
                db3 $ apply-kanban db2 move-op 1 |o3 3
                move-effects $ kanban-effects db2 db3 move-op 1 |o3 3
                noop-op $ KanbanOp :card/move |b1 |c1 |missing
                noop-effects $ kanban-effects db3 (apply-kanban db3 noop-op 1 |o4 4) noop-op 1 |o4 4
                edit-op $ KanbanOp :card/edit-detail |b1 |c1 "|Write the spec"
                db4 $ apply-kanban db3 edit-op 1 |o5 5
                edit-effects $ kanban-effects db3 db4 edit-op 1 |o5 5
                cold $ apply-cold-effects (apply-cold-effects app.schema/empty-cold-store move-effects 100) edit-effects 100
              assert= "|moved A from Todo to Done" $ :summary $ option:unwrap
                first $ :history move-effects
              assert= ([]) (:history noop-effects)
              assert= 1 $ :detail-rev $ assert-type
                option:unwrap $ get
                  :cards $ option:unwrap $ board-of db4 |b1
                  , |c1
                , app.schema/Card
              assert= 1 $ :rev $ option:unwrap
                first $ :details edit-effects
              assert= 2 $ count $ option:unwrap
                get (:history cold) |u1
              match (card-detail-reply db4 cold |b1 |c1)
                (:card-detail detail)
                  do
                    assert= 1 $ :rev detail
                    assert= "|Write the spec" $ :description detail
                _ $ raise |Expected-card-detail
              assert= (app.schema/QueryReply :missing |c9) (card-detail-reply db4 cold |b1 |c9)
              match (card-detail-reply db2 app.schema/empty-cold-store |b1 |c1)
                (:card-detail detail)
                  assert= 0 $ :rev detail
                _ $ raise |Expected-empty-detail
            :tags $ #{} :kanban :server
        'move-card $ %{} 'CodeEntry
          :doc "|Move a card to the end of another column by changing two leaves: column-id and rank."
          :code $ quote $ defn move-card (board card-id column-id user-id op-time)
            if
              option:some? $ get (:columns board) column-id
              update-card board card-id $ fn (card)
                if
                  = column-id $ :column-id card
                  , card $ struct-with card (:column-id column-id)
                    :rank $ next-rank $ column-card-ranks board column-id
                    :updated-at op-time
                    :updated-by user-id
              , board
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Board)
            :args $ [] 'app.schema/Board 'String 'String 'String 'Number
        'next-rank $ %{} 'CodeEntry
          :doc "|Rank after the current maximum; appending never rewrites sibling ranks."
          :code $ quote $ defn next-rank (ranks)
            inc $ foldl ranks 0 $ fn (acc rank)
              hint-fn $ {}
                :args $ [] 'Number 'Number
                :return 'Number
              if (> rank acc) rank acc
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Number)
            :args $ [] $ :: 'List 'Number
        'session-user-id $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn session-user-id (db sid)
            match
              get (:sessions db) sid
              (:some raw-session)
                :user-id $ assert-type raw-session app.schema/Session
              (:none) (Option :none)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'app.schema/Db 'Number
            :return $ :: 'Option 'String
        'shift-card $ %{} 'CodeEntry
          :doc "|Swap ranks with the neighbor above or below inside the same column; only two rank leaves change."
          :code $ quote $ defn shift-card (board card-id step)
            match
              get (:cards board) card-id
              (:none) board
              (:some raw-card)
                let
                    card $ assert-type raw-card app.schema/Card
                    siblings $ column-cards board $ :column-id card
                  match
                    find-index siblings $ fn (item)
                      hint-fn $ {}
                        :args $ [] 'app.schema/Card
                        :return 'Bool
                      = card-id $ :id item
                    (:none) board
                    (:some index)
                      match
                        nth siblings $ + index $ if (< step 0) -1 1
                        (:none) board
                        (:some neighbor)
                          struct-with board $ :cards $ -> (:cards board)
                            assoc card-id $ struct-with card $ :rank (:rank neighbor)
                            assoc (:id neighbor)
                              struct-with neighbor $ :rank $ :rank card
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Board)
            :args $ [] 'app.schema/Board 'String 'Number
        'touch-card $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn touch-card (card user-id op-time)
            struct-with card (:updated-at op-time) (:updated-by user-id)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Card)
            :args $ [] 'app.schema/Card 'String 'Number
        'update-board $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn update-board (db board-id f)
            match
              get (:boards db) board-id
              (:some raw-board)
                struct-with db $ :boards $ assoc (:boards db) board-id
                  f $ assert-type raw-board app.schema/Board
              (:none) db
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'String $ :: 'Fn
              {} (:return 'app.schema/Board)
                :args $ [] 'app.schema/Board
        'update-card $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn update-card (board card-id f)
            match
              get (:cards board) card-id
              (:some raw-card)
                struct-with board $ :cards $ assoc (:cards board) card-id
                  f $ assert-type raw-card app.schema/Card
              (:none) board
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Board)
            :args $ [] 'app.schema/Board 'String $ :: 'Fn
              {} (:return 'app.schema/Card)
                :args $ [] 'app.schema/Card
        'update-settings $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn update-settings (db user-id f)
            let
                current $ match
                  get (:settings db) user-id
                  (:some raw) (assert-type raw app.schema/UserSettings)
                  (:none) app.schema/default-settings
              struct-with db $ :settings $ assoc (:settings db) user-id (f current)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'String $ :: 'Fn
              {} (:return 'app.schema/UserSettings)
                :args $ [] 'app.schema/UserSettings
      :ns $ %{} 'NsEntry
        :doc "|Pure Kanban reducer plus pure derivation of cold effects (history and card details) from one committed operation."
        :code $ quote $ ns app.updater.kanban
          :require $ app.schema :refer $ Board Column Card UserSettings KanbanOp HistoryEvent CardDetail ColdStore ColdEffects
    'app.updater.router $ %{} 'FileEntry
      :defs $ {} $ 'change
        %{} 'CodeEntry (:doc |)
          :code $ quote $ defn change (db op-data sid op-id op-time)
            if-let
              raw-session $ get (:sessions db) sid
              let
                  session-data $ assert-type raw-session app.schema/Session
                struct-with db $ :sessions $ assoc (:sessions db) sid
                  struct-with session-data $ :router op-data
              , db
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'app.schema/Router 'Number 'String 'Number
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.updater.router
    'app.updater.session $ %{} 'FileEntry
      :defs $ {}
        'connect $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn connect (db sid op-id op-time)
            struct-with db $ :sessions $ assoc (:sessions db) sid
              %{} schema/Session
                :user-id $ Option :none
                :id sid
                :nickname $ Option :none
                :router schema/router
                :messages $ {}
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'Number 'String 'Number
        'disconnect $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn disconnect (db sid op-id op-time)
            struct-with db $ :sessions $ dissoc (:sessions db) sid
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'Number 'String 'Number
        'remove-message $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn remove-message (db op-data sid op-id op-time)
            if-let
              raw-session $ get (:sessions db) sid
              let
                  session-data $ assert-type raw-session app.schema/Session
                struct-with db $ :sessions $ assoc (:sessions db) sid
                  struct-with session-data $ :messages $ dissoc (:messages session-data) (:id op-data)
              , db
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'app.schema/RemoveMessage 'Number 'String 'Number
          :tests $ [] $ %{} 'TestEntry (:name |existing-message-map-callback)
            :code $ quote $ let
                sid 1
                session-data $ %{} app.schema/Session (:id sid)
                  :user-id $ Option :none
                  :nickname $ Option :none
                  :router $ %{} app.schema/Router (:name :home)
                    :target $ Option :none
                  :messages $ {}
                    |m1 $ %{} app.schema/Message (:id |m1) (:text |remove)
                    |m2 $ %{} app.schema/Message (:id |m2) (:text |keep)
                db $ %{} app.schema/Db
                  :sessions $ {} $ sid session-data
                  :users $ {}
                  :boards $ {}
                  :settings $ {}
                result $ remove-message db
                  %{} app.schema/RemoveMessage $ :id |m1
                  , sid |op 0
                raw-session $ option:unwrap $ get (:sessions result) sid
                next-session $ assert-type raw-session app.schema/Session
                next-message $ assert-type
                  option:unwrap $ get (:messages next-session) |m2
                  , app.schema/Message
              assert= (Option :none)
                get (:messages next-session) |m1
              assert= |keep $ :text next-message
            :tags $ #{} :protocol :server
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.updater.session
          :require $ app.schema :as schema
    'app.updater.user $ %{} 'FileEntry
      :defs $ {}
        'log-in $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn log-in (db username password sid op-id op-time)
            let
                maybe-user $ find
                  -> (:users db) vals .to-list
                  fn (raw-user)
                    let
                        user-data $ assert-type raw-user app.schema/User
                      = username $ :name user-data
              if-let
                raw-session $ get (:sessions db) sid
                let
                    session-data $ assert-type raw-session app.schema/Session
                  struct-with db $ :sessions $ assoc (:sessions db) sid
                    if-let (raw-user maybe-user)
                      let
                          user-data $ assert-type raw-user app.schema/User
                        if
                          = (md5 password) (:password user-data)
                          struct-with session-data $ :user-id $ Option :some (:id user-data)
                          struct-with session-data $ :messages $ assoc (:messages session-data) op-id
                            %{} app.schema/Message (:id op-id)
                              :text $ str "|Wrong password for " username
                      struct-with session-data $ :messages $ assoc (:messages session-data) op-id
                        %{} app.schema/Message (:id op-id)
                          :text $ str "|No user named: " username
                , db
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'String 'String 'Number 'String 'Number
          :tests $ [] $ %{} 'TestEntry (:name |existing-session-callbacks)
            :code $ quote $ let
                sid 1
                session-data $ %{} app.schema/Session (:id sid)
                  :user-id $ Option :none
                  :nickname $ Option :none
                  :router app.schema/router
                  :messages $ {}
                user-data $ %{} app.schema/User (:id |user-1) (:name |demo)
                  :nickname $ Option :none
                  :avatar $ Option :none
                  :password $ md5 |secret
                db $ %{} app.schema/Db
                  :sessions $ {} $ sid session-data
                  :users $ {} $ |user-1 user-data
                  :boards $ {}
                  :settings $ {}
                missing $ log-in db |missing |secret sid |op-missing 0
                wrong $ log-in db |demo |wrong sid |op-wrong 0
                success $ log-in db |demo |secret sid |op-success 0
                missing-session $ assert-type
                  option:unwrap $ get (:sessions missing) sid
                  , app.schema/Session
                wrong-session $ assert-type
                  option:unwrap $ get (:sessions wrong) sid
                  , app.schema/Session
                success-session $ assert-type
                  option:unwrap $ get (:sessions success) sid
                  , app.schema/Session
                missing-message $ assert-type
                  option:unwrap $ get (:messages missing-session) |op-missing
                  , app.schema/Message
                wrong-message $ assert-type
                  option:unwrap $ get (:messages wrong-session) |op-wrong
                  , app.schema/Message
              assert= "|No user named: missing" $ :text missing-message
              assert= "|Wrong password for demo" $ :text wrong-message
              assert= (Option :some |user-1) (:user-id success-session)
            :tags $ #{} :protocol :server
        'log-out $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn log-out (db sid op-id op-time)
            if-let
              raw-session $ get (:sessions db) sid
              let
                  session-data $ assert-type raw-session app.schema/Session
                struct-with db $ :sessions $ assoc (:sessions db) sid
                  struct-with session-data $ :user-id $ Option :none
              , db
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'Number 'String 'Number
        'sign-up $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn sign-up (db username password sid op-id op-time)
            let
                maybe-user $ find
                  -> (:users db) vals .to-list
                  fn (raw-user)
                    let
                        user-data $ assert-type raw-user app.schema/User
                      = username $ :name user-data
              if-let
                raw-session $ get (:sessions db) sid
                let
                    session-data $ assert-type raw-session app.schema/Session
                  if (option:some? maybe-user)
                    struct-with db $ :sessions $ assoc (:sessions db) sid
                      struct-with session-data $ :messages $ assoc (:messages session-data) op-id
                        %{} app.schema/Message (:id op-id)
                          :text $ str "|Name is taken: " username
                    -> db
                      struct-with $ :sessions $ assoc (:sessions db) sid
                        struct-with session-data $ :user-id $ Option :some op-id
                      struct-with $ :users $ assoc (:users db) op-id
                        %{} app.schema/User (:id op-id) (:name username)
                          :nickname $ Option :some username
                          :password $ md5 password
                          :avatar $ Option :none
                , db
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Db)
            :args $ [] 'app.schema/Db 'String 'String 'Number 'String 'Number
          :tests $ [] $ %{} 'TestEntry (:name |duplicate-user-message-callback)
            :code $ quote $ let
                sid 1
                session-data $ %{} app.schema/Session (:id sid)
                  :user-id $ Option :none
                  :nickname $ Option :none
                  :router app.schema/router
                  :messages $ {}
                user-data $ %{} app.schema/User (:id |user-1) (:name |demo)
                  :nickname $ Option :none
                  :avatar $ Option :none
                  :password $ md5 |secret
                db $ %{} app.schema/Db
                  :sessions $ {} $ sid session-data
                  :users $ {} $ |user-1 user-data
                  :boards $ {}
                  :settings $ {}
                result $ sign-up db |demo |secret sid |op-taken 0
                next-session $ assert-type
                  option:unwrap $ get (:sessions result) sid
                  , app.schema/Session
                next-message $ assert-type
                  option:unwrap $ get (:messages next-session) |op-taken
                  , app.schema/Message
              assert= "|Name is taken: demo" $ :text next-message
            :tags $ #{} :protocol :server
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.updater.user
          :require $ calcit.std.hash :refer $ md5
    'app.workload.diff-patch $ %{} 'FileEntry
      :defs $ {}
        'DomainOp $ %{} 'CodeEntry
          :doc "|A replayable state transition covering no-op, leaf, insert, remove, reorder, and replacement cases."
          :code $ quote $ defenum DomainOp (:noop) (:set-label 'String 'String) (:insert 'Entity) (:remove 'String)
            :reorder $ :: 'List 'String
            :replace $ :: 'List 'Entity
          :examples $ []
          :schema $ :: 'EnumDef
        'Entity $ %{} 'CodeEntry
          :doc "|One deterministic keyed entity used by the workload."
          :code $ quote $ defstruct Entity (:id 'String) (:rank 'Number) (:label 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'WorkloadInput $ %{} 'CodeEntry
          :doc "|A fixed seed, base state, and deterministic DomainOp sequence."
          :code $ quote $ defstruct WorkloadInput (:seed 'Number) (:base 'WorkloadState)
            :ops $ :: 'List 'DomainOp
          :examples $ []
          :schema $ :: 'StructDef
        'WorkloadState $ %{} 'CodeEntry
          :doc "|Server-side keyed entities plus their explicit presentation order."
          :code $ quote $ defstruct WorkloadState
            :entities $ :: 'Map 'String 'Entity
            :order $ :: 'List 'String
          :examples $ []
          :schema $ :: 'StructDef
        'WorkloadStore $ %{} 'CodeEntry
          :doc "|Client projection consumed by data diff and browser rendering."
          :code $ quote $ defstruct WorkloadStore
            :rows $ :: 'List 'Entity
            :count 'Number
          :examples $ []
          :schema $ :: 'StructDef
        'apply-domain-op $ %{} 'CodeEntry
          :doc "|Apply one DomainOp without mutating the previous WorkloadState."
          :code $ quote $ defn apply-domain-op (state op)
            match op
              (:noop) state
              (:set-label id label)
                match
                  get (:entities state) id
                  (:some entity)
                    %{} WorkloadState
                      :order $ :order state
                      :entities $ assoc (:entities state) id $ struct-with entity (:label label)
                  (:none) state
              (:insert raw-entity)
                let
                    entity $ assert-type raw-entity Entity
                    entity-id $ :id entity
                    next-entities $ assoc (:entities state) entity-id entity
                    next-order $ append (:order state) entity-id
                  %{} WorkloadState (:entities next-entities) (:order next-order)
              (:remove id)
                %{} WorkloadState
                  :entities $ dissoc (:entities state) id
                  :order $ filter (:order state)
                    fn (item-id) (not= item-id id)
              (:reorder order)
                %{} WorkloadState
                  :entities $ :entities state
                  :order order
              (:replace entities)
                %{} WorkloadState
                  :entities $ entities-by-id entities
                  :order $ map entities $ fn (raw-entity)
                    let
                        entity $ assert-type raw-entity Entity
                      :id entity
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'WorkloadState)
            :args $ [] 'WorkloadState 'DomainOp
          :tags $ #{} :scaffold
        'entities-by-id $ %{} 'CodeEntry (:doc "|Index an entity list by its stable identifier.")
          :code $ quote $ defn entities-by-id (entities)
            -> entities
              map $ fn (raw-entity)
                let
                    entity $ assert-type raw-entity Entity
                  [] (:id entity) entity
              pairs-map
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] $ :: 'List 'Entity
            :return $ :: 'Map 'String 'Entity
          :tags $ #{} :scaffold
        'entity-id $ %{} 'CodeEntry
          :doc "|Derive a stable entity key from the fixed seed and index."
          :code $ quote $ defn entity-id (seed index) (str |entity- seed |- index)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ [] 'Number 'Number
          :tags $ #{} :scaffold
        'main! $ %{} 'CodeEntry
          :doc "|Provide a side-effect-free entry for deterministic workload code generation."
          :code $ quote $ defn main! ()
            let
                input-data $ make-workload-input 2 794
                next-state $ replay-domain-ops (:base input-data) (:ops input-data)
                next-store $ project-state next-state
              do (workload-view next-store) &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
          :tags $ #{} :scaffold
        'make-entity $ %{} 'CodeEntry (:doc "|Construct one deterministic typed entity.")
          :code $ quote $ defn make-entity (seed index)
            %{} Entity
              :id $ entity-id seed index
              :rank index
              :label $ str |item- seed |- index
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Entity)
            :args $ [] 'Number 'Number
          :tags $ #{} :scaffold
        'make-workload-input $ %{} 'CodeEntry
          :doc "|Construct a deterministic workload of the requested size and seed."
          :code $ quote $ defn make-workload-input (size seed)
            let
                entities $ map (range size)
                  fn (index) (make-entity seed index)
                order $ map entities $ fn (raw-entity)
                  let
                      entity $ assert-type raw-entity Entity
                    :id entity
                base $ %{} WorkloadState
                  :entities $ entities-by-id entities
                  :order order
                inserted $ make-entity seed size
                inserted-id $ :id inserted
                extended-order $ append order inserted-id
                removed-id $ entity-id seed 1
                trimmed-order $ dissoc extended-order 1
                reordered $ reverse trimmed-order
                replacement $ map (range size)
                  fn (index)
                    make-entity (inc seed) index
                ops $ [] (DomainOp :noop)
                  DomainOp :set-label (entity-id seed 0) |updated
                  DomainOp :insert inserted
                  DomainOp :remove removed-id
                  DomainOp :reorder reordered
                  DomainOp :replace replacement
              %{} WorkloadInput (:seed seed) (:base base) (:ops ops)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'WorkloadInput)
            :args $ [] 'Number 'Number
          :tags $ #{} :scaffold
          :tests $ [] $ %{} 'TestEntry (:name |deterministic-shape)
            :code $ quote $ let
                input-data $ make-workload-input 4 794
                base-state $ :base input-data
                operations $ :ops input-data
              do
                assert= 4 $ count $ :order base-state
                assert= 6 $ count operations
            :tags $ #{} :client
        'project-state $ %{} 'CodeEntry
          :doc "|Project ordered keyed entities into the client WorkloadStore."
          :code $ quote $ defn project-state (state)
            let
                rows $ map (:order state)
                  fn (id)
                    option:unwrap $ get (:entities state) id
              %{} WorkloadStore (:rows rows)
                :count $ count rows
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'WorkloadStore)
            :args $ [] 'WorkloadState
          :tags $ #{} :scaffold
        'replay-domain-ops $ %{} 'CodeEntry
          :doc "|Replay the same DomainOp sequence against a WorkloadState."
          :code $ quote $ defn replay-domain-ops (state ops)
            list-match ops
              () state
              (op remaining)
                recur (apply-domain-op state op) remaining
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'WorkloadState)
            :args $ [] 'WorkloadState $ :: 'List 'DomainOp
          :tags $ #{} :scaffold
          :tests $ [] $ %{} 'TestEntry (:name |deterministic-replay)
            :code $ quote $ let
                input-data $ make-workload-input 4 794
                final-state $ replay-domain-ops (:base input-data) (:ops input-data)
                final-store $ project-state final-state
                raw-first-row $ option:unwrap $ nth (:rows final-store) 0
                first-row $ assert-type raw-first-row Entity
              do
                assert= 4 $ :count final-store
                assert= |entity-795-0 $ :id first-row
            :tags $ #{} :client
        'workload-ref! $ %{} 'CodeEntry
          :doc "|Stable no-op ref callback used to detect unexpected ref churn at the browser FFI boundary."
          :code $ quote $ defn workload-ref! (_target) &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'respo.dom/DomElement
            :features $ #{} :js-ffi
          :tags $ #{} :scaffold
        'workload-view $ %{} 'CodeEntry
          :doc "|Render keyed rows plus stable focus and listener probes for browser checks."
          :code $ quote $ defn workload-view (store)
            div
              {} $ :class-name |workload-root
              input $ {} (:id |workload-focus-probe) (:value |focus-probe) (:ref workload-ref!)
                :on-input $ fn (_event _dispatch!) &unit
              list->
                {} $ :class-name |workload-rows
                map (:rows store)
                  fn (raw-entity)
                    let
                        entity $ assert-type raw-entity Entity
                      [] (:id entity)
                        div $ {} (:class-name |workload-row)
                          :data-name $ :id entity
                          :inner-text $ str (:rank entity) |: $ :label entity
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Element)
            :args $ [] 'WorkloadStore
          :tags $ #{} :scaffold
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.workload.diff-patch
          :require
            respo.core :refer $ div input list->
            recollect.diff :refer $ diff-twig
            recollect.patch :refer $ patch-twig
