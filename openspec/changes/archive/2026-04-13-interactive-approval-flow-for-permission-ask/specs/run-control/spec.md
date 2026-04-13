## ADDED Requirements

### Requirement: Managed sessions reserve paused approval runs
The SDK SHALL treat a managed session run that is waiting for approval as an active run for concurrency and control purposes until the caller resolves it.

#### Scenario: Caller starts another prompt while approval is pending
- **WHEN** a caller attempts to start a new managed session run while the session has a pending approval request
- **THEN** the SDK rejects the new prompt instead of interleaving it with the paused run

#### Scenario: Approval resolution releases the run slot
- **WHEN** a caller resolves the pending approval request by approving or denying it
- **THEN** the SDK releases the paused run slot after the resumed or terminated work reaches its next terminal state

### Requirement: Managed sessions can resume paused approval work
The SDK SHALL allow a caller to continue a paused managed-session run after approving its pending request.

#### Scenario: Approved paused run completes normally
- **WHEN** a caller approves a pending request whose resumed work reaches a final assistant response
- **THEN** the SDK returns the completed run result with the resumed transcript updates included

#### Scenario: Denied paused run does not execute blocked work
- **WHEN** a caller denies a pending request
- **THEN** the SDK does not execute the blocked tool call or delegation request before the paused run is terminated
