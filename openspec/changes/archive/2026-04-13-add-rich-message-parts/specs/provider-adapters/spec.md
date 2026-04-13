## MODIFIED Requirements

### Requirement: SDK supports provider adapters
The SDK SHALL define a provider adapter contract that allows `agent_loop_core` to execute runs against real model backends without embedding provider-specific request or response formats inside `AgentLoop`, including normalized structured content parts and attachment metadata.

#### Scenario: Loop executes through adapter boundary
- **WHEN** a caller configures the SDK with a provider-backed model implementation
- **THEN** `AgentLoop` uses the normalized provider adapter contract rather than provider-specific message, content-part, or tool-call types

#### Scenario: Tool calls and rich parts are normalized before execution
- **WHEN** a provider response requests one or more tool calls and also includes structured content such as reasoning or file references
- **THEN** the adapter surface returns normalized tool call data and normalized message parts that the loop can store and execute without provider-specific translation logic
