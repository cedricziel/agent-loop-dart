## Context

The repository has already introduced a normalized provider boundary in `agent_loop_core`, but it still has no concrete provider package that uses a real backend and no provider-side streaming contract. The immediate goal is to add Ollama as the first real provider while preserving the existing architecture: `AgentLoop` should continue depending only on normalized provider behavior, and concrete provider concerns should stay outside the core/runtime packages.

This change is intentionally broader than one provider implementation because it also establishes the packaging rule for future providers. If the first provider is added directly to `agent_loop` or depends on a vendor-specific client package, the repo will bake in coupling that later providers will have to undo.

## Goals / Non-Goals

**Goals:**
- Add a first concrete provider package for Ollama without changing the core loop contract.
- Establish that provider integrations ship as optional packages outside `agent_loop_core` and `agent_loop`.
- Implement Ollama transport directly over its HTTP API so the provider package does not require a third-party Ollama client library.
- Add an additive provider-streaming path so providers can emit partial assistant output through the existing event stream before a terminal response is assembled.
- Normalize Ollama responses, tool calls, rich message parts, and failures into the existing core provider model.
- Use Ollama as the first concrete streaming provider implementation.
- Keep the implementation small enough that future providers can follow the same package pattern.

**Non-Goals:**
- Full parity with every Ollama API surface such as embeddings or model management.
- Browser portability; this provider only needs to work in the current Dart VM and CLI environment.
- Changing the public `AgentLoop` orchestration model to accommodate Ollama-specific request or response types.
- Re-exporting all provider packages from `package:agent_loop` and making the base SDK depend on optional providers.

## Decisions

### 1. Ship Ollama as a separate workspace package

The Ollama integration should live in a new package such as `packages/agent_loop_provider_ollama`, with its own `pubspec.yaml` and dependencies. The base packages should remain provider-agnostic.

Why this over placing Ollama code in `agent_loop` or `agent_loop_core`:
- It keeps the core/runtime dependency graph small.
- It lets consumers choose providers explicitly.
- It creates the pattern future providers can copy without revisiting package boundaries.

Alternative considered:
- Add Ollama directly to `agent_loop`. Rejected because it would make the base SDK carry provider-specific transport and dependency concerns.

### 2. Use direct HTTP transport, not a third-party Ollama client

The provider package should call the Ollama HTTP API directly using the standard Dart runtime libraries. The package may use `dart:convert` and `dart:io` for JSON and HTTP transport, but it should not require a dedicated Ollama client dependency.

Why this over using a client package:
- It preserves portability across environments that can run plain Dart HTTP code.
- It avoids coupling the provider API to a third-party library's release cycle and payload model.
- It keeps normalization logic visible in the repo instead of hidden behind another abstraction layer.

Alternative considered:
- Depend on a third-party Ollama SDK. Rejected because it adds an unnecessary portability and maintenance dependency for a relatively small REST surface.

### 3. Keep the core provider contract additive and normalized

The existing `AgentProvider.respond` contract is still the right terminal-response boundary, but it needs an additive streaming companion rather than replacement. The Ollama package should adapt Ollama payloads into normalized streamed events plus a final assembled `AgentResponse` without teaching `AgentLoop` anything about Ollama.

Why this over introducing an Ollama-specific core abstraction:
- It validates the current provider boundary instead of bypassing it.
- It keeps every provider implementation accountable to one normalized runtime model.
- It limits core churn to additive configuration or shared helper types only when truly needed.

Alternative considered:
- Extend `AgentProvider` with Ollama-specific request fields. Rejected because it would weaken the generic provider boundary.

### 4. Add provider streaming as a separate optional interface

Provider streaming should be introduced as an additive interface alongside the current request/response provider contract. `AgentLoop` can detect whether a provider supports streaming and, when it does, consume normalized provider events that map onto the existing run event model before emitting the final completion event.

Why this over replacing `respond()` entirely:
- It preserves compatibility for existing providers and tests.
- It lets non-streaming providers continue using the simpler contract.
- It allows streaming to land incrementally without forcing every provider to implement it immediately.

Alternative considered:
- Replace the provider contract with streaming-only semantics. Rejected because it would create unnecessary churn for a capability that should be additive.

### 5. Stream Ollama chunks as normalized partial text events

The Ollama provider should consume the streaming HTTP response and translate each chunk into normalized partial assistant output that the loop can expose through `AgentMessagePartEvent` ordering semantics. The provider package should also assemble those chunks into the final `AgentResponse` so terminal behavior remains consistent with non-streaming providers.

Why this over buffering the full streamed response and only emitting the final message:
- It gives callers the real-time behavior they expect from a streaming provider.
- It keeps provider streaming aligned with the existing event-stream investment.
- It proves the additive streaming contract with a concrete backend.

Alternative considered:
- Ignore partial chunks and emit only the final response. Rejected because it would add transport complexity without delivering the main product benefit.

### 6. Model Ollama configuration as a small immutable config surface

The provider package should expose a focused constructor or config object for base URL, model name, optional system/default options, and request tuning that maps cleanly onto Ollama chat requests. Raw request maps should remain internal.

Why this over exposing raw JSON payload configuration:
- It gives callers a stable Dart API.
- It avoids leaking transport payload details into application code.
- It keeps room for additive options later without locking users into untyped request maps.

Alternative considered:
- Accept arbitrary request JSON from callers. Rejected because it shifts normalization responsibility back onto SDK consumers.

### 7. Test against a fake HTTP server, not a real Ollama daemon

The provider package should use focused tests backed by a local fake `HttpServer` so request mapping, streaming chunk normalization, response assembly, and error handling are deterministic in CI. The CLI/example verification can remain lightweight and should not require Ollama to be installed during automated checks.

Why this over daemon-dependent tests:
- It keeps CI reliable and self-contained.
- It allows full control over success and error payloads.
- It exercises the transport boundary without introducing environment setup requirements.

Alternative considered:
- Run integration tests against a live Ollama instance. Rejected for the first tranche because the repo does not currently provision external services in CI.

## Risks / Trade-offs

- [Ollama payloads may evolve] -> Keep the initial API surface small and isolate request, streaming-chunk, and response mapping inside the provider package.
- [Using `dart:io` limits browser usage] -> Document the package as VM-focused and keep the transport boundary internal so a future web-capable variant can be added separately.
- [Optional package boundaries may make examples slightly more verbose] -> Accept explicit provider imports as the cost of a cleaner base SDK dependency graph.
- [Core types may still need small additive changes] -> Keep those changes minimal and shared-provider oriented, not Ollama-specific.
- [Streaming semantics may be awkward for non-streaming providers] -> Make streaming support additive and optional at the provider interface level.

## Migration Plan

1. Add the new provider package to the workspace.
2. Add additive core streaming interfaces and event-path support while keeping non-streaming providers working.
3. Implement the Ollama transport, streaming chunk handling, and response normalization inside that package.
4. Make only additive core adjustments if the provider package needs shared config or failure helpers.
5. Add package tests using a fake HTTP server.
6. Update example or CLI wiring to demonstrate the provider without making the base packages depend on it.

Rollback is straightforward: remove the optional provider package and any additive core clarifications, while leaving the existing provider boundary intact.

## Open Questions

- Should the provider package expose only a low-level `OllamaProvider`, or also offer convenience constructors for common localhost defaults?
- Does `package:agent_loop` need to re-export any additional provider-facing base types to make optional provider packages more ergonomic?
