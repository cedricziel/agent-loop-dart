## ADDED Requirements

### Requirement: SDK supports provider adapters
The SDK SHALL define a provider adapter contract that allows `agent_loop_core` to execute runs against real model backends without embedding provider-specific request or response formats inside `AgentLoop`.

#### Scenario: Loop executes through adapter boundary
- **WHEN** a caller configures the SDK with a provider-backed model implementation
- **THEN** `AgentLoop` uses the normalized provider adapter contract rather than provider-specific message or tool-call types

#### Scenario: Tool calls are normalized before execution
- **WHEN** a provider response requests one or more tool calls
- **THEN** the adapter surface returns normalized tool call data that the loop can execute with the existing tool registry contract

### Requirement: Provider failures are surfaced predictably
The SDK SHALL surface provider request failures through a consistent error boundary so callers can distinguish provider failures from loop termination and tool execution results.

#### Scenario: Provider request fails before a final response
- **WHEN** the provider adapter cannot complete a model request
- **THEN** the run fails with a provider-specific failure surfaced through the normalized SDK error path

#### Scenario: Tool failures remain distinct from provider failures
- **WHEN** a tool execution fails after a successful provider response
- **THEN** the loop does not report that failure as a provider adapter error
