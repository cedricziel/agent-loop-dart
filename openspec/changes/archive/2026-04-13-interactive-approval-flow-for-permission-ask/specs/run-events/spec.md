## ADDED Requirements

### Requirement: SDK emits approval lifecycle events for managed sessions
The SDK SHALL emit explicit approval lifecycle events for managed-session runs that pause on permission `ask` outcomes.

#### Scenario: Approval-required event is emitted before the stream pauses
- **WHEN** a managed session run receives a permission decision with outcome `ask`
- **THEN** the SDK emits the permission event and an approval-required event for the same session and run before stopping further run progress

#### Scenario: Approval-resolved event is emitted when caller responds
- **WHEN** a caller approves or denies a pending approval request
- **THEN** the SDK emits an approval-resolved event that records the caller's resolution outcome for the same session and run

### Requirement: Approval events preserve run ordering guarantees
The SDK SHALL keep approval lifecycle events ordered relative to existing tool, delegation, and completion events for the affected run.

#### Scenario: Blocked tool call does not emit tool execution before approval
- **WHEN** a tool call is paused for approval
- **THEN** the SDK emits no tool call or tool result event for that blocked tool until the caller approves it

#### Scenario: Approved request resumes normal event flow
- **WHEN** a caller approves a pending request
- **THEN** subsequent tool, assistant, delegation, and completion events continue after the approval-resolved event under the same run identifier
