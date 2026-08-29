{}
  :schema-version 1
  :feature 'typed-sync-envelopes
  :doc "|Decode untrusted WebSocket EDN once, then keep nominal client/server message envelopes through synchronization code."
  :roots $ #{} 'app.schema/decode-client-message 'app.schema/decode-server-message
  :definitions $ {}
    'app.schema/MessageDecodeError $ {}
      :mode :ensure
      :kind :data
      :doc "|Why an untrusted WebSocket value could not become a typed message envelope."
      :schema $ :: 'Enum
      :code $ quote
        defenum MessageDecodeError
          :invalid 'String
    'app.schema/ClientMessage $ {}
      :mode :ensure
      :kind :data
      :doc "|Typed messages accepted from a browser connection."
      :schema $ :: 'Enum
      :code $ quote
        defenum ClientMessage
          :sync/active 'Number
          :sync/heartbeat 'Number
          :sync/idle 'Number
          :sync/resume 'Number
          :sync/ack 'Number
          :dispatch 'app.schema/Op
    'app.schema/ServerMessage $ {}
      :mode :ensure
      :kind :data
      :doc "|Typed synchronization and effect messages sent to a browser."
      :schema $ :: 'Enum
      :code $ quote
        defenum ServerMessage
          :snapshot 'Number 'app.schema/Store
          :patch 'Number 'Number $ :: 'List 'recollect.schema/change-op
          :effect/pong
    'app.schema/decode-client-message $ {}
      :mode :ensure
      :kind :fn
      :doc "|Validate one untrusted client value and reconstruct a nominal ClientMessage; direct legacy Op enums remain accepted."
      :params $ [] 'data
      :schema $ :: 'Fn
        {}
          :args $ [] 'Dynamic
          :return $ :: 'Result 'app.schema/MessageDecodeError 'app.schema/ClientMessage
    'app.schema/decode-operation $ {}
      :mode :ensure
      :kind :fn
      :doc "|Reconstruct a nominal application Op from an untrusted or legacy enum value."
      :params $ [] 'data
      :schema $ :: 'Fn
        {}
          :args $ [] 'Dynamic
          :return $ :: 'Result 'app.schema/MessageDecodeError 'app.schema/Op
    'app.schema/decode-server-message $ {}
      :mode :ensure
      :kind :fn
      :doc "|Validate one untrusted server value and reconstruct a nominal ServerMessage."
      :params $ [] 'data
      :schema $ :: 'Fn
        {}
          :args $ [] 'Dynamic
          :return $ :: 'Result 'app.schema/MessageDecodeError 'app.schema/ServerMessage
    'app.schema/invalid-message $ {}
      :mode :ensure
      :kind :fn
      :doc "|Build a typed decode failure while preserving the expected success type."
      :params $ [] 'detail
      :schema $ :: 'Fn
        {}
          :generics $ [] 'T
          :args $ [] 'String
          :return $ :: 'Result 'app.schema/MessageDecodeError 'T
  :edges $ #{}
    :: :call 'app.schema/decode-client-message 'app.schema/invalid-message
    :: :call 'app.schema/decode-client-message 'app.schema/decode-operation
    :: :call 'app.schema/decode-operation 'app.schema/invalid-message
    :: :call 'app.schema/decode-server-message 'app.schema/invalid-message
