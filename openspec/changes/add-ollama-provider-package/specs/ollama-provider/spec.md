## ADDED Requirements

### Requirement: SDK provides an optional Ollama provider package
The SDK SHALL provide an Ollama integration as a separate optional package that implements the normalized provider adapter contract without making the base SDK packages depend on Ollama-specific code.

#### Scenario: Consumer installs Ollama without changing base SDK dependencies
- **WHEN** a caller wants to use Ollama with the SDK
- **THEN** they can add the Ollama provider package explicitly and configure it as an `AgentProvider` without requiring `agent_loop` or `agent_loop_core` to bundle Ollama transport code

#### Scenario: Base SDK remains usable without Ollama
- **WHEN** a caller uses the base SDK packages without installing the Ollama provider package
- **THEN** the core loop and public SDK remain usable without any Ollama-specific dependency requirement

### Requirement: Ollama provider uses direct HTTP transport
The Ollama provider package SHALL communicate with the Ollama server over its HTTP API without requiring a third-party Ollama client library.

#### Scenario: Provider sends a chat request
- **WHEN** the Ollama provider executes a model turn
- **THEN** it constructs and sends the necessary HTTP request to the configured Ollama endpoint and translates the HTTP response into normalized SDK types

#### Scenario: Provider package stays client-library agnostic
- **WHEN** the Ollama provider package is added to an application
- **THEN** the integration does not require a provider-specific client dependency in order to perform model requests

### Requirement: Ollama provider supports streaming responses
The Ollama provider package SHALL support Ollama's streaming response mode and surface incremental assistant output through the normalized SDK streaming path.

#### Scenario: Ollama emits incremental text chunks
- **WHEN** the Ollama server returns a streamed chat response with partial assistant content chunks
- **THEN** the provider emits normalized incremental output events in order before the final assembled assistant response is completed

#### Scenario: Final response is assembled after streaming
- **WHEN** a streamed Ollama response reaches its terminal chunk
- **THEN** the provider produces a final normalized response consistent with the incrementally emitted content

### Requirement: Ollama responses are normalized for the loop
The Ollama provider package SHALL normalize Ollama assistant content, tool calls, and provider failures into the existing `AgentResponse`, `MessagePart`, and provider error model used by `agent_loop_core`.

#### Scenario: Ollama returns assistant text and tool calls
- **WHEN** the Ollama server returns assistant output with one or more tool calls
- **THEN** the provider exposes normalized message parts and normalized tool call data that `AgentLoop` can execute without Ollama-specific translation logic

#### Scenario: Ollama request fails
- **WHEN** the Ollama server returns an error or the HTTP request cannot be completed
- **THEN** the provider surfaces the failure through the normalized SDK provider error boundary rather than leaking transport-specific failure types into the loop
