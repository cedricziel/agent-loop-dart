## ADDED Requirements

### Requirement: SDK exposes registries for custom agent capabilities
The SDK SHALL allow callers to register custom agent profiles, permission evaluators, and runtime hooks through explicit extension points.

#### Scenario: Caller registers a custom runtime hook
- **WHEN** a caller installs a supported runtime hook into the agent runtime
- **THEN** the hook is invoked at its documented lifecycle point without requiring changes to `AgentLoop`

#### Scenario: Caller registers custom agent definitions programmatically
- **WHEN** a caller supplies agent profile definitions through the SDK extensibility surface
- **THEN** those definitions are available for direct runs and permitted delegation within the same runtime

### Requirement: Hook execution does not bypass core runtime policies
The SDK SHALL preserve agent permission and session lifecycle guarantees even when hooks or custom agent definitions are installed.

#### Scenario: Hook observes delegation without bypassing policy
- **WHEN** a hook runs around a delegation attempt
- **THEN** the runtime still evaluates the active permission policy before creating the child session

#### Scenario: Hook observes permission decisions
- **WHEN** the runtime resolves a permission outcome for a tool or subagent request
- **THEN** registered hooks can observe that outcome without mutating the finalized decision after enforcement
