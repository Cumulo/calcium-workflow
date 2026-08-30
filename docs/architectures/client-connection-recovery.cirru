{}
  :schema-version 1
  :feature 'client-connection-recovery
  :doc "|ws-edn owns visibility/online lifecycle, bounded retry, and heartbeat deadline; Calcium adds manual page-touch acceleration and revision resynchronization on every open."
  :roots $ #{} 'app.client/recover-connection!
  :definitions $ {}
    'app.client/ConnectionRecoveryAction $ {}
      :mode :ensure
      :kind :data
      :doc "|Deterministic action selected from browser and WebSocket lifecycle facts."
      :schema $ :: 'EnumDef
      :code $ quote $ defenum ConnectionRecoveryAction (:none) (:reconnect) (:connect)
    'app.client/*ws-client $ {}
      :mode :ensure
      :kind :data
      :doc "|Current nominal ws-edn client, retained across browser recovery events."
      :schema $ :: 'Ref (:: 'Option 'ws-edn.client/WsClient)
      :code $ quote $ defatom *ws-client $ %none
    'app.client/choose-recovery-action $ {}
      :mode :ensure
      :kind :fn
      :doc "|Choose whether a visible online manual recovery signal should reconnect an existing client or create one."
      :params $ [] 'connected? 'has-client? 'visible? 'online?
      :schema $ :: :fn $ {}
        :args $ [] 'Bool 'Bool 'Bool 'Bool
        :return 'ConnectionRecoveryAction
    'app.client/recover-connection! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Apply typed manual page-touch acceleration to the current browser WebSocket client."
      :params $ []
      :schema $ :: :fn $ {}
        :args $ []
        :return 'Unit
        :features $ #{} :js-ffi
  :edges $ #{}
    :: :call 'app.client/recover-connection! 'app.client/choose-recovery-action
