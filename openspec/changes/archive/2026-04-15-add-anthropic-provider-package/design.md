## Context

The repository already has a normalized provider boundary, a streaming-capable run event model, and one concrete provider package for Ollama. What it still lacks is a hosted provider integration that validates authenticated HTTP transport, Anthropic's server-sent event response flow, and provider-native tool-use payloads while preserving the existing architecture where `AgentLoop` only consumes normalized provider behavior.

This change is narrower than the original Ollama tranche because the optional-package pattern and additive streaming contract already exist. The main design work now is making sure the Anthropic package follows those boundaries cleanly, handles hosted-provider concerns such as authentication and retry-related headers, and maps Anthropic-specific content blocks into the existing runtime model without pushing Anthropic semantics into `agent_loop_core`.

## Goals / Non-Goals

**Goals:**
- Add a separate optional Anthropic provider package without changing the core loop contract.
- Implement Anthropic Messages API transport directly over HTTP, including required authentication headers and a non-streaming request path.
- Support both Anthropic non-streaming responses and streaming events, translating streaming deltas into normalized incremental SDK output and a final assembled `AgentResponse`.
- Normalize Anthropic text, thinking, tool-use, tool-result, and failure payloads into the existing core provider model.
- Keep the provider API small enough that future hosted providers can follow the same package pattern.
- Verify request mapping, streaming assembly, and failure handling with deterministic fake-server tests.

**Non-Goals:**
- Full Anthropic API coverage beyond the Messages API path needed for agent turns.
- Browser portability; this provider only needs to work in the current Dart VM environment.
- Reworking `agent_loop_core` to understand Anthropic-specific request or event shapes.
- Re-exporting optional provider packages from `package:agent_loop`.
- Adding provider-independent features such as new message-part types or new loop orchestration behavior.

## Decisions

### 1. Ship Anthropic as a separate workspace package

The Anthropic integration should live in a new workspace package such as `packages/agent_loop_provider_anthropic`. The base packages remain provider-agnostic and only expose the normalized adapter/runtime types.

Why this over adding Anthropic code to `agent_loop` or `agent_loop_core`:
- It preserves the optional-provider dependency model already established by Ollama.
- It keeps hosted-provider transport and auth concerns out of the core loop.
- It lets consumers opt into Anthropic explicitly.

Alternative considered:
- Add Anthropic directly to `agent_loop`. Rejected because it would couple the base SDK to one hosted provider and blur the provider/package boundary.

### 2. Use direct HTTP transport with explicit Anthropic headers

The provider package should talk to the Anthropic Messages API over plain Dart HTTP and manage the required `x-api-key` and `anthropic-version` headers itself. Request construction should stay visible in the repo rather than being delegated to a vendor SDK.

Why this over using an Anthropic client library:
- It matches the repo's existing provider packaging rule.
- It keeps transport and normalization behavior auditable and testable.
- It avoids coupling the provider package API to an external client library's abstractions.

Alternative considered:
- Depend on a third-party Anthropic SDK. Rejected because the Messages API surface needed here is small enough to implement directly.

### 3. Map Anthropic transcript content into the existing normalized model

The provider should translate Anthropic response content blocks into the runtime's existing types: text blocks become `TextPart`, thinking blocks become `ReasoningPart`, tool-use blocks become `ToolCall`, and request failures become `AgentProviderException`. Prior assistant tool calls and tool results should be encoded back into Anthropic's `tool_use` and `tool_result` content blocks when building outbound requests.

Why this over adding Anthropic-specific content types to core:
- It preserves the provider boundary: Anthropic stays a translation concern.
- It keeps the loop and sessions reusable across providers.
- It reuses the existing rich-part and tool lifecycle model instead of forking it.

Alternative considered:
- Add Anthropic-native block types to `agent_loop_core`. Rejected because it would leak provider-specific semantics into the shared runtime surface.

### 4. Support both terminal and streaming provider paths

Anthropic should support a plain terminal request/response path through `AgentProvider.respond` and a streaming path through `AgentStreamingProvider`. The streaming implementation consumes server-sent events, emits normalized incremental parts for text and thinking deltas, accumulates tool-use JSON deltas until complete, and yields one final `AgentProviderResponseEvent` when the stream reaches a terminal state.

Why this over implementing only one mode:
- It matches Anthropic's API surface instead of forcing callers into streaming-only behavior.
- It keeps non-streaming consumers on the simplest possible provider path.
- It preserves the real-time behavior expected from a hosted provider.
- It validates that the current streaming contract is sufficient for Anthropic's event model.
- It avoids reintroducing provider-specific chunk handling inside `AgentLoop`.

Alternative considered:
- Treat Anthropic as streaming-only or non-streaming-only. Rejected because both modes are part of the provider surface and the adapter should support both.

### 5. Expose a small immutable Anthropic configuration surface

The package should expose a focused constructor/config surface for API key, model, base URL override, Anthropic version, and a small request options object. Raw request maps remain internal.

Why this over exposing arbitrary request JSON:
- It gives consumers a stable Dart API.
- It avoids leaking Anthropic payload details into app code.
- It leaves room for additive request options later without committing to an untyped map interface.

Alternative considered:
- Accept raw request payload fragments from callers. Rejected because it would shift normalization responsibility from the provider package back to SDK users.

### 6. Test with a fake HTTP/SSE server

The provider package should use deterministic tests with a local fake `HttpServer` that can return normal JSON responses, SSE event streams, error payloads, and retry-related headers such as `Retry-After`.

Why this over live API integration tests:
- It keeps CI self-contained and repeatable.
- It allows precise coverage of edge cases like partial tool-use JSON deltas.
- It avoids requiring real Anthropic credentials in automated verification.

Alternative considered:
- Run integration tests against Anthropic directly. Rejected because it would add network and secret-management requirements that the repo does not currently need.

## Risks / Trade-offs

- [Anthropic event payloads may evolve] -> Keep request/response mapping isolated inside the provider package and keep the public config surface narrow.
- [Hosted-provider auth and rate limits are easy to mishandle] -> Map auth and HTTP failures through the normalized provider error model, including retry-related metadata when available.
- [Anthropic tool-use streaming is more complex than plain text streaming] -> Accumulate partial input JSON per content block and only expose normalized `ToolCall` data in the final assembled response.
- [Optional provider packages increase workspace surface area] -> Accept the extra package as the cost of keeping the base SDK provider-agnostic.

## Migration Plan

1. Add the new Anthropic provider package to the workspace.
2. Implement direct HTTP request construction and authenticated response handling for the Messages API inside that package.
3. Implement Anthropic streaming event decoding and final response assembly through the existing provider streaming contract.
4. Add deterministic package tests that cover request mapping, streaming deltas, tool-use normalization, and failure handling.
5. Update README or example documentation to show Anthropic as another optional provider package.

Rollback remains straightforward: remove the optional package and its documentation updates while leaving the existing provider boundary unchanged.

## Open Questions

- Should the first package expose only the low-level `AnthropicProvider`, or also include convenience constructors for environment-based configuration?
- Which Anthropic request options are worth exposing in the first API surface beyond model, max tokens, and basic sampling settings?
- Should the repository add a dedicated Anthropic example binary now, or leave documentation updates sufficient for the first tranche?
