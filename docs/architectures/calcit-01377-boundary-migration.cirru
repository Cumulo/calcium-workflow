{}
  :schema-version 1
  :feature 'calcit-01377-boundary-migration
  :doc "|Migrate application-owned operation, browser visibility, typed patch, and date boundaries to Calcit 0.13.77 while preserving the existing realtime protocol."
  :roots $ #{} 'app.comp.login/comp-login 'app.client/dispatch! 'app.client/send-activity! 'app.schema/decode-server-message 'app.server/*reel 'app.server/dispatch! 'app.server/get-backup-path! 'app.server/now-ms 'app.server/next-sync-metrics 'app.server/request-sync-retry! 'app.server/sync-client! 'app.server/sync-clients! 'app.server/mark-client-active! 'app.server/acknowledge-client! 'app.server/run-server! 'app.updater.user/sign-up
  :definitions $ {}
    'app.comp.login/comp-login $ {}
      :mode :external
      :kind :data
      :schema 'Dynamic
    'app.client/dispatch! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'app.schema/Op 'Dynamic
        :return 'Dynamic
    'app.client/send-activity! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ []
        :return 'Unit
    'app.schema/decode-server-message $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'Dynamic
        :return $ :: 'Result 'app.schema/MessageDecodeError 'app.schema/ServerMessage
    'app.server/now-ms $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ []
        :return 'Number
    'app.server/*reel $ {}
      :mode :external
      :kind :data
      :schema $ :: 'Ref 'cumulo-reel.core/ReelState
    'app.server/dispatch! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'app.schema/Op 'Number
        :return 'Dynamic
    'app.server/get-backup-path! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ []
        :return 'String
    'app.server/next-sync-metrics $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'app.server/SyncMetrics 'Tag 'Number 'Number 'String
        :return 'app.server/SyncMetrics
    'app.server/request-sync-retry! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ []
        :return 'Unit
    'app.server/sync-client! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'Number 'cumulo-reel.core/ReelState 'Number
        :return 'Unit
    'app.server/sync-clients! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'cumulo-reel.core/ReelState
        :return 'Unit
    'app.server/mark-client-active! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'Number 'Number 'Bool
        :return 'Unit
    'app.server/acknowledge-client! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'Number 'Number
        :return 'Unit
    'app.server/run-server! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'Number
        :return 'Unit
    'app.updater.user/sign-up $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'Map 'String 'String 'Number 'String 'Dynamic
        :return 'Map
    'app.schema/Op $ {}
      :mode :external
      :kind :data
      :schema $ :: 'Enum
  :edges $ #{}
    :: :type 'app.comp.login/comp-login 'app.schema/Op
    :: :call 'app.server/dispatch! 'app.server/now-ms
