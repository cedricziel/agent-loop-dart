## Why

The SDK now has a provider boundary, but it still ships no real provider package for consumers to use and still cannot consume provider-native streaming output. Adding Ollama as the first concrete provider closes that product gap and establishes a packaging principle where providers live in optional packages and talk to their backends over portable HTTP instead of requiring a vendor client library.

## What Changes

- Add a new optional workspace package for an Ollama provider that implements the existing normalized provider contract.
- Define the provider packaging principle explicitly: concrete providers live outside `agent_loop_core` and `agent_loop`, so consumers only depend on the providers they choose to install.
- Implement Ollama transport directly against the Ollama HTTP API instead of depending on a third-party Ollama client library.
- Extend the provider contract and run event model so providers can stream partial assistant output and partial tool-call state before a final response is complete.
- Normalize Ollama chat responses, structured content parts, tool calls, and provider failures into the existing core runtime model.
- Implement Ollama streaming so incremental chunks from the Ollama API surface through the SDK event stream in transcript order.
- Expose the Ollama provider through a small public API that lets callers configure base URL, model, and request options without leaking Ollama-specific payload shapes into `AgentLoop`.
- Update the CLI or example surface enough to prove the package can be wired into a real run without changing the core loop contract.

## Capabilities

### New Capabilities
- `ollama-provider`: Optional package support for running the SDK against a local or remote Ollama server through the normalized provider adapter boundary.

### Modified Capabilities
- `provider-adapters`: Provider integrations can be shipped as optional packages and should not require a provider-specific client library in order to satisfy the adapter contract.
- `run-events`: The event stream should support provider-originated incremental output emitted before the terminal assistant response is complete.

## Impact

- Adds a new workspace package for the Ollama provider, likely `packages/agent_loop_provider_ollama`.
- Affects `packages/agent_loop_core` where the provider contract, shared event model, and any streaming-facing shared types need additive clarification.
- May affect `packages/agent_loop` exports if the public facade should re-export provider-facing base types, but should avoid pulling the Ollama package into the base SDK dependency graph.
- Affects examples or CLI wiring so the repository demonstrates one real provider-backed integration.
- Adds HTTP transport, streaming response normalization, and response assembly code, but avoids any required third-party Ollama client dependency.
