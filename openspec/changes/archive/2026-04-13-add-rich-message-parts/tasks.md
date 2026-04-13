## 1. Core Part Model

- [x] 1.1 Add focused core tests that describe typed message parts, file parts, and text-only compatibility behavior before changing production code
- [x] 1.2 Introduce the minimal message-part type set in `agent_loop_core` and extend transcript-bearing types to carry ordered parts
- [x] 1.3 Add compatibility helpers so existing text-oriented callers can still read final text output without constructing parts directly

## 2. Provider And Loop Integration

- [x] 2.1 Add adapter and loop tests that cover normalized rich parts, tool calls, and provider failure behavior with the new transcript model
- [x] 2.2 Update provider normalization and `AgentResponse` handling so providers can return structured parts and attachment metadata
- [x] 2.3 Update `AgentLoop` to append structured parts to transcript messages and derive terminal text output from the canonical part model

## 3. Events, Sessions, And Public SDK

- [x] 3.1 Add tests covering part-level run events, transcript ordering, and resumed sessions that already contain structured parts
- [x] 3.2 Update run event types and session/result behavior so structured parts flow through streams and resumed conversations without reordering
- [x] 3.3 Update `packages/agent_loop` exports and `AgentLoopSdk` so the richer model is publicly available through additive APIs

## 4. CLI And Verification

- [x] 4.1 Update the CLI demo to render structured text, tool, and file parts clearly enough to exercise the new runtime behavior
- [x] 4.2 Run `dart pub get`
- [x] 4.3 Run `dart format --output=none --set-exit-if-changed .`
- [x] 4.4 Run `dart analyze`
- [x] 4.5 Run `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`
