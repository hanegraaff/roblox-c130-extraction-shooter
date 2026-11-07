# Client engine suites

Plan 01 adds a client-side runner. Subsequent suites validate role-specific input, thermal occlusion, camera/zoom, UI view state, stale-update handling and cleanup. Use separate real client contexts for multiplayer claims; ordinary server assertions do not replace these checks.
