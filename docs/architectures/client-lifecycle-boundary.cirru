{}
  :schema-version 1
  :feature 'client-lifecycle-boundary
  :doc "|ws-edn exclusively owns transport reconnect, backoff, visibility/online recovery, and heartbeat deadlines. Calcium owns one cleanup-backed application activity watcher for visible/hidden status and revision heartbeats."
  :roots $ #{} 'app.client/install-activity-lifecycle! 'app.client/cleanup-activity-lifecycle!
  :definitions $ {}
    'app.client/*activity-cleanup $ {}
      :mode :ensure
      :kind :data
      :doc "|Cleanup capability for Calcium application-level browser activity signals."
      :schema $ :: 'Ref (:: 'Option 'Fn)
      :code $ quote $ defatom *activity-cleanup $ %none
    'app.client/cleanup-activity-lifecycle! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Run and clear the current application activity cleanup capability."
      :params $ []
      :schema $ :: 'Fn $ {} (:return 'Unit)
        :args $ []
    'app.client/install-activity-lifecycle! $ {}
      :mode :ensure
      :kind :fn
      :doc "|Install one cleanup-backed application activity watcher without duplicating ws-edn reconnect ownership."
      :params $ []
      :schema $ :: 'Fn $ {} (:return 'Unit)
        :args $ []
        :features $ #{} :js-ffi
    'app.client/send-activity! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {} (:return 'Unit)
        :args $ []
    'app.client/main! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {} (:return 'Dynamic)
        :args $ []
        :features $ #{} :js-ffi
    'app.client/reload! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {} (:return 'Unit)
        :args $ []
  :edges $ #{}
    :: :call 'app.client/install-activity-lifecycle! 'app.client/cleanup-activity-lifecycle!
    :: :call 'app.client/install-activity-lifecycle! 'app.client/send-activity!
    :: :call 'app.client/main! 'app.client/install-activity-lifecycle!
    :: :call 'app.client/reload! 'app.client/install-activity-lifecycle!
