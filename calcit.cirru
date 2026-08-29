
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
            defatom *store $ :: :loading
          :examples $ []
          :schema $ :: 'Dynamic
        '*sync-revision $ %{} 'CodeEntry (:doc |)
          :code $ quote (defatom *sync-revision 0)
          :examples $ []
          :schema $ :: 'Dynamic
        'ClientPatchError $ %{} 'CodeEntry (:doc "|Client-side reason for rejecting a revisioned patch before requesting a full snapshot.")
          :code $ quote
            defenum ClientPatchError (:revision-mismatch 'Number 'Number) (:invalid-patch 'recollect.patch/PatchError)
          :examples $ []
          :schema $ :: 'EnumDef
        'ack-sync! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn ack-sync! (revision)
              ws-send! $ :: :sync/ack revision
          :examples $ []
          :schema $ :: 'Dynamic
        'apply-server-patch! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn apply-server-patch! (base-revision revision changes)
              match (validate-server-patch @*store @*sync-revision base-revision changes)
                (:ok next-store)
                  do (reset! *store next-store) (reset! *sync-revision revision) (ack-sync! revision)
                (:err error)
                  do
                    match error
                      (:revision-mismatch expected actual) (js/console.warn |Sync-revision-mismatch expected actual)
                      (:invalid-patch patch-error)
                        js/console.error |Failed-to-apply-server-patch $ patch-error-message patch-error
                    request-snapshot!
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Number 'Number (:: 'List 'recollect.schema/change-op)
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
              reset! *store $ :: :loading
              ws-connect! (str |ws:// host |: port)
                {}
                  :on-open $ fn (event)
                    do (reset! *connected? true) (send-activity!) (simulate-login!)
                  :on-close $ fn (event) (reset! *connected? false)
                    reset! *store $ :: :offline
                    js/console.error "|Lost connection!"
                  :on-data on-server-data
                  :class-mapper $ {} (:Option Option) (:Store schema/Store) (:SessionView schema/SessionView) (:RouterView schema/RouterView) (:AttachedView schema/AttachedView) (:UserView schema/UserView) (:MessageView schema/MessageView)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'dispatch! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn dispatch! (op ? op-data)
              when
                and config/dev? $ not= op :states
                println |Dispatch op op-data
              if (tag? op)
                recur $ :: op op-data
                match op
                  (:states cursor s)
                    reset! *states $ update-states @*states cursor s
                  (:effect/connect) (connect!)
                  _ $ ws-send! op
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Dynamic)
              :args $ [] 'app.schema/Op 'Dynamic
        'main! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn main! () $ do
              println "|Running mode:" $ if config/dev? |dev |release
              if config/dev? $ load-console-formatter!
              render-app!
              connect!
              add-watch *store :changes $ fn (store prev) (render-app!)
              add-watch *states :changes $ fn (states prev) (render-app!)
              on-page-touch $ fn ()
                if
                  = @*store $ :: :offline
                  connect!
              js/window.addEventListener |visibilitychange $ fn (event)
                when @*connected? $ send-activity!
              visibility-heartbeat $ fn ()
                when @*connected? $ ws-send! (:: :sync/heartbeat @*sync-revision)
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
        'normalize-server-message $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn normalize-server-message (data)
              if (enum? data)
                assoc data 0 $ turn-tag
                  option:unwrap $ nth data 0
                data
          :examples $ []
          :schema $ :: 'Dynamic
        'on-server-data $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn on-server-data (data)
              let
                  message $ normalize-server-message data
                match message
                  (:snapshot revision store)
                    do (reset! *store store) (reset! *sync-revision revision) (ack-sync! revision)
                  (:patch base-revision revision changes)
                    do
                      when config/dev? $ js/console.log |Changes changes
                      apply-server-patch! base-revision revision changes
                  (:effect/pong) (do :ok)
                  _ $ eprintln "|unknown server data kind:" message
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
                println "|Code updated."
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'render-app! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn render-app! () $ let
                states $ option:unwrap-or (get @*states :states) ({})
                store @*store
                app $ if (enum? store) (comp-offline store)
                  if
                    and (struct? store) (&struct:matches? store schema/Store)
                    comp-container states $ unsafe-coerce store 'app.schema/Store
                    do
                      js/console.error |Invalid-store-payload
                        {}
                          :struct? $ struct? store
                          :store-schema-match? $ if (struct? store) (&struct:matches? store schema/Store) false
                        , store
                      div ({}) (<> "|Invalid store payload")
              render! mount-target app dispatch!
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
        'request-snapshot! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn request-snapshot! () $ ws-send! (:: :sync/resume @*sync-revision)
          :examples $ []
          :schema $ :: 'Dynamic
        'send-activity! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn send-activity! () $ if (= |visible js/document.visibilityState)
              ws-send! $ :: :sync/active @*sync-revision
              ws-send! $ :: :sync/idle @*sync-revision
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
              :return $ :: 'Result 'T 'ClientPatchError
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
        'visibility-heartbeat $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn visibility-heartbeat (cb ? duration)
              unsafe-coerce
                flipped js/setInterval (option:unwrap-or duration 3000)
                  fn () $ let
                      document-node $ unsafe-coerce js/document 'JsObject
                    when
                      = |visible $ .-visibilityState document-node
                      cb
                , 'Number
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Number)
              :args $ [] 'Fn (:: 'Option 'Number)
              :features $ #{} :js-ffi
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.client $ :require
            respo.core :refer $ render! clear-cache! realize-ssr! div <>
            respo.cursor :refer $ update-states
            app.comp.container :refer $ comp-container comp-offline
            app.schema :as schema
            app.schema :refer $ Op
            app.config :as config
            ws-edn.client :refer $ ws-connect! ws-send!
            recollect.patch :refer $ patch-batch patch-error-message PatchError PatchPathSegment PatchBatchOps
            cumulo-util.core :refer $ on-page-touch
            |url-parse :default url-parse
            |bottom-tip :default hud!
            |./calcit.build-errors :default client-errors
            recollect.schema :as patch-schema
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
                    :background-color $ option:unwrap (get config/site :theme)
                div $ {}
                  :style $ {} (:height 0)
                div $ {}
                  :style $ {}
                    :background-image $ str "|url("
                      option:unwrap $ get config/site :icon
                      , "|)"
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
          :schema $ :: 'Dynamic
        'comp-session-messages $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defcomp comp-session-messages (messages)
              list->
                {} $ :style
                  {} (:position :fixed) (:top 8) (:right 8) (:z-index 1000)
                -> messages
                  map-kv $ fn (id message)
                    hint-fn $ {}
                      :args $ [] 'String 'app.schema/MessageView
                      :return 'List
                    [] id $ div
                      {}
                        :style $ {} (:padding 8) (:margin-bottom 8)
                          :background-color $ hsl 0 80 95
                          :border $ str "|1px solid " (hsl 0 70 80)
                          :border-radius 4
                          :cursor :pointer
                        :on-click $ fn (e d!)
                          d! $ %:: schema/Op :session/remove-message
                            {} $ :id id
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
                              d! cursor $ assoc state :username (value .unwrap-or |)
                      =< nil 8
                      div ({})
                        input $ {} (:placeholder |Password) (:class-name css/input)
                          :value $ option:unwrap-or (get state :password) |
                          :on-input $ fn (e d!)
                            let
                                value $ get e :value
                              d! cursor $ assoc state :password (value .unwrap-or |)
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
                        {} $ :name :home
                    :style $ {} (:cursor :pointer)
                  <>
                    option:unwrap-or (get config/site :title) |Calcium
                    , nil
                div
                  {}
                    :style $ {} (:cursor |pointer)
                    :on-click $ fn (e d!)
                      d! $ %:: app.schema/Op :router/change
                        {} $ :name :profile
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
          :schema $ :: 'Enum
        'MessageView $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct MessageView (:id 'String) (:text 'String)
          :examples $ []
          :schema $ :: 'Enum
        'Op $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defenum Op (:session/connect) (:session/disconnect) (:session/remove-message 'Dynamic) (:user/log-in 'String 'String) (:user/sign-up 'String 'String) (:user/log-out) (:router/change 'Dynamic) (:effect/persist) (:effect/ping) (:effect/pong) (:effect/connect) (:reel/reset) (:reel/merge) (:states 'Dynamic 'Dynamic)
          :examples $ []
          :schema $ :: 'Enum
        'RouterView $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct RouterView (:name 'Tag)
              :data $ :: 'Option 'Map
              :router $ :: 'Option 'Map
          :examples $ []
          :schema $ :: 'Enum
        'SessionView $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct SessionView
              :user-id $ :: 'Optional 'String
              :id $ :: 'Optional 'Number
              :nickname $ :: 'Optional 'String
              :router $ quote app.schema/RouterView
              :messages $ :: 'Map 'String (quote app.schema/MessageView)
          :examples $ []
          :schema $ :: 'Enum
        'SharedTwig $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct SharedTwig (:reel-length 'Number)
              :attached $ quote app.schema/AttachedView
              :pages $ :: 'Option 'Map
              :members 'Map
              :session-count 'Number
          :examples $ []
          :schema $ :: 'Enum
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
          :schema $ :: 'Enum
        'UserView $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defstruct UserView (:name 'String) (:id 'String)
              :nickname $ :: 'Option 'String
              :avatar $ :: 'Option 'String
          :examples $ []
          :schema $ :: 'Enum
        'database $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def database $ {}
              :sessions $ noted session ({})
              :users $ noted user ({})
          :examples $ []
          :schema $ :: 'Dynamic
        'router $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def router $ {} (:name nil) (:title nil)
              :data $ {}
              :router nil
          :examples $ []
          :schema $ :: 'Dynamic
        'session $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def session $ {} (:user-id nil) (:id nil) (:nickname nil)
              :router $ noted router
                {} (:name :home) (:data nil) (:router nil)
              :messages $ {}
          :examples $ []
          :schema $ :: 'Dynamic
        'user $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def user $ {} (:name nil) (:id nil) (:nickname nil) (:avatar nil) (:password nil)
          :examples $ []
          :schema $ :: 'Dynamic
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
                merge schema/database $ parse-cirru-edn (read-file storage-file)
              do (println "|Found no data") schema/database
          :examples $ []
          :schema $ :: 'Dynamic
        '*reader-reel $ %{} 'CodeEntry (:doc |)
          :code $ quote (defatom *reader-reel @*reel)
          :examples $ []
          :schema $ :: 'Dynamic
        '*reel $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *reel $ merge reel-schema
              {} (:base @*initial-db) (:db @*initial-db)
          :examples $ []
          :schema $ :: 'Ref 'cumulo-reel.core/ReelState
        '*shared-twig-cache $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defatom *shared-twig-cache $ {} (:revision -1) (:value nil)
          :examples $ []
          :schema $ :: 'Dynamic
        '*sync-revision $ %{} 'CodeEntry (:doc |)
          :code $ quote (defatom *sync-revision 0)
          :examples $ []
          :schema $ :: 'Ref 'Number
        'acknowledge-client! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn acknowledge-client! (sid revision)
              let
                  state $ option:unwrap (get @*client-states sid)
                when
                  = revision $ option:unwrap (get state :sent-rev)
                  let
                      sent-store $ option:unwrap (get state :sent-store)
                    swap! *client-caches assoc sid sent-store
                  swap! *client-states update sid $ fn (current)
                    dissoc
                      merge current $ {} (:acked-rev revision) (:in-flight? false)
                      , :sent-rev :sent-store
                  when
                    >
                      option:unwrap-or (get state :dirty-rev) 0
                      , revision
                    swap! *dirty-clients include sid
          :examples $ []
          :schema $ :: 'Dynamic
        'dispatch! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn dispatch! (op sid)
              let
                  op-id $ generate-id!
                  op-time $ -> (get-time!) (.timestamp)
                if config/dev? $ println |Dispatch! (str op) sid
                match op
                  (:effect/persist) (persist-db!)
                  (:effect/ping)
                    wss-send! sid $ format-cirru-edn (:: :effect/pong)
                  _ $ reset! *reel (reel-reducer @*reel updater op sid op-id op-time config/dev?)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Dynamic)
              :args $ [] 'app.schema/Op 'Number
        'get-backup-path! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn get-backup-path! () $ let
                now $ .extract (get-time!)
              join-path calcit-dirname |backups
                str $ option:unwrap (get now :month)
                str
                  option:unwrap $ get now :day
                  , |-snapshot.cirru
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
                      value $ twig-shared (:db reel) (:records reel)
                    reset! *shared-twig-cache $ {} (:revision revision) (:value value)
                    , value
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Dynamic)
              :args $ [] 'cumulo-reel.core/ReelState 'Number
        'handle-client-message! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn handle-client-message! (action sid)
              match action
                (:sync/active client-revision) (mark-client-active! sid client-revision false)
                (:sync/heartbeat client-revision) (touch-client! sid client-revision)
                (:sync/idle client-revision) (mark-client-idle! sid client-revision)
                (:sync/resume client-revision) (mark-client-active! sid client-revision true)
                (:sync/ack revision) (acknowledge-client! sid revision)
                _ $ dispatch! action sid
          :examples $ []
          :schema $ :: 'Dynamic
        'handle-sync-send! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn handle-sync-send! (sid revision new-store outcome)
              swap! *client-states update sid $ fn (current) (next-sync-send-state current revision new-store outcome)
              match outcome
                (:accepted) &unit
                (:backpressured) (swap! *dirty-clients include sid)
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
              wss-each! $ fn (sid)
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
          :schema $ :: 'Dynamic
        'main! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn main! () $ do
              println "|Running mode:" $ if config/dev? |dev |release
              let
                  port $ if-let
                    value $ get-env |port
                    match (parse-float value)
                      (:ok parsed) parsed
                      (:err _)
                        option:unwrap $ get config/site :port
                    option:unwrap $ get config/site :port
                do (run-server! port)
                  println $ str "|Server started on port:" port
              do (; "|Initialize lazy definitions before starting background callbacks.") (identity Date) (identity @*reader-reel)
              set-interval 200 $ fn () (render-loop!)
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
                when resumed? (swap! *client-caches dissoc sid) (swap! *dirty-clients include sid)
          :examples $ []
          :schema $ :: 'Dynamic
        'mark-client-idle! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn mark-client-idle! (sid client-revision)
              when
                option:some? $ get @*client-states sid
                swap! *client-states update sid $ fn (state)
                  dissoc
                    merge state $ {} (:status :idle) (:acked-rev client-revision) (:in-flight? false) (:needs-snapshot? true)
                    , :sent-rev :sent-store
                swap! *client-caches dissoc sid
                swap! *dirty-clients exclude sid
          :examples $ []
          :schema $ :: 'Dynamic
        'mark-clients-dirty! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn mark-clients-dirty! (revision)
              wss-each! $ fn (sid)
                let
                    state $ option:unwrap (get @*client-states sid)
                  swap! *client-states assoc-in ([] sid :dirty-rev) revision
                  when
                    = :active $ option:unwrap (get state :status)
                    swap! *dirty-clients include sid
          :examples $ []
          :schema $ :: 'Dynamic
        'next-sync-send-state $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn next-sync-send-state (current revision new-store outcome)
              match outcome
                (:accepted)
                  merge current $ {} (:sent-rev revision) (:sent-store new-store) (:in-flight? true) (:needs-snapshot? false) (:slow-client? false) (:last-send-outcome :accepted)
                (:backpressured)
                  merge current $ {} (:slow-client? true) (:last-send-outcome :backpressured)
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
            %{} 'TestEntry (:name |backpressure-preserves-ack-baseline)
              :code $ quote
                assert=
                  {} (:status :active) (:acked-rev 5) (:slow-client? true) (:last-send-outcome :backpressured)
                  next-sync-send-state
                    {} (:status :active) (:acked-rev 5)
                    , 7
                      {} $ :value 1
                      %:: wss.core/WssSendOutcome :backpressured
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
        'now-ms $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn now-ms () $ -> (get-time!) (.timestamp)
          :examples $ []
          :schema $ :: 'Dynamic
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
                  assoc
                    :db $ unsafe-coerce @*reel 'cumulo-reel.core/ReelState
                    , :sessions $ {}
                storage-path storage-file
                backup-path $ get-backup-path!
              do (check-write-file! storage-path file-content) (check-write-file! backup-path file-content)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ []
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
        'run-server! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn run-server! (port)
              wss-serve!
                {} $ :port port
                fn (data)
                  match data
                    (:connect sid)
                      do
                        swap! *client-states assoc sid $ {} (:status :idle)
                          :last-heartbeat $ now-ms
                          :acked-rev 0
                          :dirty-rev @*sync-revision
                          :in-flight? false
                          :needs-snapshot? true
                        dispatch! (%:: schema/Op :session/connect) sid
                        println "|New client."
                    (:message sid msg)
                      let
                          action $ parse-cirru-edn msg
                        handle-client-message! action sid
                    (:disconnect sid)
                      do (println "|Client closed!")
                        dispatch! (%:: schema/Op :session/disconnect) sid
                        swap! *client-caches dissoc sid
                        swap! *client-states dissoc sid
                        swap! *dirty-clients exclude sid
                    _ $ println "|unknown data:" data
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'Number
        'storage-file $ %{} 'CodeEntry (:doc |)
          :code $ quote
            def storage-file $ if (empty? calcit-dirname)
              str calcit-dirname $ option:unwrap (get config/site :storage-file)
              str calcit-dirname |/ $ option:unwrap (get config/site :storage-file)
          :examples $ []
          :schema $ :: 'Dynamic
        'sweep-idle-clients! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn sweep-idle-clients! () $ let
                current-time $ now-ms
              wss-each! $ fn (sid)
                let
                    state $ option:unwrap (get @*client-states sid)
                    last-heartbeat $ option:unwrap-or (get state :last-heartbeat) 0
                  when
                    and
                      = :active $ option:unwrap (get state :status)
                      > (- current-time last-heartbeat) heartbeat-timeout
                    mark-client-idle! sid $ option:unwrap-or (get state :acked-rev) 0
          :examples $ []
          :schema $ :: 'Dynamic
        'sync-client! $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn sync-client! (sid reel revision) (swap! *dirty-clients exclude sid)
              let
                  state $ option:unwrap (get @*client-states sid)
                when
                  and
                    = :active $ option:unwrap (get state :status)
                    not $ option:unwrap-or (get state :in-flight?) false
                  let
                      db $ :db reel
                      records $ :records reel
                      session $ option:unwrap
                        get-in db $ [] :sessions sid
                      shared $ get-shared-twig reel revision
                      old-store-option $ get @*client-caches sid
                      new-store $ twig-container db session records shared
                      needs-snapshot? $ or
                        option:unwrap-or (get state :needs-snapshot?) true
                        option:none? old-store-option
                      changes $ if needs-snapshot? ([])
                        diff-twig (option:unwrap old-store-option) new-store $ {} (:key :id)
                      send-snapshot? $ or needs-snapshot?
                        > (count changes) patch-operation-limit
                      base-revision $ option:unwrap-or (get state :acked-rev) 0
                    if send-snapshot?
                      handle-sync-send! sid revision new-store $ wss-send! sid
                        format-cirru-edn $ :: :snapshot revision new-store
                      if
                        not= changes $ []
                        handle-sync-send! sid revision new-store $ wss-send! sid
                          format-cirru-edn $ :: :patch base-revision revision changes
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
                  wss-each! $ fn (sid)
                    when (includes? @*dirty-clients sid) (sync-client! sid reel revision)
                finish-twig-frame!
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Unit)
              :args $ [] 'cumulo-reel.core/ReelState
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
            recollect.diff :refer $ diff-twig
            wss.core :refer $ wss-serve! wss-send! wss-each!
            recollect.twig :refer $ clear-twig-caches!
            app.$meta :refer $ calcit-dirname
            calcit.std.fs :refer $ path-exists? check-write-file!
            calcit.std.time :refer $ set-interval
            calcit.std.date :refer $ Date get-time!
            calcit.std.path :refer $ join-path
            recollect.memo :refer $ begin-twig-frame! finish-twig-frame!
    'app.twig.container $ %{} 'FileEntry
      :defs $ {}
        'twig-container $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn twig-container (db session records shared)
              let
                  user-id $ option:unwrap-or (get session :user-id) nil
                  logged-in? $ some? user-id
                  router $ if-let
                    router-data $ get session :router
                    , router-data
                      {} (:name :home) (:data nil) (:router nil)
                  router-name $ option:unwrap (get router :name)
                  router-parent $ if-let
                    value $ get router :router
                    if (nil? value) (%:: Option :none)
                      %:: Option :some $ unsafe-coerce value 'Map
                    %:: Option :none
                  session-router-data $ if-let
                    value $ get router :data
                    if (nil? value) (%:: Option :none)
                      %:: Option :some $ unsafe-coerce value 'Map
                    %:: Option :none
                  session-router $ %{} RouterView (:name router-name) (:data session-router-data) (:router router-parent)
                  router-data $ if logged-in?
                    case-default router-name (%:: Option :none)
                      :home $ :pages shared
                      :profile $ %:: Option :some (:members shared)
                    %:: Option :none
                  router-view $ %{} RouterView (:name router-name) (:data router-data) (:router router-parent)
                  messages-view $ ->
                    option:unwrap-or (get session :messages) ({})
                    .to-list
                    map $ fn (pair)
                      let[] (id message) pair $ [] id
                        %{} MessageView
                          :id $ option:unwrap-or (get message :id) id
                          :text $ option:unwrap-or (get message :text) |
                    pairs-map
                  session-view $ %{} SessionView (:user-id user-id)
                    :id $ option:unwrap-or (get session :id) nil
                    :nickname $ option:unwrap-or (get session :nickname) nil
                    :router session-router
                    :messages messages-view
                  user-option $ if logged-in?
                    %:: Option :some $ memo-twig-by1 user-id twig-user
                      dissoc
                        option:unwrap $ get-in db ([] :users user-id)
                        , :tasks
                    %:: Option :none
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
              :args $ [] 'Map 'Map 'Dynamic 'app.schema/SharedTwig
          :tests $ []
            %{} 'TestEntry (:name |typed-store-roundtrip)
              :code $ quote
                let
                    db $ {}
                      :sessions $ {}
                      :users $ {}
                    session $ {} (:user-id nil) (:id 1) (:nickname nil)
                      :router $ {} (:name :home) (:data nil) (:router nil)
                      :messages $ {}
                        |m1 $ {} (:id |m1) (:text |hello)
                    shared $ twig-shared db ([])
                    store $ twig-container db session ([]) shared
                    decoded $ parse-cirru-edn (format-cirru-edn store)
                    typed-store $ unsafe-coerce store 'app.schema/Store
                    message $ option:unwrap
                      get
                        :messages $ :session typed-store
                        , |m1
                    typed-message $ unsafe-coerce message 'app.schema/MessageView
                  assert= true $ &struct:matches? store Store
                  assert= true $ &struct:matches? decoded Store
                  assert= true $ &struct:matches? message MessageView
                  assert= 0 $ :count typed-store
                  assert= |hello $ :text typed-message
              :tags $ #{} :twig :type
        'twig-members $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn twig-members (sessions users)
              -> sessions (.to-list)
                map $ fn (pair)
                  let[] (k session) pair $ [] k
                    option:unwrap-or
                      get-in users $ []
                        option:unwrap $ get session :user-id
                        , :name
                      , nil
                pairs-map
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Map)
              :args $ [] 'Map 'Map
        'twig-shared $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn twig-shared (db records)
              let
                  sessions $ option:unwrap (get db :sessions)
                  users $ option:unwrap (get db :users)
                  pages $ if-let
                    value $ get db :pages
                    %:: Option :some $ unsafe-coerce value 'Map
                    %:: Option :none
                %{} SharedTwig
                  :reel-length $ count records
                  :attached $ %{} AttachedView (:type :msg) (:content "|SOME data")
                  :pages pages
                  :members $ twig-members sessions users
                  :session-count $ count sessions
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/SharedTwig)
              :args $ [] 'Map 'Dynamic
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
            defn twig-user (user)
              %{} UserView
                :name $ option:unwrap (get user :name)
                :id $ option:unwrap (get user :id)
                :nickname $ option:unwrap-or (get user :nickname) nil
                :avatar $ option:unwrap-or (get user :avatar) nil
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'app.schema/UserView)
              :args $ [] 'Map
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
                _ $ do (eprintln "|Unknown op:" op) db
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Dynamic)
              :args $ [] 'Map 'app.schema/Op 'Number 'String 'Dynamic
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
              assoc-in db ([] :sessions sid :router) op-data
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Map)
              :args $ [] 'Map 'Dynamic 'Number 'String 'Dynamic
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote (ns app.updater.router)
    'app.updater.session $ %{} 'FileEntry
      :defs $ {}
        'connect $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn connect (db sid op-id op-time)
              assoc-in db ([] :sessions sid)
                merge schema/session $ {} (:id sid)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Map)
              :args $ [] 'Map 'Number 'String 'Dynamic
        'disconnect $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn disconnect (db sid op-id op-time)
              update db :sessions $ fn (sessions) (dissoc sessions sid)
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Map)
              :args $ [] 'Map 'Number 'String 'Dynamic
        'remove-message $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn remove-message (db op-data sid op-id op-time)
              update-in db ([] :sessions sid :messages)
                fn (messages)
                  dissoc (option:unwrap messages)
                    option:unwrap $ get op-data :id
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Map)
              :args $ [] 'Map 'Dynamic 'Number 'String 'Dynamic
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.updater.session $ :require (app.schema :as schema)
    'app.updater.user $ %{} 'FileEntry
      :defs $ {}
        'log-in $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn log-in (db username password sid op-id op-time)
              let
                  users $ option:unwrap-or (get db :users) ({})
                  maybe-user $ -> users vals .to-list
                    find $ fn (user)
                      = username $ option:unwrap (get user :name)
                update-in db ([] :sessions sid)
                  fn (session)
                    let
                        session-data $ option:unwrap session
                      if-let (user maybe-user)
                        if
                          = (md5 password)
                            option:unwrap $ get user :password
                          assoc session-data :user-id $ option:unwrap (get user :id)
                          update session-data :messages $ fn (messages)
                            assoc (option:unwrap messages) op-id $ {} (:id op-id)
                              :text $ str "|Wrong password for " username
                        update session-data :messages $ fn (messages)
                          assoc (option:unwrap messages) op-id $ {} (:id op-id)
                            :text $ str "|No user named: " username
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Map)
              :args $ [] 'Map 'String 'String 'Number 'String 'Dynamic
        'log-out $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn log-out (db sid op-id op-time)
              assoc-in db ([] :sessions sid :user-id) nil
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Map)
              :args $ [] 'Map 'Number 'String 'Dynamic
        'sign-up $ %{} 'CodeEntry (:doc |)
          :code $ quote
            defn sign-up (db username password sid op-id op-time)
              let
                  users $ option:unwrap-or (get db :users) ({})
                  maybe-user $ find (vals users)
                    fn (user)
                      = username $ option:unwrap (get user :name)
                if-let (user maybe-user)
                  update-in db ([] :sessions sid :messages)
                    fn (messages)
                      assoc (option:unwrap messages) op-id $ {} (:id op-id)
                        :text $ str "|Name is taken: " username
                  -> db
                    assoc-in ([] :sessions sid :user-id) op-id
                    assoc-in ([] :users op-id)
                      {} (:id op-id) (:name username) (:nickname username)
                        :password $ md5 password
                        :avatar nil
          :examples $ []
          :schema $ :: 'Fn
            {} (:return 'Map)
              :args $ [] 'Map 'String 'String 'Number 'String 'Dynamic
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote
          ns app.updater.user $ :require
            calcit.std.hash :refer $ md5
