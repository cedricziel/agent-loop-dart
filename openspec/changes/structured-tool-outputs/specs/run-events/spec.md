## MODIFIED Requirements

### Requirement: SDK emits structured run lifecycle events
The SDK SHALL expose structured run lifecycle events so consumers can observe managed-session and stateless loop progress before a final `AgentRunResult` is available, including run start, part-level assistant updates, tool state, structured tool outputs, cancellation, completion metadata, and automatic compaction lifecycle reporting for managed sessions that enable policy-driven compaction.

#### Scenario: Consumer observes managed session run start and completion
- **WHEN** a managed session starts a run and later reaches a terminal completion state
- **THEN** the SDK emits ordered lifecycle events that identify the owning session, the active run, and the resulting transcript updates

#### Scenario: Consumer observes cancellation as a terminal lifecycle event
- **WHEN** a caller cancels an active managed session run
- **THEN** the SDK emits a terminal cancellation event for that run and stops emitting further progress events for it

#### Scenario: Consumer observes automatic compaction after a run
- **WHEN** a managed session with automatic compaction enabled compacts successfully at a safe post-run boundary
- **THEN** the SDK emits ordered lifecycle reporting that identifies the owning session, the triggering run, and the resulting compaction outcome before the session becomes the persisted state for later prompts

#### Scenario: Consumer observes structured tool result payloads
- **WHEN** a tool call completes during a run
- **THEN** the emitted tool result event carries the same structured tool output recorded in the transcript for that tool call

### Requirement: Events preserve transcript ordering
The SDK SHALL emit run events in the same logical order that messages, message parts, and tool results are appended to the transcript, while scoping emitted events to newly processed activity for the current run.

#### Scenario: Model requests multiple tools and emits additional parts in one response
- **WHEN** the loop processes multiple tool calls and structured assistant parts from a single model response
- **THEN** emitted run events preserve the order in which transcript messages, message parts, and structured tool results are created

#### Scenario: Managed session resume does not replay prior messages
- **WHEN** a run starts from an existing managed session whose transcript already contains structured parts
- **THEN** new events are emitted only for newly processed loop activity and do not replay prior transcript state or prior parts out of order
