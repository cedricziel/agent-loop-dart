## ADDED Requirements

### Requirement: SDK supports named agent profiles
The SDK SHALL allow callers to define and register named agent profiles with prompt, model override, mode, visibility, and execution-limit metadata.

#### Scenario: Caller registers a visible primary agent profile
- **WHEN** a caller registers an agent profile intended for direct use
- **THEN** the SDK stores that profile under a stable identifier with its configured prompt and runtime metadata

#### Scenario: Caller registers a hidden subagent profile
- **WHEN** a caller registers an agent profile marked as hidden or subagent-only
- **THEN** the SDK keeps it available for runtime delegation without requiring it to appear in the default direct-use list

### Requirement: Sessions run under an explicit agent profile
The SDK SHALL identify which agent profile owns a managed session run.

#### Scenario: Caller starts a run with a selected profile
- **WHEN** a caller prompts a managed session under a specific agent profile
- **THEN** the runtime uses that profile's prompt and execution metadata for the run

#### Scenario: Delegated child run uses child profile configuration
- **WHEN** a parent agent delegates work to a subagent profile
- **THEN** the child run uses the delegated profile's configuration instead of reusing the parent profile unchanged
