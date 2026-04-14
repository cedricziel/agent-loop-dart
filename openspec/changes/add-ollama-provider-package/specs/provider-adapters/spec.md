## ADDED Requirements

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
