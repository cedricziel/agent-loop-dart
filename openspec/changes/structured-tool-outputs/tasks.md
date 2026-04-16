## 1. Core Tool Output Model

- [x] 1.1 Add focused failing tests in `agent_loop_core` for structured tool outputs on `ToolResult`, transcripts, and custom tool execution.
- [x] 1.2 Introduce the public structured tool output types and update core/public exports for the new API surface.
- [x] 1.3 Update the `AgentTool` contract and `ToolResult` model to carry structured output plus a deterministic text compatibility view.

## 2. Loop And Event Integration

- [x] 2.1 Add failing tests covering tool result events and resumed sessions preserving structured tool outputs.
- [x] 2.2 Update `AgentLoop` and related runtime types so structured tool outputs are recorded in transcript messages and propagated through `AgentRunResult` and session state.
- [x] 2.3 Update run event types and emitters so tool result events expose the same structured tool output stored in the transcript.

## 3. Builtin Tool Migration

- [x] 3.1 Add failing tests for builtin tools proving metadata and deterministic text rendering survive through the shared structured output contract.
- [x] 3.2 Refactor the builtin tool helper/result path to construct the shared structured tool output model for both success and failure cases.
- [x] 3.3 Update each builtin tool implementation to return structured outputs without changing its current text rendering semantics.

## 4. Consumer Updates And Verification

- [x] 4.1 Update CLI/example rendering paths to read structured tool outputs cleanly while preserving current text-first behavior.
- [x] 4.2 Run `dart pub get`, `dart format --output=none --set-exit-if-changed .`, `dart analyze`, and `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`.
