## ADDED Requirements

### Requirement: SDK supports provider adapters
The SDK SHALL define a provider adapter contract that allows `agent_loop_core` to execute runs against real model backends without embedding provider-specific request or response formats inside `AgentLoop`, including normalized structured content parts and attachment metadata.

#### Scenario: Loop executes through adapter boundary
- **WHEN** a caller configures the SDK with a provider-backed model implementation
- **THEN** `AgentLoop` uses the normalized provider adapter contract rather than provider-specific message, content-part, or tool-call types

#### Scenario: Tool calls and rich parts are normalized before execution
- **WHEN** a provider response requests one or more tool calls and also includes structured content such as reasoning or file references
- **THEN** the adapter surface returns normalized tool call data and normalized message parts that the loop can store and execute without provider-specific translation logic

### Requirement: Provider failures are surfaced predictably
The SDK SHALL surface provider request failures through a consistent error boundary so callers can distinguish provider failures from loop termination and tool execution results.

#### Scenario: Provider request fails before a final response
- **WHEN** the provider adapter cannot complete a model request
- **THEN** the run fails with a provider-specific failure surfaced through the normalized SDK error path

#### Scenario: Tool failures remain distinct from provider failures
- **WHEN** a tool execution fails after a successful provider response
- **THEN** the loop does not report that failure as a provider adapter error

### Requirement: Provider adapters can ship as optional packages
The SDK SHALL support concrete provider integrations being distributed as optional packages outside `agent_loop_core` and `agent_loop` so consumers can install only the providers they use.

#### Scenario: Optional provider package implements the adapter contract
- **WHEN** a provider package depends on the base SDK packages and implements `AgentProvider`
- **THEN** callers can use that provider with `AgentLoop` without requiring the base SDK packages to depend on the provider package

#### Scenario: Base SDK stays provider-agnostic
- **WHEN** the repository adds a new concrete provider integration
- **THEN** provider-specific transport code and dependencies do not have to be added to `agent_loop_core` or `agent_loop` for the integration to work

### Requirement: Provider adapters do not require vendor client libraries
The SDK SHALL allow provider packages to satisfy the adapter contract using direct transport code instead of requiring a provider-specific client library.

#### Scenario: Provider package uses plain HTTP transport
- **WHEN** a provider package communicates with its backend over HTTP
- **THEN** it can satisfy the provider adapter contract without any requirement for a vendor-maintained client SDK

#### Scenario: Normalized behavior does not depend on a client SDK
- **WHEN** a provider package translates backend responses into `AgentResponse`, `ToolCall`, and `MessagePart` values
- **THEN** the normalized runtime behavior remains compatible with the base SDK regardless of whether a vendor client library is present

### Requirement: Provider adapters can stream normalized partial output
The SDK SHALL allow provider packages to emit normalized partial assistant output and related provider-side progress before a final `AgentResponse` is complete.

#### Scenario: Streaming provider emits incremental output
- **WHEN** a provider supports server-side streaming for a model response
- **THEN** the provider can emit normalized partial output through the adapter boundary without requiring `AgentLoop` to understand provider-specific chunk payloads

#### Scenario: Non-streaming provider remains compatible
- **WHEN** a provider only supports terminal request/response behavior
- **THEN** it can continue satisfying the adapter contract without implementing provider-side streaming
