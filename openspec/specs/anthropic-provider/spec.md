## ADDED Requirements

### Requirement: SDK provides an optional Anthropic provider package
The SDK SHALL provide an Anthropic integration as a separate optional package that implements the normalized provider adapter contract without making the base SDK packages depend on Anthropic-specific code.

#### Scenario: Consumer installs Anthropic without changing base SDK dependencies
- **WHEN** a caller wants to use Anthropic with the SDK
- **THEN** they can add the Anthropic provider package explicitly and configure it as an `AgentProvider` without requiring `agent_loop` or `agent_loop_core` to bundle Anthropic transport code

#### Scenario: Base SDK remains usable without Anthropic
- **WHEN** a caller uses the base SDK packages without installing the Anthropic provider package
- **THEN** the core loop and public SDK remain usable without any Anthropic-specific dependency requirement

### Requirement: Anthropic provider uses direct authenticated HTTP transport
The Anthropic provider package SHALL communicate with Anthropic's Messages API over HTTP, including the required authentication and version headers, without requiring a third-party Anthropic client library.

#### Scenario: Provider sends an authenticated messages request
- **WHEN** the Anthropic provider executes a model turn
- **THEN** it constructs the required HTTP request to the configured Anthropic endpoint with the configured API key and version metadata and translates the HTTP response into normalized SDK types

#### Scenario: Provider supports non-streaming responses
- **WHEN** a caller uses the Anthropic provider through the terminal request/response path
- **THEN** the provider returns a normalized final `AgentResponse` without requiring provider streaming to be enabled

#### Scenario: Provider package stays client-library agnostic
- **WHEN** the Anthropic provider package is added to an application
- **THEN** the integration does not require a provider-specific client dependency in order to perform model requests

### Requirement: Anthropic provider supports streaming responses
The Anthropic provider package SHALL support Anthropic's streaming response mode and surface incremental assistant output through the normalized SDK streaming path.

#### Scenario: Anthropic emits incremental text or thinking deltas
- **WHEN** the Anthropic Messages API returns a streamed response with partial text or thinking content blocks
- **THEN** the provider emits normalized incremental output events in order before the final assembled assistant response is completed

#### Scenario: Final response is assembled after streaming
- **WHEN** a streamed Anthropic response reaches its terminal event
- **THEN** the provider produces a final normalized response consistent with the incrementally emitted content and any completed tool-use payloads

### Requirement: Anthropic responses are normalized for the loop
The Anthropic provider package SHALL normalize Anthropic assistant content, tool-use blocks, tool-result payloads, and provider failures into the existing `AgentResponse`, `MessagePart`, `ToolCall`, and provider error model used by `agent_loop_core`.

#### Scenario: Anthropic returns thinking and tool use
- **WHEN** the Anthropic Messages API returns assistant output with thinking content and one or more tool-use blocks
- **THEN** the provider exposes normalized reasoning parts and normalized tool call data that `AgentLoop` can store and execute without Anthropic-specific translation logic

#### Scenario: Prior tool results are sent back to Anthropic
- **WHEN** the provider builds a follow-up Anthropic request after a tool has completed in the loop transcript
- **THEN** it encodes the prior assistant tool call and tool result into Anthropic-compatible request content so the model can continue the conversation correctly

#### Scenario: Anthropic request fails
- **WHEN** the Anthropic API returns an error or the HTTP request cannot be completed
- **THEN** the provider surfaces the failure through the normalized SDK provider error boundary rather than leaking transport-specific failure types into the loop
