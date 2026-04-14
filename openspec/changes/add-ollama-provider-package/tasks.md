## 1. Package Setup

- [x] 1.1 Add `packages/agent_loop_provider_ollama` to the workspace with its own `pubspec.yaml` depending on `agent_loop_core`
- [x] 1.2 Create the package library entrypoint and public exports for the Ollama provider API
- [x] 1.3 Add any minimal additive shared types or docs in the base packages needed to support optional provider packages and provider-side streaming without introducing an Ollama dependency

## 2. Core Streaming Tests

- [x] 2.1 Add core tests covering additive provider-streaming behavior while preserving compatibility for non-streaming providers
- [x] 2.2 Add core tests covering ordered run events for provider-originated partial output before final completion

## 3. Transport and Normalization Tests

- [x] 3.1 Add package tests that drive the provider against a fake local `HttpServer` for successful Ollama chat responses
- [x] 3.2 Add package tests covering streamed Ollama chunks, final response assembly, and ordered partial-output events
- [x] 3.3 Add package tests covering normalized tool calls and rich message parts produced from Ollama responses
- [x] 3.4 Add package tests covering HTTP failures, streaming errors, error payloads, and provider exception mapping

## 4. Ollama Provider Implementation

- [x] 4.1 Implement the additive core provider-streaming contract and event-path support
- [x] 4.2 Implement the Ollama provider config and constructor surface for base URL, model, and request options
- [x] 4.3 Implement direct HTTP request/response and streaming handling against the Ollama chat API without a third-party client library
- [x] 4.4 Normalize Ollama assistant content, streamed partial output, tool calls, and failures into the core provider and event models

## 5. Repository Wiring

- [x] 5.1 Add a focused example or demo wiring path that shows the Ollama provider being used without making `agent_loop` or `agent_loop_core` depend on it
- [x] 5.2 Update package-level documentation or README content to explain the optional provider-package principle, streaming behavior, and Ollama setup

## 6. Verification

- [x] 6.1 Run focused tests for `packages/agent_loop_core`
- [x] 6.2 Run focused tests for `packages/agent_loop_provider_ollama`
- [x] 6.3 Run `dart pub get`
- [x] 6.4 Run `dart format --output=none --set-exit-if-changed .`
- [x] 6.5 Run `dart analyze`
- [x] 6.6 Run `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`
