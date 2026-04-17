## ADDED Requirements

### Requirement: SDK emits structured run lifecycle events
The SDK SHALL expose structured run lifecycle events so consumers can observe managed-session and stateless loop progress before a final `AgentRunResult` is available, including run start, part-level assistant updates, tool state, structured tool outputs, interactive question pauses and resolutions, cancellation, completion metadata, and automatic compaction lifecycle reporting for managed sessions that enable policy-driven compaction.

#### Scenario: Consumer observes managed session run start and completion
- **WHEN** a managed session starts a run and later reaches a terminal completion state
- **THEN** the SDK emits ordered lifecycle events that identify the owning session, the active run, and the resulting transcript updates

#### Scenario: Consumer observes cancellation as a terminal lifecycle event
- **WHEN** a caller cancels an active managed session run
- **THEN** the SDK emits a terminal cancellation event for that run and stops emitting further progress events for it

#### Scenario: Consumer observes automatic compaction after a run
- **WHEN** a managed session with automatic compaction enabled compacts successfully at a safe post-run boundary
- **THEN** the SDK emits ordered lifecycle reporting that identifies the owning session, the triggering run, and the resulting compaction outcome before the session becomes the persisted state for later prompts

#### Scenario: Consumer observes a pending interactive question
- **WHEN** a managed-session run pauses because the model called `ask_user`
- **THEN** the SDK emits lifecycle reporting that identifies the owning session, active run, and pending question request without emitting later loop activity for that run until the request is resolved

#### Scenario: Consumer observes question answer resolution
- **WHEN** a caller answers a pending `ask_user` request on a managed session
- **THEN** the SDK emits ordered lifecycle reporting for the question resolution before the resumed run continues from the resulting `ask_user` tool result

#### Scenario: Consumer observes question cancellation as a terminal interruption
- **WHEN** a caller cancels a pending `ask_user` request on a managed session
- **THEN** the SDK emits terminal lifecycle reporting for the interrupted run and stops emitting further progress events for that run

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

### Requirement: Run events can include provider-streamed partial output
The SDK SHALL allow the run event stream to surface provider-originated partial assistant output in order before the terminal assistant response is complete.

#### Scenario: Streaming provider emits partial assistant text
- **WHEN** a provider emits incremental assistant output for an active run
- **THEN** the SDK emits ordered run events for that partial output before the final completion event for the run

#### Scenario: Final completion follows streamed output
- **WHEN** a streaming provider reaches the terminal response for a run
- **THEN** the SDK emits the final completion event after the previously streamed partial output events for that run

### Requirement: Provider-streamed events preserve existing ordering guarantees
The SDK SHALL preserve existing transcript and lifecycle ordering guarantees when provider-streamed output is interleaved with assistant messages, tool activity, and completion.

#### Scenario: Streamed output precedes tool calls from the same response
- **WHEN** a provider response emits partial assistant output and later yields tool calls
- **THEN** the SDK emits the partial output events before any tool-call events produced from that same response

#### Scenario: Session resume does not replay prior streamed chunks
- **WHEN** a resumed run starts from an existing session transcript that already contains content assembled from an earlier streamed response
- **THEN** the SDK does not replay the earlier streamed chunk events and only emits newly streamed output for the current run
