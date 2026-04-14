## 1. Reliability contract

- [x] 1.1 Add failing core and SDK tests that describe one-shot compatibility, retry success, non-retryable failure, and retry exhaustion behavior.
- [x] 1.2 Add the public reliability types and exception metadata in `packages/agent_loop_core/lib/src/agent_types.dart` and export them through `packages/agent_loop_core/lib/agent_loop_core.dart` and `packages/agent_loop/lib/agent_loop.dart`.
- [x] 1.3 Thread an optional `AgentReliabilityPolicy` through `AgentLoop` and `AgentLoopSdk` without changing existing behavior when no policy is configured.

## 2. Core retry execution

- [x] 2.1 Implement bounded provider retry, timeout, and deterministic backoff handling in `packages/agent_loop_core/lib/src/agent_loop.dart` for both `respond()` and `streamRespond()` paths.
- [x] 2.2 Add retry lifecycle run events, ensure failed attempts do not mutate the transcript, and preserve existing assistant/tool/completion ordering for successful attempts.
- [x] 2.3 Update or add focused tests in `packages/agent_loop_core/test/agent_loop_test.dart` and related runtime tests to cover streaming retry behavior and terminal exhaustion.

## 3. Provider and facade integration

- [x] 3.1 Update `packages/agent_loop_provider_ollama/lib/src/ollama_provider.dart` and its tests to classify transient transport and HTTP failures with the normalized retry metadata.
- [x] 3.2 Expose reliability policy configuration through `packages/agent_loop/lib/src/sdk.dart`, CLI/example entry points, and any affected demos so retry events can be observed end-to-end.

## 4. Verification

- [x] 4.1 Run `dart pub get`, `dart format --output=none --set-exit-if-changed .`, and `dart analyze` from the repo root.
- [x] 4.2 Run the focused Dart tests added for reliability behavior, then run `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"` as the final smoke check.
