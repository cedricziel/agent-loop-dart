## MODIFIED Requirements

### Requirement: SDK emits structured run lifecycle events
The SDK SHALL expose structured run lifecycle events so consumers can observe managed-session and stateless loop progress before a final `AgentRunResult` is available, including agent selection, delegation boundaries, permission decisions, run start, part-level assistant updates, tool state, cancellation, and completion metadata.

#### Scenario: Consumer observes agent delegation lifecycle
- **WHEN** a parent agent selects a subagent and delegates work into a child session
- **THEN** the SDK emits ordered lifecycle events that identify the parent session, child session, delegating agent, delegated agent, and resulting child-run boundaries

#### Scenario: Consumer observes permission decisions in the event stream
- **WHEN** the runtime resolves a permission outcome for a tool call or subagent invocation
- **THEN** the SDK emits an event describing whether the action was allowed, requires approval, or was denied

### Requirement: Events preserve transcript ordering
The SDK SHALL emit run events in the same logical order that messages, message parts, tool results, and delegated child-run boundaries are appended to the session hierarchy.

#### Scenario: Parent run delegates work and later continues
- **WHEN** a parent run emits transcript parts, delegates work to a child session, and then resumes parent-side progress
- **THEN** emitted events preserve the order of newly created parent and child session activity without replaying prior transcript state

#### Scenario: Permission denial does not fabricate transcript activity
- **WHEN** a permission policy denies a tool call or subagent invocation
- **THEN** the event stream reports the denial without appending fake assistant, tool, or child-session transcript messages for work that never executed
