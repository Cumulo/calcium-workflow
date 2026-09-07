{}
  :schema-version 1
  :feature 'typed-database-workflow
  :doc "|Keep nominal database values from persistence decoding through domain updates and client projections, while accepting legacy bare-map storage at one named boundary."
  :roots $ #{} 'app.schema/database 'app.schema/decode-database 'app.server/read-persisted-database 'app.server/dispatch-domain! 'app.server/persist-db! 'app.server/reel-db 'app.server/reel-record-count 'app.server/get-shared-twig 'app.updater/updater 'app.twig.container/twig-shared 'app.twig.container/twig-container
  :definitions $ {}
    'app.schema/Message $ {}
      :mode :ensure
      :kind :data
      :doc "|A persisted session message."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct Message (:id 'String) (:text 'String)
    'app.schema/Router $ {}
      :mode :ensure
      :kind :data
      :doc "|The domain route stored for one session. Route-specific view data is projected separately."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct Router (:name 'Tag)
    'app.schema/Session $ {}
      :mode :ensure
      :kind :data
      :doc "|A connected session in the nominal database."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct Session
          :user-id $ :: 'Option 'String
          :id 'Number
          :nickname $ :: 'Option 'String
          :router $ quote app.schema/Router
          :messages $ :: 'Map 'String 'app.schema/Message
    'app.schema/User $ {}
      :mode :ensure
      :kind :data
      :doc "|A persisted application user."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct User (:name 'String) (:id 'String)
          :nickname $ :: 'Option 'String
          :avatar $ :: 'Option 'String
          :password 'String
    'app.schema/Db $ {}
      :mode :ensure
      :kind :data
      :doc "|The nominal application database used by reducers and projections."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct Db
          :sessions $ :: 'Map 'Number 'app.schema/Session
          :users $ :: 'Map 'String 'app.schema/User
    'app.schema/RemoveMessage $ {}
      :mode :ensure
      :kind :data
      :doc "|Concrete payload for removing one session message."
      :schema $ :: 'StructDef
      :code $ quote
        defstruct RemoveMessage (:id 'String)
    'app.schema/DomainOp $ {}
      :mode :ensure
      :kind :data
      :doc "|Pure business operations accepted by the database reducer; local and server effects stay outside this enum."
      :schema $ :: 'EnumDef
      :code $ quote
        defenum DomainOp
          :session/connect
          :session/disconnect
          :session/remove-message 'app.schema/RemoveMessage
          :user/log-in 'String 'String
          :user/sign-up 'String 'String
          :user/log-out
          :router/change 'app.schema/Router
    'app.schema/DatabaseDecodeError $ {}
      :mode :ensure
      :kind :data
      :doc "|A path-aware failure produced while decoding untrusted or legacy persisted database data."
      :schema $ :: 'EnumDef
      :code $ quote
        defenum DatabaseDecodeError
          :invalid 'String 'String
    'app.schema/database $ {}
      :mode :external
      :kind :data
      :schema $ :: 'app.schema/Db
    'app.schema/decode-database $ {}
      :mode :ensure
      :kind :fn
      :doc "|Deeply validate a wire or legacy bare-map database and reconstruct nominal Db, Session, User, Router, and Message values."
      :params $ [] 'data
      :schema $ :: 'Fn
        {}
          :generics $ [] 'T
          :args $ [] 'T
          :return $ :: 'Result 'app.schema/Db 'app.schema/DatabaseDecodeError
    'app.schema/decode-router $ {}
      :mode :ensure
      :kind :fn
      :doc "|Decode and validate one stored route."
      :params $ [] 'data 'path
      :schema $ :: 'Fn
        {}
          :generics $ [] 'T
          :args $ [] 'T 'String
          :return $ :: 'Result 'app.schema/Router 'app.schema/DatabaseDecodeError
    'app.schema/decode-message $ {}
      :mode :ensure
      :kind :fn
      :doc "|Decode and validate one stored message."
      :params $ [] 'data 'path
      :schema $ :: 'Fn
        {}
          :generics $ [] 'T
          :args $ [] 'T 'String
          :return $ :: 'Result 'app.schema/Message 'app.schema/DatabaseDecodeError
    'app.schema/decode-session $ {}
      :mode :ensure
      :kind :fn
      :doc "|Decode and deeply validate one stored session."
      :params $ [] 'data 'path
      :schema $ :: 'Fn
        {}
          :generics $ [] 'T
          :args $ [] 'T 'String
          :return $ :: 'Result 'app.schema/Session 'app.schema/DatabaseDecodeError
    'app.schema/decode-user $ {}
      :mode :ensure
      :kind :fn
      :doc "|Decode and validate one stored user."
      :params $ [] 'data 'path
      :schema $ :: 'Fn
        {}
          :generics $ [] 'T
          :args $ [] 'T 'String
          :return $ :: 'Result 'app.schema/User 'app.schema/DatabaseDecodeError
    'app.schema/decode-messages $ {}
      :mode :ensure
      :kind :fn
      :doc "|Decode a keyed message collection and validate every nested value."
      :params $ [] 'data 'path
      :schema $ :: 'Fn
        {}
          :generics $ [] 'T
          :args $ [] 'T 'String
          :return $ :: 'Result (:: 'Map 'String 'app.schema/Message) 'app.schema/DatabaseDecodeError
    'app.schema/decode-sessions $ {}
      :mode :ensure
      :kind :fn
      :doc "|Decode a keyed session collection and validate every nested value."
      :params $ [] 'data 'path
      :schema $ :: 'Fn
        {}
          :generics $ [] 'T
          :args $ [] 'T 'String
          :return $ :: 'Result (:: 'Map 'Number 'app.schema/Session) 'app.schema/DatabaseDecodeError
    'app.schema/decode-users $ {}
      :mode :ensure
      :kind :fn
      :doc "|Decode a keyed user collection and validate every nested value."
      :params $ [] 'data 'path
      :schema $ :: 'Fn
        {}
          :generics $ [] 'T
          :args $ [] 'T 'String
          :return $ :: 'Result (:: 'Map 'String 'app.schema/User) 'app.schema/DatabaseDecodeError
    'app.server/read-persisted-database $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'String
          :return $ :: 'Result 'app.schema/Db 'app.schema/DatabaseDecodeError
    'app.server/reel-db $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'cumulo-reel.core/ReelState
          :return 'app.schema/Db
    'app.server/reel-record-count $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'cumulo-reel.core/ReelState
          :return 'Number
    'app.server/get-shared-twig $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'cumulo-reel.core/ReelState 'Number
          :return 'app.schema/SharedTwig
    'app.server/persist-db! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ []
          :return 'Unit
    'app.server/dispatch-domain! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'app.schema/DomainOp 'Number 'String 'Number
          :return 'Unit
    'app.updater/updater $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'app.schema/Db 'app.schema/DomainOp 'Number 'String 'Number
          :return 'app.schema/Db
    'app.twig.container/twig-shared $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'app.schema/Db 'Number
          :return 'app.schema/SharedTwig
    'app.twig.container/twig-container $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'app.schema/Db 'app.schema/Session 'app.schema/SharedTwig
          :return 'app.schema/Store
  :edges $ #{}
    :: :call 'app.schema/decode-database 'app.schema/Db
    :: :call 'app.schema/decode-database 'app.schema/decode-sessions
    :: :call 'app.schema/decode-database 'app.schema/decode-users
    :: :call 'app.schema/decode-session 'app.schema/decode-router
    :: :call 'app.schema/decode-session 'app.schema/decode-messages
    :: :call 'app.schema/decode-sessions 'app.schema/decode-session
    :: :call 'app.schema/decode-users 'app.schema/decode-user
    :: :call 'app.server/read-persisted-database 'app.schema/decode-database
    :: :type 'app.server/reel-db 'app.schema/Db
    :: :call 'app.server/get-shared-twig 'app.server/reel-record-count
    :: :call 'app.server/get-shared-twig 'app.server/reel-db
    :: :call 'app.server/get-shared-twig 'app.twig.container/twig-shared
    :: :call 'app.server/persist-db! 'app.server/reel-db
    :: :call 'app.server/dispatch-domain! 'app.updater/updater
    :: :type 'app.updater/updater 'app.schema/DomainOp
    :: :type 'app.updater/updater 'app.schema/Db
    :: :type 'app.twig.container/twig-shared 'app.schema/Db
    :: :type 'app.twig.container/twig-container 'app.schema/Db
    :: :type 'app.twig.container/twig-container 'app.schema/Session
