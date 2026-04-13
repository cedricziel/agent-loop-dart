## ADDED Requirements

### Requirement: SDK emits structured run lifecycle events
The SDK SHALL expose structured run lifecycle events so consumers can observe managed-session and stateless loop progress before a final `AgentRunResult` is available, including run start, part-level assistant updates, tool state, cancellation, and completion metadata.

#### Scenario: Consumer observes managed session run start and completion
- **WHEN** a managed session starts a run and later reaches a terminal completion state
- **THEN** the SDK emits ordered lifecycle events that identify the owning session, the active run, and the resulting transcript updates

#### Scenario: Consumer observes cancellation as a terminal lifecycle event
- **WHEN** a caller cancels an active managed session run
- **THEN** the SDK emits a terminal cancellation event for that run and stops emitting further progress events for it

### Requirement: Events preserve transcript ordering
The SDK SHALL emit run events in the same logical order that messages, message parts, and tool results are appended to the transcript, while scoping emitted events to newly processed activity for the current run.

#### Scenario: Model requests multiple tools and emits additional parts in one response
- **WHEN** the loop processes multiple tool calls and structured assistant parts from a single model response
- **THEN** emitted run events preserve the order in which transcript messages and their parts are created

#### Scenario: Managed session resume does not replay prior messages
- **WHEN** a run starts from an existing managed session whose transcript already contains structured parts
- **THEN** new events are emitted only for newly processed loop activity and do not replay prior transcript state or prior parts out of order

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
