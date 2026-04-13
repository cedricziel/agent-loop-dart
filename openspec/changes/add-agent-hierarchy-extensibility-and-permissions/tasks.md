## 1. Agent Profiles

- [x] 1.1 Add failing tests for registering named agent profiles and selecting a profile for a managed session run
- [x] 1.2 Implement immutable agent profile definitions, registration APIs, and public exports
- [x] 1.3 Wire managed session runs to use profile prompt/model/limit metadata

## 2. Permission Policies

- [x] 2.1 Add failing tests for allow, ask, and deny outcomes on tool calls and subagent delegation
- [x] 2.2 Implement declarative per-profile permission policy evaluation and structured permission errors/results
- [x] 2.3 Extend lifecycle events to surface permission decisions without fabricating transcript activity

## 3. Subagent Hierarchy

- [x] 3.1 Add failing tests for parent-child delegation, child session creation, and child-session lookup from a parent
- [x] 3.2 Implement tree-structured parent-child delegation on top of managed sessions
- [x] 3.3 Extend session metadata and persistence so child sessions retain parent and delegating-agent lineage

## 4. Extensibility Hooks

- [x] 4.1 Add failing tests for runtime hooks around permission evaluation and delegation lifecycle points
- [x] 4.2 Implement registries/interfaces for custom agent definitions, permission evaluators, and runtime hooks
- [x] 4.3 Ensure hooks observe runtime decisions without bypassing core permission or session guarantees

## 5. Run Control And Events

- [x] 5.1 Add failing tests for parent and child session run-control behavior, including cancellation semantics across delegation boundaries
- [x] 5.2 Extend run-control behavior so parent and child sessions are separate concurrency scopes with explicit cancellation outcomes
- [x] 5.3 Extend run events with agent selection, delegation boundaries, child run metadata, and terminal cancellation events

## 6. SDK And CLI

- [x] 6.1 Add failing public API tests for configuring agents, invoking subagents, and using permission-aware managed sessions through `AgentLoopSdk`
- [x] 6.2 Expose the new agent-runtime APIs from `packages/agent_loop` and `packages/agent_loop_core`
- [x] 6.3 Update the CLI demo to exercise named agents, subagent delegation, and permission-aware behavior

## 7. Verification

- [x] 7.1 Run `dart pub get`
- [x] 7.2 Run `dart format --output=none --set-exit-if-changed .`
- [x] 7.3 Run `dart analyze`
- [x] 7.4 Run `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`
