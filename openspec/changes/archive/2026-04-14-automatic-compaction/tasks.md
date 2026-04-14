## 1. Session Policy Model

- [x] 1.1 Add failing core tests for managed-session automatic compaction thresholds, safe-boundary guards, and persisted policy reload behavior
- [x] 1.2 Add serializable automatic compaction policy types and runtime summarizer resolution contracts to `agent_loop_core`
- [x] 1.3 Export the new automatic compaction policy APIs through `agent_loop_core` and `agent_loop`

## 2. Managed Session Automatic Compaction

- [x] 2.1 Add failing tests for triggering automatic compaction after eligible managed-session runs while preserving explicit compaction behavior
- [x] 2.2 Route post-run managed-session persistence through the existing compaction path when automatic compaction policy conditions are met
- [x] 2.3 Reject or defer automatic compaction while approval is pending or a run has not yet reached a safe boundary

## 3. Persistence And Branching

- [x] 3.1 Add failing tests for saving, loading, and branching sessions that carry automatic compaction policy metadata
- [x] 3.2 Update managed-session storage and branch-copy flows to persist automatic compaction policy consistently with existing compaction metadata

## 4. Events And SDK Surface

- [x] 4.1 Add failing tests for automatic compaction lifecycle reporting on managed-session event streams
- [x] 4.2 Implement automatic compaction lifecycle events and surface them through the public SDK managed-session APIs
- [x] 4.3 Add a minimal CLI or example path that demonstrates configuring and observing automatic compaction on a long-lived session

## 5. Verification

- [x] 5.1 Run `dart pub get`
- [x] 5.2 Run `dart format --output=none --set-exit-if-changed .`
- [x] 5.3 Run `dart analyze`
- [x] 5.4 Run `dart test`
- [x] 5.5 Run `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`
