## 1. Session Model And Specs Alignment

- [x] 1.1 Add failing core tests for explicit compaction eligibility, retained-suffix validation, and summary-backed resume behavior on managed sessions
- [x] 1.2 Add compaction metadata types and summarizer boundary to `agent_loop_core` session/runtime models
- [x] 1.3 Extend public exports so new compaction types are available through `agent_loop` and `agent_loop_core`

## 2. Managed Session Compaction

- [x] 2.1 Add failing tests for compacting a managed session, persisting the compacted state, and reloading it from the session store
- [x] 2.2 Implement managed-session compaction APIs and guards, including rejection when a session cannot preserve the required recent suffix
- [x] 2.3 Materialize compacted provider-facing context from the stored summary plus retained raw transcript before follow-up runs

## 3. Branching And Persistence

- [x] 3.1 Add failing tests for branching a compacted session and preserving compaction metadata on the new branch
- [x] 3.2 Update session branching and storage flows so compacted metadata is copied, saved, and restored consistently

## 4. SDK And Examples

- [x] 4.1 Add failing public API tests for invoking compaction through `AgentLoopSdk` managed sessions
- [x] 4.2 Expose the compaction flow through the SDK surface and add a minimal CLI or example path that exercises explicit session compaction

## 5. Verification

- [x] 5.1 Run `dart pub get`
- [x] 5.2 Run `dart format --output=none --set-exit-if-changed .`
- [x] 5.3 Run `dart analyze`
- [x] 5.4 Run `dart test`
- [x] 5.5 Run `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`
