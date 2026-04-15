## Why

The SDK now has one real provider package for Ollama, but it still lacks a hosted provider integration that exercises authenticated HTTP transport, Anthropic-style streaming semantics, and provider-native tool-use payloads. Adding an Anthropic adapter closes that product gap and proves that the normalized runtime can support both local and hosted providers without changing the core loop model.

## What Changes

- Add a new optional workspace package for an Anthropic provider that implements the existing normalized provider adapter contract.
- Implement Anthropic Messages API transport directly over HTTP, including API key authentication and configurable base URL, model, request options, and a non-streaming request path.
- Support both Anthropic non-streaming and streaming response modes, translating provider-native server-sent events into normalized incremental SDK output before the final streaming response completes.
- Normalize Anthropic text, thinking, tool-use, and tool-result payloads into `AgentResponse`, `MessagePart`, `ToolCall`, and `AgentProviderException` values understood by `agent_loop_core`.
- Add focused package tests using a fake HTTP server so hosted-provider request mapping, streaming assembly, and failure normalization remain deterministic in CI.
- Update repository documentation to list Anthropic as another optional provider package alongside Ollama.

## Capabilities

### New Capabilities
- `anthropic-provider`: Optional package support for running the SDK against Anthropic's Messages API through the normalized provider adapter boundary.

### Modified Capabilities

None.

## Impact

- Adds a new workspace package, likely `packages/agent_loop_provider_anthropic`.
- Affects provider-facing integration examples and package documentation, but keeps `agent_loop_core` and `agent_loop` provider-agnostic.
- Introduces authenticated HTTP transport, SSE streaming response handling, and Anthropic-specific normalization logic in the new optional package only.
- Adds hosted-provider test coverage that complements the existing local Ollama package coverage.
