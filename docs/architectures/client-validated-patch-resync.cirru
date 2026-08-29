{}
  :schema-version 1
  :feature 'client-validated-patch-resync
  :doc "|Validate revisioned server patches atomically and turn any structural failure into a deterministic full-resync request."
  :roots $ #{} 'app.client/validate-server-patch 'app.client/apply-server-patch!
  :definitions $ {}
    'app.client/ClientPatchError $ {}
      :mode :ensure
      :kind :data
      :doc "|Client-side reason for rejecting a revisioned patch before requesting a full snapshot."
      :schema $ :: 'EnumDef
      :code $ quote
        defenum ClientPatchError
          :revision-mismatch 'Number 'Number
          :invalid-patch 'recollect.patch/PatchError
    'app.client/validate-server-patch $ {}
      :mode :ensure
      :kind :fn
      :doc "|Validate base revision and apply one patch batch without mutating client state."
      :params $ [] 'store 'local-revision 'base-revision 'changes
      :schema $ :: 'Fn
        {}
          :generics $ [] 'T
          :args $ [] 'T 'Number 'Number (:: 'List 'recollect.schema/change-op)
          :return $ :: 'Result 'T 'ClientPatchError
    'app.client/apply-server-patch! $ {}
      :mode :external
      :kind :fn
      :schema $ :: 'Fn
        {}
          :args $ [] 'Number 'Number (:: 'List 'recollect.schema/change-op)
          :return 'Unit
  :edges $ #{}
    :: :call 'app.client/apply-server-patch! 'app.client/validate-server-patch
