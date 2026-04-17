## 1. Question Contract

- [x] 1.1 Add focused failing tests for the built-in `ask_user` tool definition and its request/answer models.
- [x] 1.2 Introduce public SDK types for pending question requests, suggested options, and question answers.
- [x] 1.3 Export the new interactive-question types through `agent_loop_core` and `agent_loop`.

## 2. Managed Run Pause / Resume

- [x] 2.1 Add failing managed-session tests covering pause persistence when the model calls `ask_user`.
- [x] 2.2 Extend the managed-session pause/resume flow to persist pending question requests and block the run until resolved.
- [x] 2.3 Resume answered questions by recording an `ask_user` tool result in the transcript and continuing the original run.
- [x] 2.4 Support cancelling a pending question request and verify the paused run terminates cleanly.

## 3. Event And Consumer Integration

- [x] 3.1 Add failing tests for question-required and question-resolved lifecycle events.
- [x] 3.2 Update run-event types and emitters so callers can observe pending question requests and their resolution.
- [x] 3.3 Update CLI/example rendering to display structured questions with option descriptions and collect answers or cancellation.

## 4. Verification

- [x] 4.1 Run `dart pub get`, `dart format --output=none --set-exit-if-changed .`, `dart analyze`, and `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`.
