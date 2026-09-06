# Session/User Option projection / 显式缺失值投影

Base: 1be7e3b4098ba37a1182e36c38bf710a7b105b99; calcit-lang/calcit#876.

- SessionView user-id/id/nickname now carry Option. Projection validates present
  values and normalizes legacy nil/missing input without changing database maps.
- SessionView 三个旧 Optional 字段改为 Option，投影处验证有效值，保留原数据库输入。
- A logged-in regression exposed the existing UserView constructor passing bare
  nil into Option fields. Fixed nickname/avatar projection and tested it in JS.
- 已登录测试发现 UserView 构造与 Option schema 不一致，修正并增加 JS 回归。
- Native client 10/10, server-tagged 12/12, server-entry full 21/21;
  generated-JS positive/negative/roundtrip suite;
  unchanged quality baseline; canonical formatting and Vite build pass.
- Browser smoke exposed mixed Enum/Store atom inference erasing the ready render
  branch. Replaced it with Ref<ClientState> (loading/offline/ready Store), and
  corrected validate-server-patch's reversed Result type arguments (error first).
  The typed ready-state regression validates wrapping successful patched Store.
- Browser passed Guest, local signup, home/profile, URL reload with login
  restoration, logout and login. Profile Refresh drops the custom test port;
  restoring the explicit URL reconnects. Full protocol/strict-nil acceptance
  remains pending; see the migration document for exact limitations. No release/version or
  provider change, no baseline weakening, and no merge-completion claim.
