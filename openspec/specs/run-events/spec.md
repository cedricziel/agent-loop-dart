## ADDED Requirements

### Requirement: SDK emits structured run lifecycle events
The SDK SHALL expose structured run lifecycle events so consumers can observe loop progress before a final `AgentRunResult` is available.

#### Scenario: Consumer observes tool execution lifecycle
- **WHEN** the loop starts a tool call and later receives the tool result
- **THEN** the SDK emits ordered lifecycle events describing the tool call and the tool result

#### Scenario: Consumer observes run completion
- **WHEN** the loop reaches a final assistant response
- **THEN** the SDK emits a completion event that includes the same terminal outcome represented by the final run result

### Requirement: Events preserve transcript ordering
The SDK SHALL emit run events in the same logical order that messages and tool results are appended to the transcript.

#### Scenario: Model requests multiple tools in one response
- **WHEN** the loop processes multiple tool calls from a single model response
- **THEN** emitted run events preserve the order in which assistant and tool transcript entries are created

#### Scenario: Session resume does not reorder prior messages
- **WHEN** a run starts from an existing transcript
- **THEN** new events are emitted only for newly processed loop activity and do not replay prior transcript state out of order
