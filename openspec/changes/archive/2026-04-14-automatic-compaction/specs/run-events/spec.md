## MODIFIED Requirements

### Requirement: SDK emits structured run lifecycle events
The SDK SHALL expose structured run lifecycle events so consumers can observe managed-session and stateless loop progress before a final `AgentRunResult` is available, including run start, part-level assistant updates, tool state, cancellation, completion metadata, and automatic compaction lifecycle reporting for managed sessions that enable policy-driven compaction.

#### Scenario: Consumer observes managed session run start and completion
- **WHEN** a managed session starts a run and later reaches a terminal completion state
- **THEN** the SDK emits ordered lifecycle events that identify the owning session, the active run, and the resulting transcript updates

#### Scenario: Consumer observes cancellation as a terminal lifecycle event
- **WHEN** a caller cancels an active managed session run
- **THEN** the SDK emits a terminal cancellation event for that run and stops emitting further progress events for it

#### Scenario: Consumer observes automatic compaction after a run
- **WHEN** a managed session with automatic compaction enabled compacts successfully at a safe post-run boundary
- **THEN** the SDK emits ordered lifecycle reporting that identifies the owning session, the triggering run, and the resulting compaction outcome before the session becomes the persisted state for later prompts
