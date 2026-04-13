## 1. Core Session Model

- [ ] 1.1 Add failing core tests for managed session creation, reload, and transcript-backed resume behavior
- [ ] 1.2 Introduce managed session identifiers, branch metadata, and a minimal session store interface with a default in-memory implementation
- [ ] 1.3 Implement branch-by-copy managed session creation and persistence wiring in `agent_loop_core`

## 2. Run Control And Events

- [ ] 2.1 Add failing tests for single-active-run enforcement and managed session cancellation behavior
- [ ] 2.2 Implement managed-session run tracking, per-session run identifiers, and structured concurrency errors
- [ ] 2.3 Extend run events to include session/run metadata plus terminal cancellation events without breaking transcript ordering

## 3. Public SDK And CLI

- [ ] 3.1 Add failing public API tests for creating, loading, branching, prompting, streaming, and aborting managed sessions through `AgentLoopSdk`
- [ ] 3.2 Expose the managed session facade and any new public types from `packages/agent_loop` and `packages/agent_loop_core`
- [ ] 3.3 Update the CLI demo to exercise managed session creation/resume and cancellation using the new SDK surface

## 4. Verification

- [ ] 4.1 Run `dart pub get`
- [ ] 4.2 Run `dart format --output=none --set-exit-if-changed .`
- [ ] 4.3 Run `dart analyze`
- [ ] 4.4 Run `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`
