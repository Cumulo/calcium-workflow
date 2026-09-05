{}
  :schema-version 1
  :feature 'client-store-state
  :doc "|Keep loading, offline, and ready Store in one nominal client-owned state; unwrap Store only for patching and rendering."
  :roots $ #{} 'app.client/render-app! 'app.client/apply-server-patch!
  :definitions $ {}
    'app.client/ClientState $ {}
      :mode :external
      :kind :data
      :schema $ :: 'EnumDef
    'app.client/render-app! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ []
        :return 'Unit
    'app.client/apply-server-patch! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'Number 'Number (:: 'List 'recollect.schema/change-op)
        :return 'Unit
  :edges $ #{}
    :: :type 'app.client/render-app! 'app.client/ClientState
    :: :type 'app.client/apply-server-patch! 'app.client/ClientState
