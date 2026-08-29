{}
  :schema-version 1
  :feature 'coalesced-server-sync
  :doc "|Replace the fixed global sync scan with bounded dispatch-driven coalescing while retaining a slower backpressure retry path."
  :roots $ #{} 'app.server/request-sync! 'app.server/request-sync-retry!
  :definitions $ {}
    'app.server/*sync-scheduled? $ {}
      :mode :ensure
      :kind :data
      :doc "|Whether a fast coalesced server sync callback is pending."
      :schema $ :: 'Ref 'Bool
      :code $ quote
        defatom *sync-scheduled? false
    'app.server/*sync-retry-scheduled? $ {}
      :mode :ensure
      :kind :data
      :doc "|Whether a slower backpressure retry callback is pending."
      :schema $ :: 'Ref 'Bool
      :code $ quote
        defatom *sync-retry-scheduled? false
    'app.server/sync-coalesce-delay $ {}
      :mode :ensure
      :kind :data
      :doc "|Maximum coalescing delay in milliseconds for ordinary state updates."
      :schema $ :: :number
      :code $ quote
        def sync-coalesce-delay 16
    'app.server/sync-retry-delay $ {}
      :mode :ensure
      :kind :data
      :doc "|Retry delay in milliseconds after WebSocket backpressure."
      :schema $ :: :number
      :code $ quote
        def sync-retry-delay 200
    'app.server/request-sync! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Request one bounded, coalesced server sync callback."
      :params $ []
      :schema $ :: 'Fn
        {}
          :args $ []
          :return 'Unit
    'app.server/request-sync-retry! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Request one slower retry without blocking new fast sync requests."
      :params $ []
      :schema $ :: 'Fn
        {}
          :args $ []
          :return 'Unit
    'app.server/render-loop! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ []
          :return 'Unit
    'app.server/mark-clients-dirty! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] :number
          :return 'Unit
    'app.server/sync-clients! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'cumulo-reel.core/ReelState
          :return 'Unit
    'app.server/invalidate-sync-caches! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ []
          :return 'Unit
    'app.server/sweep-idle-clients! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ []
          :return 'Unit
  :edges $ #{}
    :: :call 'app.server/request-sync! 'app.server/render-loop!
    :: :call 'app.server/request-sync-retry! 'app.server/request-sync!
    :: :call 'app.server/render-loop! 'app.server/mark-clients-dirty!
    :: :call 'app.server/render-loop! 'app.server/sync-clients!
