## ADDED Requirements

### Requirement: Managed sessions expose pending approval requests
The SDK SHALL pause a managed session run when a permission decision returns `ask` and persist a structured pending approval request that the caller can inspect on the session.

#### Scenario: Tool permission ask pauses a managed run
- **WHEN** a managed session encounters a tool permission decision with outcome `ask`
- **THEN** the SDK records a pending approval request containing the run identifier, permission decision, and blocked tool call

#### Scenario: Reloaded session retains the pending approval request
- **WHEN** a caller reloads a managed session whose active run previously paused for approval
- **THEN** the reloaded session exposes the same pending approval request without re-running the model

### Requirement: Callers can resolve a pending approval request
The SDK SHALL let a caller approve or deny the pending approval request on a managed session.

#### Scenario: Caller approves a blocked tool request
- **WHEN** a caller approves a pending tool approval request on a managed session
- **THEN** the SDK resumes the paused run, executes the blocked tool call once, and continues the run under the original run identifier

#### Scenario: Caller denies a blocked delegation request
- **WHEN** a caller denies a pending subagent approval request on a managed session
- **THEN** the SDK clears the pending approval state and completes the paused work without creating the delegated child session
