
{} (:about "|Machine-generated snapshot. Do not edit directly — changes will be overwritten. Use `calcit query` to inspect and `calcit edit`/`calcit tree` to modify. Run `calcit docs agents --full` first. Manual edits must follow format and schema conventions, then run `calcit edit format`.") (:package |app)
  :entries $ {}
    :default $ {} (:description |) (:init-fn 'app.client/main!) (:mode :js) (:reload-fn 'app.client/reload!)
      :feature-policy $ {}
      :modules $ [] |respo.calcit/ |recollect/ |respo-ui.calcit/ |ws-edn.calcit/ |cumulo-util.calcit/ |respo-message.calcit/ |cumulo-reel.calcit/ |js-ffi/
      :type-slots $ {} (:dispatch-op |app.schema/Op)
    :server $ {} (:description |) (:init-fn 'app.server/main!) (:mode :native) (:reload-fn 'app.server/reload!)
      :feature-policy $ {}
      :modules $ [] |recollect/ |ws-edn.calcit/ |cumulo-util.calcit/ |cumulo-reel.calcit/ |calcit-wss/ |calcit.std/
      :type-slots $ {} (:dispatch-op |app.schema/Op)
  :files $ {}
    'app.client $ %{} 'FileEntry
      :defs $ {}
        '*activity-cleanup $ %{} 'CodeEntry (:doc "|Cleanup capability for Calcium application-level browser activity signals.")
          :code $ quote
            defatom *activity-cleanup $ %none
          :examples $ []
          :schema $ :: 'Ref (:: 'Option 'Fn)
        '*connected? $ %{} 'CodeEntry (:doc |)
          :code $ quote (defatom *connected? false)
          :examples $ []
          :schema $ :: 'Dynamic
        '*states $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *states $ {}
              :states $ {}
                :cursor $ []
          :examples $ []
          :schema $ :: 'Dynamic
        '*store $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *store $ ClientState :loading
          :examples $ []
          :schema $ :: 'Ref 'app.client/ClientState
        '*sync-revision $ %{} 'CodeEntry (:doc |)
          :code $ quote (defatom *sync-revision 0)
          :examples $ []
          :schema $ :: 'Dynamic
        '*ws-client $ %{} 'CodeEntry (:doc "|Current nominal ws-edn client, retained across browser recovery events.")
          :code $ quote
            defatom *ws-client $ %none
          :examples $ []
          :schema $ :: 'Ref (:: 'Option 'ws-edn.client/WsClient)
        'ClientPatchError $ %{} 'CodeEntry (:doc "|Client-side reason for rejecting a revisioned patch before requesting a full snapshot.")
          :code $ quote
            defenum ClientPatchError (:revision-mismatch 'Number 'Number) (:invalid-patch 'recollect.patch/PatchError)
          :examples $ []
          :schema $ :: 'EnumDef
        'ClientState $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defenum ClientState (:loading) (:offline) (:ready 'app.schema/Store)
          :examples $ []
          :schema $ :: 'EnumDef
        'ack-sync! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn ack-sync! (revision)
              ws-send! $ %:: schema/ClientMessage :sync/ack revision
          :examples $ []
          :schema $ :: 'Dynamic
        'apply-server-patch! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn apply-server-patch! (base-revision revision changes)
              match @*store
                (:ready store)
                  match (validate-server-patch store @*sync-revision base-revision changes)
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
                        request-snapshot!
                (:loading) (request-snapshot!)
                (:offline) (request-snapshot!)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Number 'Number (:: 'List 'recollect.schema/change-op)
        'cleanup-activity-lifecycle! $ %{} 'CodeEntry (:doc "|Run and clear the current application activity cleanup capability.")
          :code $ quote
            defn cleanup-activity-lifecycle! () $ do
              match @*activity-cleanup
                (:some cleanup) (cleanup)
                (:none) &unit
              reset! *activity-cleanup $ %none
              , &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'connect! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn connect! () $ let
                url-object $ unsafe-coerce (url-parse js/location.href true) 'JsObject
                query $ unsafe-coerce (.-query url-object) 'JsObject
                host-value $ .-host query
                port-value $ .-port query
                host $ if (js-present? host-value) (unsafe-coerce host-value 'String) (unsafe-coerce js/location.hostname 'String)
                port $ if (js-present? port-value) (unsafe-coerce port-value 'String)
                  str $ option:unwrap (get config/site :port)
              reset! *store $ ClientState :loading
              reset! *ws-client $ %some
                ws-connect! (str |ws:// host |: port)
                  {}
                    :on-open $ fn (event)
                      do (reset! *connected? true) (request-snapshot!) (send-activity!) (simulate-login!)
                    :on-close $ fn (event) (reset! *connected? false)
                      reset! *store $ ClientState :offline
                      js/console.error "|Lost connection!"
                    :on-data on-server-data
                    :heartbeat-timeout-ms 75000
                    :class-mapper $ {} (:Option Option) (:Store schema/Store) (:SessionView schema/SessionView) (:RouterView schema/RouterView) (:AttachedView schema/AttachedView) (:UserView schema/UserView) (:MessageView schema/MessageView) (:ServerMessage schema/ServerMessage) (:change-op patch-schema/change-op)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'dispatch! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn dispatch! (op ? op-data)
              when
                and config/dev? $ match op
                  (:states _ _) false
                  _ true
                println |Dispatch op op-data
              if (tag? op)
                recur $ :: op op-data
                match op
                  (:states cursor s)
                    reset! *states $ update-states @*states cursor s
                  (:effect/connect) (connect!)
                  _ $ ws-send! (%:: schema/ClientMessage :dispatch op)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Dynamic)
              :args $ [] 'app.schema/Op 'Dynamic
        'install-activity-lifecycle! $ %{} 'CodeEntry (:doc "|Install one cleanup-backed application activity watcher without duplicating ws-edn reconnect ownership.")
          :code $ quote
            defn install-activity-lifecycle! () $ do (cleanup-activity-lifecycle!)
              let
                  cleanup $ watch-browser-lifecycle!
                    fn (signal)
                      cond
                          = signal :visible
                          when @*connected? $ send-activity!
                        (= signal :hidden)
                          when @*connected? $ send-activity!
                        (= signal :heartbeat)
                          when @*connected? $ ws-send! (schema/ClientMessage :sync/heartbeat @*sync-revision)
                        true &unit
                    %some 30000
                reset! *activity-cleanup $ %some cleanup
                , &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
              :features $ #{} :js-ffi
        'main! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn main! () $ do
              println "|Running mode:" $ if config/dev? |dev |release
              if config/dev? $ load-console-formatter!
              render-app!
              connect!
              add-watch *store :changes $ fn (store prev) (render-app!)
              add-watch *states :changes $ fn (states prev) (render-app!)
              install-activity-lifecycle!
              workload-entry!
              println "|App started!"
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Dynamic)
              :args $ []
              :features $ #{} :js-ffi
        'mount-target $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def mount-target $ js/document.querySelector |.app
          :examples $ []
          :schema $ :: 'Dynamic
        'on-server-data $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn on-server-data (data)
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
                (:err error) (eprintln "|Invalid server message:" error)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Dynamic
        'reload! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn reload! () $ if (some? client-errors) (hud! |error client-errors)
              do (hud! |inactive nil) (remove-watch *store :changes) (remove-watch *states :changes) (clear-cache!) (render-app!)
                add-watch *store :changes $ fn (store prev) (render-app!)
                add-watch *states :changes $ fn (states prev) (render-app!)
                install-activity-lifecycle!
                ws-set-on-data! on-server-data
                println "|Code updated."
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'render-app! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn render-app! () $ let
                states $ match (get @*states :states)
                  (:some value) value
                  (:none) ({})
                app $ match @*store
                  (:loading)
                    comp-offline $ :: :loading
                  (:offline)
                    comp-offline $ :: :offline
                  (:ready store) (comp-container states store)
              render! mount-target app dispatch!
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'request-snapshot! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn request-snapshot! () $ ws-send! (%:: schema/ClientMessage :sync/resume @*sync-revision)
          :examples $ []
          :schema $ :: 'Dynamic
        'send-activity! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn send-activity! () $ if (page-visible?)
              ws-send! $ %:: schema/ClientMessage :sync/active @*sync-revision
              ws-send! $ %:: schema/ClientMessage :sync/idle @*sync-revision
          :examples $ []
          :schema $ :: 'Dynamic
        'simulate-login! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn simulate-login! () $ let
                raw $ js/localStorage.getItem
                  option:unwrap $ get config/site :storage-key
              if (js-present? raw)
                let
                    pair $ parse-cirru-edn (unsafe-coerce raw 'String)
                  do (println "|Found storage.")
                    dispatch! $ %:: app.schema/Op :user/log-in
                      option:unwrap $ nth pair 0
                      option:unwrap $ nth pair 1
                println "|Found no storage."
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'validate-server-patch $ %{} 'CodeEntry (:doc "|Validate base revision and apply one patch batch without mutating client state.")
          :code $ quote
            defn validate-server-patch (store local-revision base-revision changes)
              if (= base-revision local-revision)
                match
                  .apply-to
                    assert-traits (patch-batch changes) PatchBatchOps
                    , store
                  (:ok next-store) (%ok next-store)
                  (:err error)
                    %err $ %:: ClientPatchError :invalid-patch error
                %err $ %:: ClientPatchError :revision-mismatch base-revision local-revision
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'T 'Number 'Number (:: 'List 'recollect.schema/change-op)
              :generics $ [] 'T
              :return $ :: 'Result 'T 'app.client/ClientPatchError
          :tests $ []
            %{} 'TestEntry (:name |accepts-valid-revisioned-patch)
              :code $ quote
                let
                    store $ {} (:value 1)
                    changes $ [] (%:: patch-schema/change-op :assoc :value 2)
                  assert=
                    %ok $ {} (:value 2)
                    validate-server-patch store 7 7 changes
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-revision-mismatch)
              :code $ quote
                let
                    store $ {} (:value 1)
                    changes $ []
                  assert=
                    %err $ %:: ClientPatchError :revision-mismatch 8 7
                    validate-server-patch store 7 8 changes
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-invalid-patch-atomically)
              :code $ quote
                let
                    store $ {} (:stable 1)
                    changes $ [] (%:: patch-schema/change-op :assoc :temporary 2)
                      %:: patch-schema/change-op :update :missing $ %:: patch-schema/change-op :replace 3
                    expected $ %err
                      %:: ClientPatchError :invalid-patch $ %:: PatchError :missing-node
                        [] $ %:: PatchPathSegment :field :missing
                  assert= expected $ validate-server-patch store 9 9 changes
                  assert=
                    {} $ :stable 1
                    , store
              :tags $ #{} :client
            %{} 'TestEntry (:name |ready-store-retains-nominal-state)
              :code $ quote
                let
                    db app.schema/database
                    shared $ app.twig.container/twig-shared db 0
                    store $ app.twig.container/twig-container db app.schema/session shared
                    state $ match
                      validate-server-patch store 7 7 $ []
                      (:ok next-store) (ClientState :ready next-store)
                      (:err error) (raise |Unexpected-patch-error)
                  assert= (ClientState :ready store) state
                  match state
                    (:ready next-store) (assert= store next-store)
                    _ $ raise |Expected-ready-state
              :tags $ #{} :client
        'workload-entry! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn workload-entry! () $ workload/main!
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.client $ :require
            respo.core :refer $ render! clear-cache! realize-ssr! div <>
            respo.cursor :refer $ update-states
            app.comp.container :refer $ comp-container comp-offline
            app.schema :as schema
            app.schema :refer $ Op
            app.config :as config
            ws-edn.client :refer $ ws-connect! ws-send! ws-set-on-data!
            recollect.patch :refer $ patch-batch patch-error-message PatchError PatchPathSegment PatchBatchOps
            |url-parse :default url-parse
            |bottom-tip :default hud!
            |./calcit.build-errors :default client-errors
            recollect.schema :as patch-schema
            cumulo-util.activity :refer $ watch-browser-lifecycle! page-visible?
            app.workload.diff-patch :as workload
    'app.comp.container $ %{} 'FileEntry
      :defs $ {}
        'comp-container $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defcomp comp-container (states store)
              let
                  state $ option:unwrap-or (get states :data)
                    {} $ :demo |
                  session $ :session store
                  router $ :router store
                  router-data $ option:unwrap-or (:data router) ({})
                  logged-in? $ :logged-in? store
                div
                  {} $ :class-name (str-spaced css/preset css/global css/fullscreen css/column)
                  comp-navigation logged-in? $ :count store
                  if logged-in?
                    case-default (:name router)
                      <> $ str router
                      :home $ div
                        {} (:class-name css/expand)
                          :style $ {} (:padding |8px)
                        input $ {} (:class-name css/input)
                          :value $ option:unwrap-or (get state :demo) |
                        =< 8 nil
                        <> "|demo page"
                        pre $ {}
                          :style $ {} (:line-height 1.4) (:padding 4)
                            :border $ str "|1px solid #ddd"
                          :inner-text $ str "|backend data" (format-cirru-edn store)
                      :profile $ comp-profile
                        option:unwrap $ :user store
                        , router-data
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
          :schema $ :: 'Fn
            {} (:return 'respo.schema/Component)
              :args $ [] 'Map 'app.schema/Store
        'comp-offline $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defcomp comp-offline (mark)
              div
                {} $ :style
                  merge ui/global ui/fullscreen ui/column-dispersive $ {}
                    :background-color $ site-theme
                div $ {}
                  :style $ {} (:height 0)
                div $ {}
                  :style $ {}
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
          :schema $ :: 'Fn
            {} (:return 'respo.schema/Component)
              :args $ [] 'Dynamic
        'comp-session-messages $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defcomp comp-session-messages (messages)
              list->
                {} $ :style
                  {} (:position :fixed) (:top 8) (:right 8) (:z-index 1000)
                -> messages
                  filter-map-kv $ fn (id message)
                    hint-fn $ {}
                      :args $ [] 'String 'app.schema/MessageView
                      :return $ :: 'MapEntryDecision 'String 'respo.schema/Element
                    %:: MapEntryDecision :keep id $ div
                      {}
                        :style $ {} (:padding 8) (:margin-bottom 8)
                          :background-color $ hsl 0 80 95
                          :border $ str "|1px solid " (hsl 0 70 80)
                          :border-radius 4
                          :cursor :pointer
                        :on-click $ fn (e d!)
                          d! $ %:: schema/Op :session/remove-message
                            %{} schema/RemoveMessage $ :id id
                      <> (:text message) nil
                  .to-list
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'respo.schema/Component)
              :args $ [] (:: 'Map 'String 'app.schema/MessageView)
        'comp-status-color $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defcomp comp-status-color (color)
              div $ {} (:class-name css-status-color)
                :style $ let
                    size 24
                  {} (:width size) (:height size) (:background-color color)
          :examples $ []
          :schema $ :: 'Dynamic
        'css-status-color $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstyle css-status-color $ {}
              |$0 $ {} (:position :absolute) (:bottom 60) (:left 8) (:border-radius |50%) (:opacity 0.6) (:pointer-events :none)
          :examples $ []
          :schema $ :: 'Dynamic
        'site-icon $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn site-icon () $ assert-type (&map:get config/site :icon) String
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'String)
              :args $ []
        'site-theme $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn site-theme () $ assert-type (&map:get config/site :theme) String
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'String)
              :args $ []
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.comp.container $ :require
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
          :code $ quote
            defcomp comp-login (states)
              let
                  cursor $ option:unwrap-or (get states :cursor) ([])
                  state $ option:unwrap-or (get states :data) initial-state
                div
                  {} $ :class-name (str-spaced css/flex css/center)
                  div ({})
                    div ({})
                      div ({})
                        input $ {} (:placeholder |Username) (:class-name css/input)
                          :value $ option:unwrap-or (get state :username) |
                          :on-input $ fn (e d!)
                            let
                                value $ get e :value
                              d! $ %:: schema/Op :states cursor
                                assoc state :username $ value .unwrap-or |
                      =< nil 8
                      div ({})
                        input $ {} (:placeholder |Password) (:class-name css/input)
                          :value $ option:unwrap-or (get state :password) |
                          :on-input $ fn (e d!)
                            let
                                value $ get e :value
                              d! $ %:: schema/Op :states cursor
                                assoc state :password $ value .unwrap-or |
                    =< nil 8
                    div
                      {} $ :style
                        {} $ :text-align :right
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
          :schema $ :: 'Dynamic
        'initial-state $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def initial-state $ {} (:username |) (:password |)
          :examples $ []
          :schema $ :: 'Dynamic
        'on-submit $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn on-submit (username password signup?)
              fn (e dispatch!)
                dispatch! $ if signup? (%:: app.schema/Op :user/sign-up username password) (%:: app.schema/Op :user/log-in username password)
                when (js-present? js/localStorage)
                  let
                      storage $ unsafe-coerce js/localStorage 'JsObject
                    .!setItem storage
                      option:unwrap $ get config/site :storage-key
                      format-cirru-edn $ [] username password
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Fn)
              :args $ [] 'String 'String 'Bool
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.comp.login $ :require
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
          :code $ quote
            defcomp comp-navigation (logged-in? count-members)
              div
                {} $ :class-name (str-spaced css/row-center css-navigation)
                div
                  {}
                    :on-click $ fn (e d!)
                      d! $ %:: app.schema/Op :router/change
                        %{} app.schema/Router $ :name :home
                    :style $ {} (:cursor :pointer)
                  <>
                    option:unwrap-or (get config/site :title) |Calcium
                    , nil
                div
                  {}
                    :style $ {} (:cursor |pointer)
                    :on-click $ fn (e d!)
                      d! $ %:: app.schema/Op :router/change
                        %{} app.schema/Router $ :name :profile
                  <> $ if logged-in? |Me |Guest
                  =< 8 nil
                  <> count-members
          :examples $ []
          :schema $ :: 'Dynamic
        'css-navigation $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstyle css-navigation $ {}
              |$0 $ {} (:height 48) (:justify-content :space-between) (:padding "|0 16px") (:font-size 16)
                :border-bottom $ str "|1px solid " (hsl 0 0 0 0.1)
                :font-family ui/font-fancy
          :examples $ []
          :schema $ :: 'Dynamic
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.comp.navigation $ :require
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
          :code $ quote
            defcomp comp-profile (user members)
              div
                {} (:class-name css/flex)
                  :style $ {} (:padding 16)
                div
                  {} (:class-name css/font-fancy)
                    :style $ {} (:font-size 32) (:font-weight 100)
                  <> $ str "|Hello! " (:name user)
                =< nil 16
                div
                  {} $ :class-name css/row
                  <> |Members:
                  =< 8 nil
                  list->
                    {} $ :class-name css/row
                    -> members (.to-list)
                      map $ fn (pair)
                        let[] (k username) pair $ [] k
                          div
                            {} $ :class-name css-member-label
                            <> username
                =< nil 48
                div ({})
                  button
                    {} (:class-name css/button)
                      :on-click $ fn (e d!)
                        js/location.replace $ str js/location.origin |?time= (js/Date.now)
                        , &unit
                    <> |Refresh
                  =< 8 nil
                  button
                    {} (:class-name css/button)
                      :style $ {} (:color :red) (:border-color :red)
                      :on-click $ fn (e dispatch!)
                        dispatch! $ %:: app.schema/Op :user/log-out
                        js/localStorage.removeItem $ option:unwrap (get config/site :storage-key)
                        , &unit
                    <> "|Log out"
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'respo.schema/Component)
              :args $ [] 'app.schema/UserView 'Map
        'css-member-label $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstyle css-member-label $ {}
              |$0 $ {} (:padding "|0 8px")
                :border $ str "|1px solid " (hsl 0 0 80)
                :border-radius |16px
                :margin "|0 4px"
          :examples $ []
          :schema $ :: 'Dynamic
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.comp.profile $ :require
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
          :code $ quote
            def dev? $ = |dev
              option:unwrap-or (get-env |mode) |release
          :examples $ []
          :schema $ :: 'Dynamic
        'site $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def site $ {} (:port 5021) (:title |Calcium) (:icon |https://cdn.tiye.me/logo/cumulo.png) (:theme |#eeeeff) (:storage-key |calcium-storage) (:storage-file |storage.cirru)
          :examples $ []
          :schema $ :: 'Dynamic
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote (ns app.config)
    'app.schema $ %{} 'FileEntry
      :defs $ {}
        'AttachedView $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct AttachedView (:type 'Tag) (:content 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'ClientMessage $ %{} 'CodeEntry (:doc "|Typed messages accepted from a browser connection.")
          :code $ quote
            defenum ClientMessage (:sync/active 'Number) (:sync/heartbeat 'Number) (:sync/idle 'Number) (:sync/resume 'Number) (:sync/ack 'Number) (:dispatch 'app.schema/Op)
          :examples $ []
          :schema $ :: 'EnumDef
        'DatabaseDecodeError $ %{} 'CodeEntry (:doc "|A path-aware failure produced while decoding untrusted or legacy persisted database data.")
          :code $ quote
            defenum DatabaseDecodeError $ :invalid 'String 'String
          :examples $ []
          :schema $ :: 'EnumDef
        'Db $ %{} 'CodeEntry (:doc "|The nominal application database used by reducers and projections.")
          :code $ quote
            defstruct Db
              :sessions $ :: 'Map 'Number 'app.schema/Session
              :users $ :: 'Map 'String 'app.schema/User
          :examples $ []
          :schema $ :: 'StructDef
        'DomainOp $ %{} 'CodeEntry (:doc "|Pure business operations accepted by the database reducer; local and server effects stay outside this enum.")
          :code $ quote
            defenum DomainOp (:session/connect) (:session/disconnect) (:session/remove-message 'app.schema/RemoveMessage) (:user/log-in 'String 'String) (:user/sign-up 'String 'String) (:user/log-out) (:router/change 'app.schema/Router)
          :examples $ []
          :schema $ :: 'EnumDef
        'Message $ %{} 'CodeEntry (:doc "|A persisted session message.")
          :code $ quote
            defstruct Message (:id 'String) (:text 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'MessageDecodeError $ %{} 'CodeEntry (:doc "|Why an untrusted WebSocket value could not become a typed message envelope.")
          :code $ quote
            defenum MessageDecodeError $ :invalid 'String
          :examples $ []
          :schema $ :: 'EnumDef
        'MessageView $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct MessageView (:id 'String) (:text 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'Op $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defenum Op (:session/connect) (:session/disconnect) (:session/remove-message 'app.schema/RemoveMessage) (:user/log-in 'String 'String) (:user/sign-up 'String 'String) (:user/log-out) (:router/change 'app.schema/Router) (:effect/persist) (:effect/ping) (:effect/pong) (:effect/connect) (:reel/reset) (:reel/merge) (:states 'Dynamic 'Dynamic)
          :examples $ []
          :schema $ :: 'EnumDef
        'RemoveMessage $ %{} 'CodeEntry (:doc "|Concrete payload for removing one session message.")
          :code $ quote
            defstruct RemoveMessage $ :id 'String
          :examples $ []
          :schema $ :: 'StructDef
        'Router $ %{} 'CodeEntry (:doc "|The domain route stored for one session. Route-specific view data is projected separately.")
          :code $ quote
            defstruct Router $ :name 'Tag
          :examples $ []
          :schema $ :: 'StructDef
        'RouterView $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct RouterView (:name 'Tag)
              :data $ :: 'Option 'Map
              :router $ :: 'Option 'Map
          :examples $ []
          :schema $ :: 'StructDef
        'ServerMessage $ %{} 'CodeEntry (:doc "|Typed synchronization and effect messages sent to a browser.")
          :code $ quote
            defenum ServerMessage (:snapshot 'Number 'app.schema/Store)
              :patch 'Number 'Number $ :: 'List 'recollect.schema/change-op
              :effect/pong
          :examples $ []
          :schema $ :: 'EnumDef
        'Session $ %{} 'CodeEntry (:doc "|A connected session in the nominal database.")
          :code $ quote
            defstruct Session
              :user-id $ :: 'Option 'String
              :id 'Number
              :nickname $ :: 'Option 'String
              :router $ quote app.schema/Router
              :messages $ :: 'Map 'String 'app.schema/Message
          :examples $ []
          :schema $ :: 'StructDef
        'SessionView $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct SessionView
              :user-id $ :: 'Option 'String
              :id $ :: 'Option 'Number
              :nickname $ :: 'Option 'String
              :router $ quote app.schema/RouterView
              :messages $ :: 'Map 'String (quote app.schema/MessageView)
          :examples $ []
          :schema $ :: 'StructDef
        'SharedTwig $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct SharedTwig (:reel-length 'Number)
              :attached $ quote app.schema/AttachedView
              :pages $ :: 'Option 'Map
              :members $ :: 'Map 'Number (:: 'Option 'String)
              :session-count 'Number
          :examples $ []
          :schema $ :: 'StructDef
        'Store $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct Store (:logged-in? 'Bool)
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
          :code $ quote
            defstruct User (:name 'String) (:id 'String)
              :nickname $ :: 'Option 'String
              :avatar $ :: 'Option 'String
              :password 'String
          :examples $ []
          :schema $ :: 'StructDef
        'UserView $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct UserView (:name 'String) (:id 'String)
              :nickname $ :: 'Option 'String
              :avatar $ :: 'Option 'String
          :examples $ []
          :schema $ :: 'StructDef
        'database $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def database $ %{} Db
              :sessions $ {}
              :users $ {}
          :examples $ []
          :schema $ :: 'app.schema/Db
        'decode-client-message $ %{} 'CodeEntry (:doc "|Validate one untrusted client value and reconstruct a nominal ClientMessage; direct legacy Op enums remain accepted.")
          :code $ quote
            defn decode-client-message (data)
              let
                  message $ if (enum? data)
                    assoc data 0 $ turn-tag
                      option:unwrap $ nth data 0
                    , data
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
                  _ $ match (decode-operation message)
                    (:ok typed-op)
                      %:: Result :ok $ %:: ClientMessage :dispatch typed-op
                    (:err error) (%:: Result :err error)
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'Dynamic
              :return $ :: 'Result 'app.schema/ClientMessage 'app.schema/MessageDecodeError
          :tests $ []
            %{} 'TestEntry (:name |decodes-sync-control)
              :code $ quote
                assert=
                  %:: Result :ok $ %:: ClientMessage :sync/ack 7
                  decode-client-message $ :: :sync/ack 7
              :tags $ #{} :server
            %{} 'TestEntry (:name |accepts-legacy-direct-op)
              :code $ quote
                assert=
                  %:: Result :ok $ %:: ClientMessage :dispatch (%:: Op :effect/ping)
                  decode-client-message $ %:: Op :effect/ping
              :tags $ #{} :server
            %{} 'TestEntry (:name |rejects-invalid-revision)
              :code $ quote
                match
                  decode-client-message $ :: :sync/active |bad
                  (:err error)
                    match error $
                      :invalid detail
                      starts-with? detail "|Expected numeric active revision"
                  _ false
              :tags $ #{} :server
            %{} 'TestEntry (:name |decodes-named-wire-operation)
              :code $ quote
                assert=
                  %:: Result :ok $ %:: ClientMessage :dispatch (%:: Op :effect/ping)
                  decode-client-message $ parse-cirru-edn "|%:: 'ClientMessage 'dispatch $ %:: 'Op 'effect/ping"
              :tags $ #{} :server
        'decode-database $ %{} 'CodeEntry (:doc "|Deeply validate a wire or legacy bare-map database and reconstruct nominal Db, Session, User, Router, and Message values.")
          :code $ quote
            defn decode-database (data)
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
                    match (decode-sessions sessions-data |db.sessions)
                      (:err error) (%err error)
                      (:ok sessions)
                        match (decode-users users-data |db.users)
                          (:err error) (%err error)
                          (:ok users)
                            %ok $ %{} Db (:sessions sessions) (:users users)
                  %err $ %:: DatabaseDecodeError :invalid |db "|Expected database map or struct"
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'T
              :generics $ [] 'T
              :return $ :: 'Result 'app.schema/Db 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
          :tests $ []
            %{} 'TestEntry (:name |decodes-legacy-bare-map)
              :code $ quote
                let
                    legacy $ {}
                      :sessions $ {}
                        1 $ {} (:id 1) (:user-id |u1) (:nickname nil)
                          :router $ {} (:name :profile)
                          :messages $ {}
                            |m1 $ {} (:id |m1) (:text |hello)
                      :users $ {}
                        |u1 $ {} (:id |u1) (:name |demo) (:nickname nil) (:avatar nil) (:password |hash)
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
              :code $ quote
                let
                    corrupt $ {}
                      :sessions $ {}
                        1 $ {} (:id 1)
                          :router $ {} (:name :home)
                          :messages $ {}
                            |m1 $ {} (:id |m1) (:text 42)
                      :users $ {}
                  assert=
                    %err $ %:: DatabaseDecodeError :invalid |db.sessions.1.messages.m1.text "|Expected String"
                    decode-database corrupt
              :tags $ #{} :schema :server
            %{} 'TestEntry (:name |rejects-corrupt-nested-user)
              :code $ quote
                let
                    corrupt $ {}
                      :sessions $ {}
                      :users $ {}
                        |u1 $ {} (:id |u1) (:name |demo) (:password 42)
                  assert=
                    %err $ %:: DatabaseDecodeError :invalid |db.users.u1.password "|Expected String"
                    decode-database corrupt
              :tags $ #{} :schema :server
        'decode-message $ %{} 'CodeEntry (:doc "|Decode and validate one stored message.")
          :code $ quote
            defn decode-message (data path)
              let
                  source $ if
                    = (type-of data) :struct
                    &struct:to-map data
                    , data
                if
                  = (type-of source) :map
                  match (get source :id)
                    (:none)
                      %err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected String"
                    (:some id)
                      if-not (string? id)
                        %err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected String"
                        match (get source :text)
                          (:none)
                            %err $ %:: DatabaseDecodeError :invalid (str path |.text) "|Expected String"
                          (:some text)
                            if (string? text)
                              %ok $ %{} Message (:id id) (:text text)
                              %err $ %:: DatabaseDecodeError :invalid (str path |.text) "|Expected String"
                  %err $ %:: DatabaseDecodeError :invalid path "|Expected Message map or struct"
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'T 'String
              :generics $ [] 'T
              :return $ :: 'Result 'app.schema/Message 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-messages $ %{} 'CodeEntry (:doc "|Decode a keyed message collection and validate every nested value.")
          :code $ quote
            defn decode-messages (data path)
              if-not
                = (type-of data) :map
                %err $ %:: DatabaseDecodeError :invalid path "|Expected message Map"
                foldl (&map:to-list data)
                  %ok $ {}
                  fn (acc pair)
                    match acc
                      (:err error) (%err error)
                      (:ok messages)
                        let[] (id value) pair $ if-not (string? id)
                          %err $ %:: DatabaseDecodeError :invalid path "|Expected String message key"
                          let
                              decoded $ decode-message value (str path |. id)
                            match decoded
                              (:err error) (%err error)
                              (:ok message)
                                if
                                  = id $ :id message
                                  %ok $ assoc messages id message
                                  %err $ %:: DatabaseDecodeError :invalid (str path |. id |.id) "|Message id must match map key"
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'T 'String
              :generics $ [] 'T
              :return $ :: 'Result (:: 'Map 'String 'app.schema/Message) 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
          :tests $ []
            %{} 'TestEntry (:name |rejects-mismatched-message-key)
              :code $ quote
                assert=
                  %err $ %:: DatabaseDecodeError :invalid |messages.m1.id "|Message id must match map key"
                  decode-messages
                    {} $ |m1
                      {} (:id |m2) (:text |hello)
                    , |messages
              :tags $ #{} :schema :server
        'decode-operation $ %{} 'CodeEntry (:doc "|Reconstruct a nominal application Op from an untrusted or legacy enum value.")
          :code $ quote
            defn decode-operation (data)
              let
                  op $ if (enum? data)
                    assoc data 0 $ turn-tag
                      option:unwrap $ nth data 0
                    , data
                match op
                  (:session/connect)
                    %ok $ %:: Op :session/connect
                  (:session/disconnect)
                    %ok $ %:: Op :session/disconnect
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
                              %ok $ %:: Op :session/remove-message
                                %{} RemoveMessage $ :id id
                              invalid-message $ str "|Invalid remove-message id: " id
                      invalid-message $ str "|Invalid remove-message payload: " message
                  (:user/log-in username password)
                    if
                      and (string? username) (string? password)
                      %ok $ %:: Op :user/log-in username password
                      invalid-message $ str "|Invalid log-in operation: " op
                  (:user/sign-up username password)
                    if
                      and (string? username) (string? password)
                      %ok $ %:: Op :user/sign-up username password
                      invalid-message $ str "|Invalid sign-up operation: " op
                  (:user/log-out)
                    %ok $ %:: Op :user/log-out
                  (:router/change router-data)
                    let
                        decoded-router $ decode-router router-data |operation.router
                      match decoded-router
                        (:ok typed-router)
                          %ok $ %:: Op :router/change typed-router
                        (:err error)
                          invalid-message $ str "|Invalid router operation: " error
                  (:effect/persist)
                    %ok $ %:: Op :effect/persist
                  (:effect/ping)
                    %ok $ %:: Op :effect/ping
                  (:effect/pong)
                    %ok $ %:: Op :effect/pong
                  (:effect/connect)
                    %ok $ %:: Op :effect/connect
                  (:reel/reset)
                    %ok $ %:: Op :reel/reset
                  (:reel/merge)
                    %ok $ %:: Op :reel/merge
                  (:states cursor state)
                    %ok $ %:: Op :states cursor state
                  _ $ invalid-message (str "|Unknown application operation: " op)
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'Dynamic
              :return $ :: 'Result 'app.schema/Op 'app.schema/MessageDecodeError
          :tests $ []
            %{} 'TestEntry (:name |decodes-concrete-domain-payloads)
              :code $ quote
                do
                  assert=
                    %ok $ %:: Op :router/change
                      %{} Router $ :name :profile
                    decode-operation $ :: :router/change
                      {} $ :name :profile
                  assert=
                    %ok $ %:: Op :session/remove-message
                      %{} RemoveMessage $ :id |m1
                    decode-operation $ :: :session/remove-message
                      {} $ :id |m1
                  match
                    decode-operation $ :: :router/change |profile
                    (:ok _) (raise |Expected-invalid-router-payload)
                    (:err _) &unit
                  match
                    decode-operation $ :: :session/remove-message
                      {} $ :id 1
                    (:ok _) (raise |Expected-invalid-remove-message-payload)
                    (:err _) &unit
              :tags $ #{} :protocol :schema
        'decode-optional-string $ %{} 'CodeEntry (:doc "|Normalize a persisted optional string from missing, nil, legacy String, or nominal Option data.")
          :code $ quote
            defn decode-optional-string (data path)
              hint-fn $ {}
                :generics $ [] 'T
                :args $ [] 'T 'String
                :return $ :: 'Result (:: 'Option 'String) 'app.schema/DatabaseDecodeError
              match data
                (:none)
                  %ok $ %none
                (:some value)
                  if (nil? value)
                    %ok $ %none
                    if (string? value)
                      %ok $ %some value
                      if
                        = (type-of value) :enum
                        match value
                          (:none)
                            %ok $ %none
                          (:some item)
                            if (string? item)
                              %ok $ %some item
                              %err $ %:: DatabaseDecodeError :invalid path "|Expected nil, String, or Option<String>"
                          _ $ %err (%:: DatabaseDecodeError :invalid path "|Expected nil, String, or Option<String>")
                        %err $ %:: DatabaseDecodeError :invalid path "|Expected nil, String, or Option<String>"
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'T 'String
              :generics $ [] 'T
              :return $ :: 'Result (:: 'Option 'String) 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-router $ %{} 'CodeEntry (:doc "|Decode and validate one stored route.")
          :code $ quote
            defn decode-router (data path)
              let
                  source $ if
                    = (type-of data) :struct
                    &struct:to-map data
                    , data
                if
                  = (type-of source) :map
                  match (get source :name)
                    (:none)
                      %err $ %:: DatabaseDecodeError :invalid (str path |.name) "|Expected Tag"
                    (:some name)
                      if (tag? name)
                        %ok $ %{} Router (:name name)
                        %err $ %:: DatabaseDecodeError :invalid (str path |.name) "|Expected Tag"
                  %err $ %:: DatabaseDecodeError :invalid path "|Expected Router map or struct"
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'T 'String
              :generics $ [] 'T
              :return $ :: 'Result 'app.schema/Router 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-server-message $ %{} 'CodeEntry (:doc "|Validate one untrusted server value and reconstruct a nominal ServerMessage.")
          :code $ quote
            defn decode-server-message (data)
              let
                  message $ if (enum? data)
                    assoc data 0 $ turn-tag
                      option:unwrap $ nth data 0
                    , data
                match message
                  (:snapshot revision store)
                    if
                      and (number? revision) (struct? store) (&struct:matches? store Store)
                      %:: Result :ok $ %:: ServerMessage :snapshot revision (unsafe-coerce store 'app.schema/Store)
                      invalid-message $ str "|Invalid snapshot envelope: " message
                  (:patch base-revision revision changes)
                    let
                        valid-changes? $ if (list? changes)
                          every? (unsafe-coerce changes 'List)
                            fn (change)
                              = (enum-definition change) (%some recollect.schema/change-op)
                          , false
                      if
                        and (number? base-revision) (number? revision) valid-changes?
                        %:: Result :ok $ %:: ServerMessage :patch base-revision revision
                          unsafe-coerce changes $ :: 'List 'recollect.schema/change-op
                        invalid-message $ str "|Invalid patch envelope: " message
                  (:effect/pong)
                    %:: Result :ok $ %:: ServerMessage :effect/pong
                  _ $ invalid-message (str "|Unknown server message: " message)
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'Dynamic
              :return $ :: 'Result 'app.schema/ServerMessage 'app.schema/MessageDecodeError
          :tests $ []
            %{} 'TestEntry (:name |decodes-pong)
              :code $ quote
                assert=
                  %:: Result :ok $ %:: ServerMessage :effect/pong
                  decode-server-message $ :: :effect/pong
              :tags $ #{} :client
            %{} 'TestEntry (:name |rejects-invalid-patch-payload)
              :code $ quote
                match
                  decode-server-message $ :: :patch 1 2 :bad
                  (:err error)
                    match error $
                      :invalid detail
                      starts-with? detail "|Invalid patch envelope"
                  _ false
              :tags $ #{} :client
            %{} 'TestEntry (:name |decodes-named-wire-pong)
              :code $ quote
                assert=
                  %:: Result :ok $ %:: ServerMessage :effect/pong
                  decode-server-message $ parse-cirru-edn "|%:: 'ServerMessage 'effect/pong"
              :tags $ #{} :client
            %{} 'TestEntry (:name |validates-nominal-patch-list)
              :code $ quote
                assert=
                  %:: Result :ok $ %:: ServerMessage :patch 3 4
                    [] $ %:: recollect.schema/change-op :replace 1
                  decode-server-message $ %:: ServerMessage :patch 3 4
                    [] $ %:: recollect.schema/change-op :replace 1
              :tags $ #{} :client
        'decode-session $ %{} 'CodeEntry (:doc "|Decode and deeply validate one stored session.")
          :code $ quote
            defn decode-session (data path)
              let
                  source $ if
                    = (type-of data) :struct
                    &struct:to-map data
                    , data
                if
                  = (type-of source) :map
                  match (get source :id)
                    (:none)
                      %err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected Number"
                    (:some id)
                      if-not (number? id)
                        %err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected Number"
                        let
                            user-id-result $ decode-optional-string (get source :user-id) (str path |.user-id)
                            nickname-result $ decode-optional-string (get source :nickname) (str path |.nickname)
                            router-data $ option:unwrap-or (get source :router)
                              {} $ :name :home
                            messages-data $ option:unwrap-or (get source :messages) ({})
                            router-result $ decode-router router-data (str path |.router)
                            messages-result $ decode-messages messages-data (str path |.messages)
                          match user-id-result
                            (:err error) (%err error)
                            (:ok user-id)
                              match nickname-result
                                (:err error) (%err error)
                                (:ok nickname)
                                  match router-result
                                    (:err error) (%err error)
                                    (:ok typed-router)
                                      match messages-result
                                        (:err error) (%err error)
                                        (:ok typed-messages)
                                          %ok $ %{} Session (:user-id user-id) (:id id) (:nickname nickname) (:router typed-router) (:messages typed-messages)
                  %err $ %:: DatabaseDecodeError :invalid path "|Expected Session map or struct"
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'T 'String
              :generics $ [] 'T
              :return $ :: 'Result 'app.schema/Session 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-sessions $ %{} 'CodeEntry (:doc "|Decode a keyed session collection and validate every nested value.")
          :code $ quote
            defn decode-sessions (data path)
              if-not
                = (type-of data) :map
                %err $ %:: DatabaseDecodeError :invalid path "|Expected session Map"
                foldl (&map:to-list data)
                  %ok $ {}
                  fn (acc pair)
                    match acc
                      (:err error) (%err error)
                      (:ok sessions)
                        let[] (id value) pair $ if-not (number? id)
                          %err $ %:: DatabaseDecodeError :invalid path "|Expected Number session key"
                          let
                              decoded $ decode-session value (str path |. id)
                            match decoded
                              (:err error) (%err error)
                              (:ok session)
                                if
                                  = id $ :id session
                                  %ok $ assoc sessions id session
                                  %err $ %:: DatabaseDecodeError :invalid (str path |. id |.id) "|Session id must match map key"
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'T 'String
              :generics $ [] 'T
              :return $ :: 'Result (:: 'Map 'Number 'app.schema/Session) 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-user $ %{} 'CodeEntry (:doc "|Decode and validate one stored user.")
          :code $ quote
            defn decode-user (data path)
              let
                  source $ if
                    = (type-of data) :struct
                    &struct:to-map data
                    , data
                if
                  = (type-of source) :map
                  match (get source :name)
                    (:none)
                      %err $ %:: DatabaseDecodeError :invalid (str path |.name) "|Expected String"
                    (:some name)
                      if-not (string? name)
                        %err $ %:: DatabaseDecodeError :invalid (str path |.name) "|Expected String"
                        match (get source :id)
                          (:none)
                            %err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected String"
                          (:some id)
                            if-not (string? id)
                              %err $ %:: DatabaseDecodeError :invalid (str path |.id) "|Expected String"
                              let
                                  nickname-result $ decode-optional-string (get source :nickname) (str path |.nickname)
                                  avatar-result $ decode-optional-string (get source :avatar) (str path |.avatar)
                                match nickname-result
                                  (:err error) (%err error)
                                  (:ok nickname)
                                    match avatar-result
                                      (:err error) (%err error)
                                      (:ok avatar)
                                        match (get source :password)
                                          (:none)
                                            %err $ %:: DatabaseDecodeError :invalid (str path |.password) "|Expected String"
                                          (:some password)
                                            if (string? password)
                                              %ok $ %{} User (:name name) (:id id) (:nickname nickname) (:avatar avatar) (:password password)
                                              %err $ %:: DatabaseDecodeError :invalid (str path |.password) "|Expected String"
                  %err $ %:: DatabaseDecodeError :invalid path "|Expected User map or struct"
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'T 'String
              :generics $ [] 'T
              :return $ :: 'Result 'app.schema/User 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'decode-users $ %{} 'CodeEntry (:doc "|Decode a keyed user collection and validate every nested value.")
          :code $ quote
            defn decode-users (data path)
              if-not
                = (type-of data) :map
                %err $ %:: DatabaseDecodeError :invalid path "|Expected user Map"
                foldl (&map:to-list data)
                  %ok $ {}
                  fn (acc pair)
                    match acc
                      (:err error) (%err error)
                      (:ok users)
                        let[] (id value) pair $ if-not (string? id)
                          %err $ %:: DatabaseDecodeError :invalid path "|Expected String user key"
                          let
                              decoded $ decode-user value (str path |. id)
                            match decoded
                              (:err error) (%err error)
                              (:ok user)
                                if
                                  = id $ :id user
                                  %ok $ assoc users id user
                                  %err $ %:: DatabaseDecodeError :invalid (str path |. id |.id) "|User id must match map key"
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'T 'String
              :generics $ [] 'T
              :return $ :: 'Result (:: 'Map 'String 'app.schema/User) 'app.schema/DatabaseDecodeError
          :tags $ #{} :scaffold
        'invalid-message $ %{} 'CodeEntry (:doc "|Build a typed decode failure while preserving the expected success type.")
          :code $ quote
            defn invalid-message (detail)
              %:: Result :err $ %:: MessageDecodeError :invalid detail
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'String
              :generics $ [] 'T
              :return $ :: 'Result 'T 'app.schema/MessageDecodeError
        'router $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def router $ %{} Router (:name :home)
          :examples $ []
          :schema $ :: 'app.schema/Router
        'session $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def session $ %{} Session
              :user-id $ %none
              :id 0
              :nickname $ %none
              :router router
              :messages $ {}
          :examples $ []
          :schema $ :: 'app.schema/Session
        'user $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def user $ %{} User (:name ||) (:id ||)
              :nickname $ %none
              :avatar $ %none
              :password ||
          :examples $ []
          :schema $ :: 'app.schema/User
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote (ns app.schema)
    'app.server $ %{} 'FileEntry
      :defs $ {}
        '*client-caches $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *client-caches $ {}
          :examples $ []
          :schema $ :: 'Ref (:: 'Map 'Number 'Dynamic)
        '*client-states $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *client-states $ {}
          :examples $ []
          :schema $ :: 'Ref (:: 'Map 'Number 'Dynamic)
        '*dirty-clients $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *dirty-clients $ #{}
          :examples $ []
          :schema $ :: 'Ref (:: 'Set 'Number)
        '*initial-db $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *initial-db $ if
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
        '*reader-reel $ %{} 'CodeEntry (:doc |)
          :code $ quote (defatom *reader-reel @*reel)
          :examples $ []
          :schema $ :: 'Dynamic
        '*reel $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *reel $ struct-with reel-schema (:base @*initial-db) (:db @*initial-db)
          :examples $ []
          :schema $ :: 'Ref 'cumulo-reel.core/ReelState
        '*shared-twig-cache $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *shared-twig-cache $ {} (:revision -1) (:value nil)
          :examples $ []
          :schema $ :: 'Dynamic
        '*sync-metrics $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *sync-metrics $ %{} SyncMetrics (:last-diff-latency-ms 0) (:last-patch-bytes 0) (:last-snapshot-bytes 0) (:last-visited-nodes 0) (:last-emitted-ops 0) (:budget-fallback-count 0) (:pending-clients 0) (:slow-clients 0) (:resync-count 0) (:patch-attempts 0) (:snapshot-attempts 0) (:last-revision 0)
          :examples $ []
          :schema $ :: 'Dynamic
        '*sync-retry-scheduled? $ %{} 'CodeEntry (:doc "|Whether a slower backpressure retry callback is pending.")
          :code $ quote (defatom *sync-retry-scheduled? false)
          :examples $ []
          :schema $ :: 'Ref 'Bool
        '*sync-revision $ %{} 'CodeEntry (:doc |)
          :code $ quote (defatom *sync-revision 0)
          :examples $ []
          :schema $ :: 'Ref 'Number
        '*sync-scheduled? $ %{} 'CodeEntry (:doc "|Whether a fast coalesced server sync callback is pending.")
          :code $ quote (defatom *sync-scheduled? false)
          :examples $ []
          :schema $ :: 'Ref 'Bool
        'SyncDiffPlan $ %{} 'CodeEntry (:doc "|Atomic server decision. Snapshot variants carry statistics and an optional budget reason but never partial changes.")
          :code $ quote
            defenum SyncDiffPlan
              :snapshot 'recollect.diff/DiffStats $ :: 'Option 'recollect.diff/DiffBudgetReason
              :patch (:: 'List 'recollect.schema/change-op) 'recollect.diff/DiffStats
              :idle 'recollect.diff/DiffStats
          :examples $ []
          :schema $ :: 'EnumDef
        'SyncMetrics $ %{} 'CodeEntry (:doc "|Application-level synchronization latency, wire-byte, deterministic diff-work, budget-fallback, revision, resync, pending-client, and slow-client metrics; pending and slow fields are gauges refreshed on read.")
          :code $ quote
            defstruct SyncMetrics (:last-diff-latency-ms 'Number) (:last-patch-bytes 'Number) (:last-snapshot-bytes 'Number) (:last-visited-nodes 'Number) (:last-emitted-ops 'Number) (:budget-fallback-count 'Number) (:pending-clients 'Number) (:slow-clients 'Number) (:resync-count 'Number) (:patch-attempts 'Number) (:snapshot-attempts 'Number) (:last-revision 'Number)
          :examples $ []
          :schema $ :: 'Enum
        'acknowledge-client! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn acknowledge-client! (sid revision)
              let
                  state $ option:unwrap (get @*client-states sid)
                when
                  = revision $ option:unwrap-or (get state :sent-rev) -1
                  let
                      sent-store $ option:unwrap (get state :sent-store)
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
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Number 'Number
        'dispatch! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn dispatch! (op sid)
              let
                  op-id $ generate-id!
                  op-time $ now-ms
                if config/dev? $ println |Dispatch! (str op) sid
                match op
                  (:effect/persist) (persist-db!)
                  (:effect/ping)
                    wss-send! sid $ format-cirru-edn (%:: schema/ServerMessage :effect/pong)
                  (:reel/reset)
                    do
                      reset! *reel $ -> @*reel
                        assoc :db $ :base @*reel
                        assoc :records $ []
                      request-sync!
                  (:reel/merge)
                    do
                      reset! *reel $ -> @*reel
                        assoc :base $ :db @*reel
                        assoc :records $ []
                        assoc :merged? true
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
                  _ $ do (eprintln "|Ignoring client-local operation on server:" op) &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Dynamic)
              :args $ [] 'app.schema/Op 'Number
        'dispatch-domain! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn dispatch-domain! (op sid op-id op-time)
              do
                reset! *reel $ reel-reducer @*reel updater op sid op-id op-time config/dev?
                request-sync!
                , &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'app.schema/DomainOp 'Number 'String 'Number
        'empty-diff-stats $ %{} 'CodeEntry (:doc "|Zero work statistics used when an existing recovery state already requires a snapshot and no diff runs.")
          :code $ quote
            def empty-diff-stats $ %{} DiffStats (:visited-nodes 0) (:emitted-ops 0)
          :examples $ []
          :schema $ :: 'recollect.diff/DiffStats
        'get-backup-path! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn get-backup-path! () $ join-path calcit-dirname |backups
              str (unix-time-ms) |-snapshot.cirru
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'String)
              :args $ []
        'get-shared-twig $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn get-shared-twig (reel revision)
              let
                  cached @*shared-twig-cache
                if
                  = revision $ option:unwrap (get cached :revision)
                  option:unwrap $ get cached :value
                  let
                      value $ twig-shared (reel-db reel) (reel-record-count reel)
                    reset! *shared-twig-cache $ {} (:revision revision) (:value value)
                    , value
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/SharedTwig)
              :args $ [] 'cumulo-reel.core/ReelState 'Number
        'handle-client-message! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn handle-client-message! (message sid)
              match message
                (:sync/active client-revision) (mark-client-active! sid client-revision false)
                (:sync/heartbeat client-revision)
                  do (touch-client! sid client-revision)
                    wss-send! sid $ format-cirru-edn (%:: schema/ServerMessage :effect/pong)
                    , &unit
                (:sync/idle client-revision) (mark-client-idle! sid client-revision)
                (:sync/resume client-revision)
                  do (record-resync!) (mark-client-active! sid client-revision true)
                (:sync/ack revision) (acknowledge-client! sid revision)
                (:dispatch op) (dispatch! op sid)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'app.schema/ClientMessage 'Number
        'handle-sync-send! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn handle-sync-send! (sid revision new-store outcome)
              swap! *client-states update sid $ fn (current) (next-sync-send-state current revision new-store outcome)
              match outcome
                (:accepted) &unit
                (:backpressured)
                  do (swap! *dirty-clients include sid) (request-sync-retry!)
                (:too-large) (println "|WebSocket sync payload is too large for client:" sid)
                (:closed) &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Number 'Number 'app.schema/Store 'wss.core/WssSendOutcome
        'heartbeat-timeout $ %{} 'CodeEntry (:doc |)
          :code $ quote (def heartbeat-timeout 12000)
          :examples $ []
          :schema $ :: 'Dynamic
        'invalidate-sync-caches! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn invalidate-sync-caches! ()
              reset! *shared-twig-cache $ {} (:revision -1) (:value nil)
              reset! *client-caches $ {}
              each (keys @*client-states)
                fn (sid)
                  swap! *client-states update sid $ fn (state)
                    dissoc
                      merge state $ {} (:needs-snapshot? true) (:in-flight? false)
                      , :sent-rev :sent-store
                  when
                    = :active $ option:unwrap
                      get
                        option:unwrap $ get @*client-states sid
                        , :status
                    swap! *dirty-clients include sid
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'main! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn main! () $ do
              println "|Running mode:" $ if config/dev? |dev |release
              let
                  port $ resolve-port
                do (run-server! port)
                  println $ str "|Server started on port:" port
              do (; "|Initialize lazy definitions before starting background callbacks.") (identity @*reader-reel)
              set-interval 5000 $ fn () (sweep-idle-clients!)
              set-interval 600000 $ fn () (persist-db!)
              on-control-c on-exit!
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'mark-client-active! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn mark-client-active! (sid client-revision force-snapshot?)
              let
                  state $ option:unwrap-or (get @*client-states sid) ({})
                  resumed? $ or force-snapshot?
                    not= :active $ option:unwrap-or (get state :status) :idle
                  next-state-base $ merge
                    {} (:status :active)
                      :last-heartbeat $ now-ms
                      :acked-rev client-revision
                      :dirty-rev @*sync-revision
                      :in-flight? false
                      :needs-snapshot? true
                    , state
                      {} (:status :active)
                        :last-heartbeat $ now-ms
                        :acked-rev $ if resumed? client-revision
                          option:unwrap-or (get state :acked-rev) client-revision
                        :in-flight? $ if resumed? false
                          option:unwrap-or (get state :in-flight?) false
                        :needs-snapshot? $ or resumed?
                          option:unwrap-or (get state :needs-snapshot?) false
                  next-state $ if resumed? (dissoc next-state-base :sent-rev :sent-store) next-state-base
                swap! *client-states assoc sid next-state
                when resumed? (swap! *client-caches remove-client-cache sid) (swap! *dirty-clients include sid) (request-sync!)
              , &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Number 'Number 'Bool
        'mark-client-idle! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn mark-client-idle! (sid client-revision)
              when
                option:some? $ get @*client-states sid
                swap! *client-states update sid $ fn (state)
                  dissoc
                    merge state $ {} (:status :idle) (:acked-rev client-revision) (:in-flight? false) (:needs-snapshot? true)
                    , :sent-rev :sent-store
                swap! *client-caches remove-client-cache sid
                swap! *dirty-clients remove-dirty-client sid
          :examples $ []
          :schema $ :: 'Dynamic
        'mark-clients-dirty! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn mark-clients-dirty! (revision)
              each (keys @*client-states)
                fn (sid)
                  let
                      state $ option:unwrap (get @*client-states sid)
                    swap! *client-states assoc-in ([] sid :dirty-rev) revision
                    when
                      = :active $ option:unwrap (get state :status)
                      swap! *dirty-clients include sid
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Number
        'next-sync-ack-state $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn next-sync-ack-state (current revision)
              dissoc
                merge current $ {} (:acked-rev revision) (:in-flight? false)
                , :sent-rev :sent-store
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'C)
              :args $ [] 'C 'Number
              :generics $ [] 'C
          :tests $ []
            %{} 'TestEntry (:name |repeated-backpressure-converges-to-latest-revision)
              :code $ quote
                let
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
        'next-sync-metrics $ %{} 'CodeEntry (:doc "|Purely advance synchronization counters for one attempted snapshot or patch send.")
          :code $ quote
            defn next-sync-metrics (metrics message-kind revision diff-latency payload stats budget-fallback?)
              struct-with metrics (:last-diff-latency-ms diff-latency)
                :last-patch-bytes $ if (= message-kind :patch) payload.utf8-byte-count (:last-patch-bytes metrics)
                :last-snapshot-bytes $ if (= message-kind :snapshot) payload.utf8-byte-count (:last-snapshot-bytes metrics)
                :last-visited-nodes $ :visited-nodes stats
                :last-emitted-ops $ :emitted-ops stats
                :budget-fallback-count $ if budget-fallback?
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
          :schema $ :: 'Fn
            {} (:return 'app.server/SyncMetrics)
              :args $ [] 'app.server/SyncMetrics 'Tag 'Number 'Number 'String 'recollect.diff/DiffStats 'Bool
          :tests $ []
            %{} 'TestEntry (:name |advances-patch-and-snapshot-counters)
              :code $ quote
                let
                    initial $ %{} SyncMetrics (:last-diff-latency-ms 0) (:last-patch-bytes 0) (:last-snapshot-bytes 0) (:last-visited-nodes 0) (:last-emitted-ops 0) (:budget-fallback-count 0) (:pending-clients 0) (:slow-clients 0) (:resync-count 0) (:patch-attempts 0) (:snapshot-attempts 0) (:last-revision 0)
                    patch-stats $ %{} DiffStats (:visited-nodes 7) (:emitted-ops 3)
                    snapshot-stats $ %{} DiffStats (:visited-nodes 9) (:emitted-ops 4)
                    after-patch $ next-sync-metrics initial :patch 7 3 "|A😀" patch-stats false
                  assert=
                    %{} SyncMetrics (:last-diff-latency-ms 2) (:last-patch-bytes 5) (:last-snapshot-bytes 7) (:last-visited-nodes 9) (:last-emitted-ops 4) (:budget-fallback-count 1) (:pending-clients 0) (:slow-clients 0) (:resync-count 0) (:patch-attempts 1) (:snapshot-attempts 1) (:last-revision 8)
                    next-sync-metrics after-patch :snapshot 8 2 |ignored snapshot-stats true
              :tags $ #{} :server
        'next-sync-send-state $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn next-sync-send-state (current revision new-store outcome)
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
          :schema $ :: 'Fn
            {} (:return 'C)
              :args $ [] 'C 'Number 'U 'wss.core/WssSendOutcome
              :generics $ [] 'C 'U
          :tests $ []
            %{} 'TestEntry (:name |accepted-records-pending-store)
              :code $ quote
                assert=
                  {} (:status :active) (:sent-rev 7)
                    :sent-store $ {} (:value 1)
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
              :code $ quote
                assert=
                  {} (:status :active) (:needs-snapshot? true) (:slow-client? true) (:last-send-outcome :too-large)
                  next-sync-send-state
                    {} $ :status :active
                    , 7
                      {} $ :value 1
                      %:: wss.core/WssSendOutcome :too-large
              :tags $ #{} :server
            %{} 'TestEntry (:name |closed-clears-pending-send)
              :code $ quote
                assert=
                  {} (:status :idle) (:in-flight? false) (:last-send-outcome :closed)
                  next-sync-send-state
                    {} (:status :active) (:in-flight? true) (:sent-rev 7)
                      :sent-store $ {} (:value 1)
                    , 7
                      {} $ :value 1
                      %:: wss.core/WssSendOutcome :closed
              :tags $ #{} :server
            %{} 'TestEntry (:name |backpressure-preserves-latest-dirty-revision)
              :code $ quote
                assert=
                  {} (:status :active) (:acked-rev 5) (:dirty-rev 7) (:slow-client? true) (:last-send-outcome :backpressured)
                  next-sync-send-state
                    {} (:status :active) (:acked-rev 5) (:dirty-rev 6)
                    , 7
                      {} $ :value 1
                      %:: wss.core/WssSendOutcome :backpressured
              :tags $ #{} :server
        'now-ms $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn now-ms () $ unix-time-ms
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Number)
              :args $ []
        'on-exit! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn on-exit! () (persist-db!) (; println "|exit code is...") (quit! 0)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Dynamic)
              :args $ []
        'patch-operation-limit $ %{} 'CodeEntry (:doc |)
          :code $ quote (def patch-operation-limit 64)
          :examples $ []
          :schema $ :: 'Dynamic
        'persist-db! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn persist-db! () $ let
                file-content $ format-cirru-edn
                  assoc (reel-db @*reel) :sessions $ {}
                storage-path storage-file
                backup-path $ get-backup-path!
              do (check-write-file! storage-path file-content) (check-write-file! backup-path file-content)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'read-persisted-database $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn read-persisted-database (content)
              try
                schema/decode-database $ parse-cirru-edn content
                fn (error)
                  %err $ %:: schema/DatabaseDecodeError :invalid |db (str "|Malformed persisted Cirru EDN: " error)
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] 'String
              :return $ :: 'Result 'app.schema/Db 'app.schema/DatabaseDecodeError
          :tests $ []
            %{} 'TestEntry (:name |rejects-malformed-cirru-edn)
              :code $ quote
                match (read-persisted-database "|{} (:sessions")
                  (:ok _) (raise |Expected-malformed-storage-error)
                  (:err _) &unit
              :tags $ #{} :schema :server
        'read-sync-metrics $ %{} 'CodeEntry (:doc "|Read counters plus pending and slow-client gauges computed from current connection state.")
          :code $ quote
            defn read-sync-metrics () $ let
                states $ vals @*client-states
                pending-clients $ count
                  filter states $ fn (state)
                    option:unwrap-or (get state :in-flight?) false
                slow-clients $ count
                  filter states $ fn (state)
                    option:unwrap-or (get state :slow-client?) false
              merge @*sync-metrics $ {} (:pending-clients pending-clients) (:slow-clients slow-clients)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.server/SyncMetrics)
              :args $ []
        'record-resync! $ %{} 'CodeEntry (:doc "|Count one explicit client request for a full synchronization snapshot.")
          :code $ quote
            defn record-resync! () $ swap! *sync-metrics update :resync-count inc
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'record-sync-send! $ %{} 'CodeEntry (:doc "|Record metrics for one synchronization send attempt before transport admission.")
          :code $ quote
            defn record-sync-send! (message-kind revision diff-latency payload stats budget-fallback?)
              swap! *sync-metrics $ fn (metrics) (next-sync-metrics metrics message-kind revision diff-latency payload stats budget-fallback?)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Tag 'Number 'Number 'String 'recollect.diff/DiffStats 'Bool
        'reel-db $ %{} 'CodeEntry (:doc "|Named adapter for the legacy generic ReelState database slot.")
          :code $ quote
            defn reel-db (reel)
              assert-type (:db reel) app.schema/Db
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/Db)
              :args $ [] 'cumulo-reel.core/ReelState
          :tests $ []
            %{} 'TestEntry (:name |decodes-generic-reel-slot)
              :code $ quote
                let
                    reel $ struct-with reel-schema (:db schema/database) (:base schema/database)
                      :records $ []
                      :merged? false
                  assert= schema/database $ reel-db reel
                  assert= 0 $ reel-record-count reel
              :tags $ #{} :server :type
        'reel-record-count $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn reel-record-count (reel)
              count $ :records reel
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Number)
              :args $ [] 'cumulo-reel.core/ReelState
        'reload! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn reload! () (println "|Code updated..")
              if (not config/dev?) (raise "|reloading only happens in dev mode")
              clear-twig-caches!
              invalidate-sync-caches!
              reset! *reel $ refresh-reel @*reel @*initial-db updater
              render-loop!
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'remove-client-cache $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn remove-client-cache (caches sid) (dissoc caches sid)
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] (:: 'Map 'Number 'T) 'Number
              :generics $ [] 'T
              :return $ :: 'Map 'Number 'T
        'remove-dirty-client $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn remove-dirty-client (clients sid) (exclude clients sid)
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] (:: 'Set 'Number) 'Number
              :return $ :: 'Set 'Number
        'render-loop! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn render-loop! ()
              when
                not $ identical? @*reader-reel @*reel
                reset! *reader-reel @*reel
                swap! *sync-revision inc
                mark-clients-dirty! @*sync-revision
              sync-clients! @*reader-reel
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'request-sync! $ %{} 'CodeEntry (:doc "|Request one bounded, coalesced server sync callback.")
          :code $ quote
            defn request-sync! () $ if @*sync-scheduled? &unit
              do (reset! *sync-scheduled? true)
                set-timeout sync-coalesce-delay $ fn () (reset! *sync-scheduled? false) (render-loop!)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'request-sync-retry! $ %{} 'CodeEntry (:doc "|Request one slower retry without blocking new fast sync requests.")
          :code $ quote
            defn request-sync-retry! () $ if @*sync-retry-scheduled? &unit
              do (reset! *sync-retry-scheduled? true)
                set-timeout sync-retry-delay $ fn () (reset! *sync-retry-scheduled? false)
                  when
                    not $ empty? @*dirty-clients
                    request-sync!
                  , &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'resolve-port $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn resolve-port ()
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
          :schema $ :: 'Fn
            {} (:return 'Number)
              :args $ []
        'run-server! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn run-server! (port)
              wss-serve!
                {} $ :port port
                fn (data)
                  hint-fn $ {}
                    :args $ [] 'Dynamic
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
                    _ $ println "|unknown data:" data
              , &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Number
        'select-sync-diff $ %{} 'CodeEntry (:doc "|Convert one atomic Recollect outcome into patch, snapshot, or idle policy while retaining the existing top-level patch-operation limit.")
          :code $ quote
            defn select-sync-diff (outcome)
              match outcome
                (:budget-exceeded reason stats)
                  %:: SyncDiffPlan :snapshot stats $ %some reason
                (:complete changes stats)
                  cond
                      empty? changes
                      %:: SyncDiffPlan :idle stats
                    (> (count changes) patch-operation-limit)
                      %:: SyncDiffPlan :snapshot stats $ %none
                    true $ %:: SyncDiffPlan :patch changes stats
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.server/SyncDiffPlan)
              :args $ [] 'recollect.diff/DiffOutcome
          :tests $ []
            %{} 'TestEntry (:name |budget-exceeded-discards-partial-path)
              :code $ quote
                let
                    stats $ %{} DiffStats (:visited-nodes 3) (:emitted-ops 1)
                    reason $ %:: recollect.diff/DiffBudgetReason :visited-nodes
                    outcome $ %:: recollect.diff/DiffOutcome :budget-exceeded reason stats
                  assert=
                    %:: SyncDiffPlan :snapshot stats $ %some reason
                    select-sync-diff outcome
              :tags $ #{} :server
            %{} 'TestEntry (:name |complete-selects-idle-patch-and-operation-fallback)
              :code $ quote
                let
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
                      %:: SyncDiffPlan :snapshot stats $ %none
                      select-sync-diff large-outcome
              :tags $ #{} :server
            %{} 'TestEntry (:name |real-budget-overflow-is-atomic)
              :code $ quote
                let
                    budget $ %{} DiffBudget
                      :max-visited $ %some 3
                      :max-emitted $ %none
                    outcome $ diff-twig-budgeted ([] 1 2 3) ([] 1 2 4) ({}) budget
                    plan $ select-sync-diff outcome
                  match plan
                    (:snapshot stats reason)
                      do
                        assert= 3 $ :visited-nodes stats
                        assert=
                          %some $ %:: recollect.diff/DiffBudgetReason :visited-nodes
                          , reason
                    _ $ assert |overflow-must-select-snapshot false
              :tags $ #{} :server
        'site-port $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn site-port () $ assert-type (&map:get config/site :port) Number
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Number)
              :args $ []
        'site-storage-file $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn site-storage-file () $ assert-type (&map:get config/site :storage-file) String
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'String)
              :args $ []
        'storage-file $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def storage-file $ if (empty? calcit-dirname)
              str calcit-dirname $ site-storage-file
              str calcit-dirname |/ $ site-storage-file
          :examples $ []
          :schema $ :: 'String
        'sweep-idle-clients! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn sweep-idle-clients! () $ let
                current-time $ now-ms
              each (keys @*client-states)
                fn (sid)
                  let
                      state $ option:unwrap (get @*client-states sid)
                      last-heartbeat $ option:unwrap-or (get state :last-heartbeat) 0
                    when
                      and
                        = :active $ option:unwrap (get state :status)
                        > (- current-time last-heartbeat) heartbeat-timeout
                      mark-client-idle! sid $ option:unwrap-or (get state :acked-rev) 0
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'sync-client! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn sync-client! (sid reel revision) (swap! *dirty-clients remove-dirty-client sid)
              let
                  state $ option:unwrap (get @*client-states sid)
                when
                  and
                    = :active $ option:unwrap (get state :status)
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
                            %:: SyncDiffPlan :snapshot empty-diff-stats $ %none
                            select-sync-diff $ diff-twig-budgeted (option:unwrap old-store-option) new-store
                              {} $ :key :id
                              , sync-diff-budget
                          diff-latency $ - (now-ms) diff-start
                          base-revision $ option:unwrap-or (get state :acked-rev) 0
                        match diff-plan
                          (:snapshot stats budget-reason)
                            let
                                payload $ format-cirru-edn (%:: schema/ServerMessage :snapshot revision new-store)
                              record-sync-send! :snapshot revision diff-latency payload stats $ option:some? budget-reason
                              handle-sync-send! sid revision new-store $ wss-send! sid payload
                          (:patch changes stats)
                            let
                                payload $ format-cirru-edn (%:: schema/ServerMessage :patch base-revision revision changes)
                              record-sync-send! :patch revision diff-latency payload stats false
                              handle-sync-send! sid revision new-store $ wss-send! sid payload
                          (:idle _stats) &unit
                      do (eprintln |Missing-typed-session-during-sync: sid) &unit
              , &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Number 'cumulo-reel.core/ReelState 'Number
        'sync-clients! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn sync-clients! (reel)
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
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'cumulo-reel.core/ReelState
        'sync-coalesce-delay $ %{} 'CodeEntry (:doc "|Maximum coalescing delay in milliseconds for ordinary state updates.")
          :code $ quote (def sync-coalesce-delay 16)
          :examples $ []
          :schema $ :: 'Number
        'sync-diff-budget $ %{} 'CodeEntry (:doc "|Deterministic per-client diff budget; snapshot size and transport admission remain independent limits.")
          :code $ quote
            def sync-diff-budget $ %{} DiffBudget
              :max-visited $ %some sync-diff-visited-limit
              :max-emitted $ %some sync-diff-emitted-limit
          :examples $ []
          :schema $ :: 'recollect.diff/DiffBudget
        'sync-diff-emitted-limit $ %{} 'CodeEntry (:doc "|Operation-construction ceiling selected above the measured 10k workload maximum of 70001.")
          :code $ quote (def sync-diff-emitted-limit 80000)
          :examples $ []
          :schema $ :: 'Number
        'sync-diff-visited-limit $ %{} 'CodeEntry (:doc "|Visited-node ceiling selected above the measured 10k workload maximum of 40002.")
          :code $ quote (def sync-diff-visited-limit 50000)
          :examples $ []
          :schema $ :: 'Number
        'sync-retry-delay $ %{} 'CodeEntry (:doc "|Retry delay in milliseconds after WebSocket backpressure.")
          :code $ quote (def sync-retry-delay 200)
          :examples $ []
          :schema $ :: 'Number
        'touch-client! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn touch-client! (sid client-revision)
              let
                  state $ option:unwrap (get @*client-states sid)
                if
                  = :active $ option:unwrap (get state :status)
                  swap! *client-states assoc-in ([] sid :last-heartbeat) (now-ms)
                  mark-client-active! sid client-revision true
          :examples $ []
          :schema $ :: 'Dynamic
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.server $ :require (app.schema :as schema)
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
    'app.twig.container $ %{} 'FileEntry
      :defs $ {}
        'twig-container $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn twig-container (db session-data shared)
              let
                  user-id-option $ :user-id session-data
                  logged-in? $ option:some? user-id-option
                  router-data $ :router session-data
                  router-name $ :name router-data
                  router-view-data $ if logged-in?
                    case-default router-name (%none)
                      :home $ :pages shared
                      :profile $ %some (:members shared)
                    %none
                  router-view $ %{} RouterView (:name router-name) (:data router-view-data)
                    :router $ %none
                  messages-view $ -> (:messages session-data) (.to-list)
                    map $ fn (pair)
                      let[] (id raw-message) pair $ let
                          message $ assert-type raw-message app.schema/Message
                        [] id $ %{} MessageView
                          :id $ :id message
                          :text $ :text message
                    pairs-map
                  session-view $ %{} SessionView (:user-id user-id-option)
                    :id $ %some (:id session-data)
                    :nickname $ :nickname session-data
                    :router $ %{} RouterView (:name router-name)
                      :data $ %none
                      :router $ %none
                    :messages messages-view
                  user-option $ match user-id-option
                    (:none) (%none)
                    (:some user-id)
                      if-let
                        raw-user $ get (:users db) user-id
                        let
                            user-data $ assert-type raw-user app.schema/User
                          %some $ twig-user user-data
                        %none
                %{} Store (:logged-in? logged-in?) (:session session-view)
                  :reel-length $ :reel-length shared
                  :attached $ :attached shared
                  :user user-option
                  :router router-view
                  :count $ if logged-in? (:session-count shared) 0
                  :color $ if logged-in? |#aaa |transparent
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/Store)
              :args $ [] 'app.schema/Db 'app.schema/Session 'app.schema/SharedTwig
          :tests $ []
            %{} 'TestEntry (:name |typed-store-roundtrip)
              :code $ quote
                let
                    message $ %{} app.schema/Message (:id |m1) (:text |hello)
                    session-data $ %{} app.schema/Session
                      :user-id $ %none
                      :id 1
                      :nickname $ %none
                      :router $ %{} app.schema/Router (:name :home)
                      :messages $ {} (|m1 message)
                    db $ %{} app.schema/Db
                      :sessions $ {} (1 session-data)
                      :users $ {}
                    shared $ twig-shared db 0
                    store $ twig-container db session-data shared
                    decoded $ parse-cirru-edn (format-cirru-edn store)
                    session-view $ :session store
                    raw-message $ option:unwrap
                      get (:messages session-view) |m1
                    typed-message $ assert-type raw-message app.schema/MessageView
                  assert= true $ &struct:matches? store Store
                  assert= true $ &struct:matches? decoded Store
                  assert= true $ &struct:matches? typed-message MessageView
                  assert= 0 $ :count store
                  assert= |hello $ :text typed-message
              :tags $ #{} :twig :type
            %{} 'TestEntry (:name |session-none-fields)
              :code $ quote
                let
                    db app.schema/database
                    session-data app.schema/session
                    shared $ twig-shared db 0
                    projected $ twig-container db session-data shared
                    view $ :session projected
                  assert= (%some 0) (:id view)
                  assert= (%none) (:user-id view)
                  assert= (%none) (:nickname view)
                  assert= view $ parse-cirru-edn (format-cirru-edn view)
              :tags $ #{} :client :server :twig :type
            %{} 'TestEntry (:name |session-some-fields)
              :code $ quote
                let
                    user-data $ %{} app.schema/User (:id |u1) (:name |demo)
                      :nickname $ %none
                      :avatar $ %none
                      :password |hash
                    session-data $ %{} app.schema/Session (:id 0)
                      :user-id $ %some |u1
                      :nickname $ %some ||
                      :router $ %{} app.schema/Router (:name :home)
                      :messages $ {}
                    db $ %{} app.schema/Db
                      :sessions $ {} (0 session-data)
                      :users $ {} (|u1 user-data)
                    shared $ twig-shared db 0
                    projected $ twig-container db session-data shared
                    view $ :session projected
                  assert= (%some 0) (:id view)
                  assert= (%some |u1) (:user-id view)
                  assert= (%some ||) (:nickname view)
                  assert= true $ :logged-in? projected
                  assert= view $ parse-cirru-edn (format-cirru-edn view)
              :tags $ #{} :client :server :twig :type
        'twig-members $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn twig-members (sessions users)
              -> sessions (.to-list)
                map $ fn (pair)
                  let[] (sid raw-session) pair $ let
                      session-data $ assert-type raw-session app.schema/Session
                    [] sid $ match (:user-id session-data)
                      (:none) (%none)
                      (:some user-id)
                        if-let
                          raw-user $ get users user-id
                          let
                              user-data $ assert-type raw-user app.schema/User
                            %some $ :name user-data
                          %none
                pairs-map
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] (:: 'Map 'Number 'app.schema/Session) (:: 'Map 'String 'app.schema/User)
              :return $ :: 'Map 'Number (:: 'Option 'String)
        'twig-shared $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn twig-shared (db record-count)
              %{} SharedTwig (:reel-length record-count)
                :attached $ %{} AttachedView (:type :msg) (:content "|SOME data")
                :pages $ %none
                :members $ twig-members (:sessions db) (:users db)
                :session-count $ count (:sessions db)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/SharedTwig)
              :args $ [] 'app.schema/Db 'Number
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.twig.container $ :require
            app.twig.user :refer $ twig-user
            recollect.memo :refer $ memo-twig-by1
            app.schema :refer $ AttachedView MessageView RouterView SessionView SharedTwig Store
    'app.twig.user $ %{} 'FileEntry
      :defs $ {}
        'twig-user $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn twig-user (user-data)
              %{} UserView
                :name $ :name user-data
                :id $ :id user-data
                :nickname $ :nickname user-data
                :avatar $ :avatar user-data
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/UserView)
              :args $ [] 'app.schema/User
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.twig.user $ :require
            app.schema :refer $ UserView
    'app.updater $ %{} 'FileEntry
      :defs $ {}
        'updater $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn updater (db op sid op-id op-time)
              match op
                (:session/connect) (session/connect db sid op-id op-time)
                (:session/disconnect) (session/disconnect db sid op-id op-time)
                (:session/remove-message data) (session/remove-message db data sid op-id op-time)
                (:user/log-in username password) (user/log-in db username password sid op-id op-time)
                (:user/sign-up username password) (user/sign-up db username password sid op-id op-time)
                (:user/log-out) (user/log-out db sid op-id op-time)
                (:router/change data) (router/change db data sid op-id op-time)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/Db)
              :args $ [] 'app.schema/Db 'app.schema/DomainOp 'Number 'String 'Number
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.updater $ :require (app.updater.session :as session) (app.updater.user :as user) (app.updater.router :as router) (app.schema :as schema)
            app.schema :refer $ Op
            respo-message.updater :refer $ update-messages
    'app.updater.router $ %{} 'FileEntry
      :defs $ {}
        'change $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn change (db op-data sid op-id op-time)
              if-let
                raw-session $ get (:sessions db) sid
                let
                    session-data $ assert-type raw-session app.schema/Session
                  assoc db :sessions $ assoc (:sessions db) sid
                    struct-with session-data $ :router op-data
                , db
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/Db)
              :args $ [] 'app.schema/Db 'app.schema/Router 'Number 'String 'Number
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote (ns app.updater.router)
    'app.updater.session $ %{} 'FileEntry
      :defs $ {}
        'connect $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn connect (db sid op-id op-time)
              assoc db :sessions $ assoc (:sessions db) sid
                %{} schema/Session
                  :user-id $ %none
                  :id sid
                  :nickname $ %none
                  :router schema/router
                  :messages $ {}
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/Db)
              :args $ [] 'app.schema/Db 'Number 'String 'Number
        'disconnect $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn disconnect (db sid op-id op-time)
              assoc db :sessions $ dissoc (:sessions db) sid
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/Db)
              :args $ [] 'app.schema/Db 'Number 'String 'Number
        'remove-message $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn remove-message (db op-data sid op-id op-time)
              if-let
                raw-session $ get (:sessions db) sid
                let
                    session-data $ assert-type raw-session app.schema/Session
                  assoc db :sessions $ assoc (:sessions db) sid
                    struct-with session-data $ :messages
                      dissoc (:messages session-data) (:id op-data)
                , db
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/Db)
              :args $ [] 'app.schema/Db 'app.schema/RemoveMessage 'Number 'String 'Number
          :tests $ []
            %{} 'TestEntry (:name |existing-message-map-callback)
              :code $ quote
                let
                    sid 1
                    session-data $ %{} app.schema/Session (:id sid)
                      :user-id $ %none
                      :nickname $ %none
                      :router $ %{} app.schema/Router (:name :home)
                      :messages $ {}
                        |m1 $ %{} app.schema/Message (:id |m1) (:text |remove)
                        |m2 $ %{} app.schema/Message (:id |m2) (:text |keep)
                    db $ %{} app.schema/Db
                      :sessions $ {} (sid session-data)
                      :users $ {}
                    result $ remove-message db
                      %{} app.schema/RemoveMessage $ :id |m1
                      , sid |op 0
                    raw-session $ option:unwrap
                      get (:sessions result) sid
                    next-session $ assert-type raw-session app.schema/Session
                    next-message $ assert-type
                      option:unwrap $ get (:messages next-session) |m2
                      , app.schema/Message
                  assert= (%none)
                    get (:messages next-session) |m1
                  assert= |keep $ :text next-message
              :tags $ #{} :protocol :server
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.updater.session $ :require (app.schema :as schema)
    'app.updater.user $ %{} 'FileEntry
      :defs $ {}
        'log-in $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn log-in (db username password sid op-id op-time)
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
                    assoc db :sessions $ assoc (:sessions db) sid
                      if-let (raw-user maybe-user)
                        let
                            user-data $ assert-type raw-user app.schema/User
                          if
                            = (md5 password) (:password user-data)
                            struct-with session-data $ :user-id
                              %some $ :id user-data
                            struct-with session-data $ :messages
                              assoc (:messages session-data) op-id $ %{} app.schema/Message (:id op-id)
                                :text $ str "|Wrong password for " username
                        struct-with session-data $ :messages
                          assoc (:messages session-data) op-id $ %{} app.schema/Message (:id op-id)
                            :text $ str "|No user named: " username
                  , db
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/Db)
              :args $ [] 'app.schema/Db 'String 'String 'Number 'String 'Number
          :tests $ []
            %{} 'TestEntry (:name |existing-session-callbacks)
              :code $ quote
                let
                    sid 1
                    session-data $ %{} app.schema/Session (:id sid)
                      :user-id $ %none
                      :nickname $ %none
                      :router app.schema/router
                      :messages $ {}
                    user-data $ %{} app.schema/User (:id |user-1) (:name |demo)
                      :nickname $ %none
                      :avatar $ %none
                      :password $ md5 |secret
                    db $ %{} app.schema/Db
                      :sessions $ {} (sid session-data)
                      :users $ {} (|user-1 user-data)
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
                  assert= (%some |user-1) (:user-id success-session)
              :tags $ #{} :protocol :server
        'log-out $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn log-out (db sid op-id op-time)
              if-let
                raw-session $ get (:sessions db) sid
                let
                    session-data $ assert-type raw-session app.schema/Session
                  assoc db :sessions $ assoc (:sessions db) sid
                    struct-with session-data $ :user-id (%none)
                , db
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/Db)
              :args $ [] 'app.schema/Db 'Number 'String 'Number
        'sign-up $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn sign-up (db username password sid op-id op-time)
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
                      assoc db :sessions $ assoc (:sessions db) sid
                        struct-with session-data $ :messages
                          assoc (:messages session-data) op-id $ %{} app.schema/Message (:id op-id)
                            :text $ str "|Name is taken: " username
                      -> db
                        assoc :sessions $ assoc (:sessions db) sid
                          struct-with session-data $ :user-id (%some op-id)
                        assoc :users $ assoc (:users db) op-id
                          %{} app.schema/User (:id op-id) (:name username)
                            :nickname $ %some username
                            :password $ md5 password
                            :avatar $ %none
                  , db
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/Db)
              :args $ [] 'app.schema/Db 'String 'String 'Number 'String 'Number
          :tests $ []
            %{} 'TestEntry (:name |duplicate-user-message-callback)
              :code $ quote
                let
                    sid 1
                    session-data $ %{} app.schema/Session (:id sid)
                      :user-id $ %none
                      :nickname $ %none
                      :router app.schema/router
                      :messages $ {}
                    user-data $ %{} app.schema/User (:id |user-1) (:name |demo)
                      :nickname $ %none
                      :avatar $ %none
                      :password $ md5 |secret
                    db $ %{} app.schema/Db
                      :sessions $ {} (sid session-data)
                      :users $ {} (|user-1 user-data)
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
        :code $ quote
          ns app.updater.user $ :require
            calcit.std.hash :refer $ md5
    'app.workload.diff-patch $ %{} 'FileEntry
      :defs $ {}
        'DomainOp $ %{} 'CodeEntry (:doc "|A replayable state transition covering no-op, leaf, insert, remove, reorder, and replacement cases.")
          :code $ quote
            defenum DomainOp (:noop) (:set-label 'String 'String) (:insert 'Entity) (:remove 'String)
              :reorder $ :: 'List 'String
              :replace $ :: 'List 'Entity
          :examples $ []
          :schema $ :: 'EnumDef
        'Entity $ %{} 'CodeEntry (:doc "|One deterministic keyed entity used by the workload.")
          :code $ quote
            defstruct Entity (:id 'String) (:rank 'Number) (:label 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'WorkloadInput $ %{} 'CodeEntry (:doc "|A fixed seed, base state, and deterministic DomainOp sequence.")
          :code $ quote
            defstruct WorkloadInput (:seed 'Number) (:base 'WorkloadState)
              :ops $ :: 'List 'DomainOp
          :examples $ []
          :schema $ :: 'StructDef
        'WorkloadState $ %{} 'CodeEntry (:doc "|Server-side keyed entities plus their explicit presentation order.")
          :code $ quote
            defstruct WorkloadState
              :entities $ :: 'Map 'String 'Entity
              :order $ :: 'List 'String
          :examples $ []
          :schema $ :: 'StructDef
        'WorkloadStore $ %{} 'CodeEntry (:doc "|Client projection consumed by data diff and browser rendering.")
          :code $ quote
            defstruct WorkloadStore
              :rows $ :: 'List 'Entity
              :count 'Number
          :examples $ []
          :schema $ :: 'StructDef
        'apply-domain-op $ %{} 'CodeEntry (:doc "|Apply one DomainOp without mutating the previous WorkloadState.")
          :code $ quote
            defn apply-domain-op (state op)
              match op
                (:noop) state
                (:set-label id label)
                  match
                    get (:entities state) id
                    (:some entity)
                      %{} WorkloadState
                        :order $ :order state
                        :entities $ assoc (:entities state) id (assoc entity :label label)
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
                    :order $ map entities
                      fn (raw-entity)
                        let
                            entity $ assert-type raw-entity Entity
                          :id entity
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'WorkloadState)
              :args $ [] 'WorkloadState 'DomainOp
          :tags $ #{} :scaffold
        'entities-by-id $ %{} 'CodeEntry (:doc "|Index an entity list by its stable identifier.")
          :code $ quote
            defn entities-by-id (entities)
              -> entities
                map $ fn (raw-entity)
                  let
                      entity $ assert-type raw-entity Entity
                    [] (:id entity) entity
                pairs-map
          :examples $ []
          :schema $ :: 'Fn
            {}
              :args $ [] (:: 'List 'Entity)
              :return $ :: 'Map 'String 'Entity
          :tags $ #{} :scaffold
        'entity-id $ %{} 'CodeEntry (:doc "|Derive a stable entity key from the fixed seed and index.")
          :code $ quote
            defn entity-id (seed index) (str |entity- seed |- index)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'String)
              :args $ [] 'Number 'Number
          :tags $ #{} :scaffold
        'main! $ %{} 'CodeEntry (:doc "|Provide a side-effect-free entry for deterministic workload code generation.")
          :code $ quote
            defn main! () $ let
                input-data $ make-workload-input 2 794
                next-state $ replay-domain-ops (:base input-data) (:ops input-data)
                next-store $ project-state next-state
              do (workload-view next-store) &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
          :tags $ #{} :scaffold
        'make-entity $ %{} 'CodeEntry (:doc "|Construct one deterministic typed entity.")
          :code $ quote
            defn make-entity (seed index)
              %{} Entity
                :id $ entity-id seed index
                :rank index
                :label $ str |item- seed |- index
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Entity)
              :args $ [] 'Number 'Number
          :tags $ #{} :scaffold
        'make-workload-input $ %{} 'CodeEntry (:doc "|Construct a deterministic workload of the requested size and seed.")
          :code $ quote
            defn make-workload-input (size seed)
              let
                  entities $ map (range size)
                    fn (index) (make-entity seed index)
                  order $ map entities
                    fn (raw-entity)
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
          :schema $ :: 'Fn
            {} (:return 'WorkloadInput)
              :args $ [] 'Number 'Number
          :tags $ #{} :scaffold
          :tests $ []
            %{} 'TestEntry (:name |deterministic-shape)
              :code $ quote
                let
                    input-data $ make-workload-input 4 794
                    base-state $ :base input-data
                    operations $ :ops input-data
                  do
                    assert= 4 $ count (:order base-state)
                    assert= 6 $ count operations
              :tags $ #{} :client
        'project-state $ %{} 'CodeEntry (:doc "|Project ordered keyed entities into the client WorkloadStore.")
          :code $ quote
            defn project-state (state)
              let
                  rows $ map (:order state)
                    fn (id)
                      option:unwrap $ get (:entities state) id
                %{} WorkloadStore (:rows rows)
                  :count $ count rows
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'WorkloadStore)
              :args $ [] 'WorkloadState
          :tags $ #{} :scaffold
        'replay-domain-ops $ %{} 'CodeEntry (:doc "|Replay the same DomainOp sequence against a WorkloadState.")
          :code $ quote
            defn replay-domain-ops (state ops)
              list-match ops
                () state
                (op remaining)
                  recur (apply-domain-op state op) remaining
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'WorkloadState)
              :args $ [] 'WorkloadState (:: 'List 'DomainOp)
          :tags $ #{} :scaffold
          :tests $ []
            %{} 'TestEntry (:name |deterministic-replay)
              :code $ quote
                let
                    input-data $ make-workload-input 4 794
                    final-state $ replay-domain-ops (:base input-data) (:ops input-data)
                    final-store $ project-state final-state
                    raw-first-row $ option:unwrap
                      nth (:rows final-store) 0
                    first-row $ assert-type raw-first-row Entity
                  do
                    assert= 4 $ :count final-store
                    assert= |entity-795-0 $ :id first-row
              :tags $ #{} :client
        'workload-ref! $ %{} 'CodeEntry (:doc "|Stable no-op ref callback used to detect unexpected ref churn at the browser FFI boundary.")
          :code $ quote
            defn workload-ref! (_target) &unit
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'respo.dom/DomElement
              :features $ #{} :js-ffi
          :tags $ #{} :scaffold
        'workload-view $ %{} 'CodeEntry (:doc "|Render keyed rows plus stable focus and listener probes for browser checks.")
          :code $ quote
            defn workload-view (store)
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
                            :inner-text $ str (:rank entity) |: (:label entity)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'respo.schema/Element)
              :args $ [] 'WorkloadStore
          :tags $ #{} :scaffold
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.workload.diff-patch $ :require
            respo.core :refer $ div input list->
            recollect.diff :refer $ diff-twig
            recollect.patch :refer $ patch-twig
