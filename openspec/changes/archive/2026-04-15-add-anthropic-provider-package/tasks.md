## 1. Package Setup

- [x] 1.1 Add `packages/agent_loop_provider_anthropic` to the workspace and create the package scaffold with public exports.
- [x] 1.2 Update repository documentation to list Anthropic as an optional provider package without changing the base SDK dependency graph.

## 2. Anthropic Provider Implementation

- [x] 2.1 Write failing package tests for authenticated request mapping, normalized non-streaming responses, and provider failure handling.
- [x] 2.2 Implement the Anthropic non-streaming request path for the Messages API with API key and version headers plus a small immutable request options surface.
- [x] 2.3 Implement normalization of terminal Anthropic response content into `TextPart`, `ReasoningPart`, `ToolCall`, and `AgentProviderException` values.
- [x] 2.4 Implement outbound transcript mapping for prior assistant tool calls and tool results into Anthropic-compatible `tool_use` and `tool_result` request content.

## 3. Streaming and Verification

- [x] 3.1 Write failing streaming tests for SSE delta handling, final response assembly, and tool-use JSON accumulation.
- [x] 3.2 Implement Anthropic streaming support through `AgentStreamingProvider` using normalized incremental output events and a final assembled response.
- [x] 3.3 Verify both non-streaming and streaming Anthropic paths pass their focused package tests.
- [x] 3.4 Run repo-level verification with `dart pub get`, `dart format --output=none --set-exit-if-changed .`, `dart analyze`, and the CLI smoke check.
