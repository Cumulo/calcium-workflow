{}
  :schema-version 1
  :feature 'session-option-boundary
  :doc "|Normalize legacy session-map absence into owned SessionView Option fields; retain database/session wire inputs."
  :roots $ #{} 'app.twig.container/twig-container
  :definitions $ {}
    'app.twig.user/twig-user $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'Map
        :return 'app.schema/UserView
    'app.schema/SessionView $ {}
      :mode :external
      :kind :data
      :schema $ :: 'Enum
    'app.twig.container/twig-container $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn $ {}
        :args $ [] 'Map 'Map 'Dynamic 'app.schema/SharedTwig
        :return 'app.schema/Store
  :edges $ #{}
    :: :call 'app.twig.container/twig-container 'app.twig.user/twig-user
    :: :type 'app.twig.container/twig-container 'app.schema/SessionView
