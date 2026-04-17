## MODIFIED Requirements

### Requirement: SDK emits structured run lifecycle events
The SDK SHALL expose structured run lifecycle events so consumers can observe managed-session and stateless loop progress before a final `AgentRunResult` is available, including run start, part-level assistant updates, tool state, structured tool outputs, interactive question pauses and resolutions, cancellation, completion metadata, and automatic compaction lifecycle reporting for managed sessions that enable policy-driven compaction.

#### Scenario: Consumer observes a pending interactive question
- **WHEN** a managed-session run pauses because the model called `ask_user`
- **THEN** the SDK emits lifecycle reporting that identifies the owning session, active run, and pending question request without emitting later loop activity for that run until the request is resolved

#### Scenario: Consumer observes question answer resolution
- **WHEN** a caller answers a pending `ask_user` request on a managed session
- **THEN** the SDK emits ordered lifecycle reporting for the question resolution before the resumed run continues from the resulting `ask_user` tool result

#### Scenario: Consumer observes question cancellation as a terminal interruption
- **WHEN** a caller cancels a pending `ask_user` request on a managed session
- **THEN** the SDK emits terminal lifecycle reporting for the interrupted run and stops emitting further progress events for that run
