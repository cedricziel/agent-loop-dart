## 1. Provider Foundation

- [x] 1.1 Add core provider adapter types and normalize provider responses in `agent_loop_core`
- [x] 1.2 Update `AgentLoop` to execute through the provider adapter boundary without embedding provider-specific behavior
- [x] 1.3 Add focused tests for normalized tool calls and provider failure handling

## 2. Run Observability

- [x] 2.1 Define structured run event types for assistant activity, tool execution, and completion
- [x] 2.2 Expose an event stream from the core loop and wire it through the public SDK facade
- [x] 2.3 Update the CLI demo to exercise live run events during execution

## 3. Conversation State

- [x] 3.1 Extend the core run API to accept existing transcript or session state for resumed conversations
- [x] 3.2 Return updated conversation state from completed runs while preserving the current one-shot entry point
- [x] 3.3 Add tests covering resumed runs and additive compatibility with the existing `run(prompt: ...)` flow

## 4. Verification

- [x] 4.1 Run `dart pub get`
- [x] 4.2 Run `dart format --output=none --set-exit-if-changed .`
- [x] 4.3 Run `dart analyze`
- [x] 4.4 Run `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`
