## MODIFIED Requirements

### Requirement: SDK emits structured run lifecycle events
The SDK SHALL expose structured run lifecycle events so consumers can observe loop progress before a final `AgentRunResult` is available, including part-level updates for assistant output and tool state.

#### Scenario: Consumer observes tool execution lifecycle
- **WHEN** the loop starts a tool call, updates tool progress, and later receives the tool result
- **THEN** the SDK emits ordered lifecycle events describing the tool state transitions and the resulting transcript parts

#### Scenario: Consumer observes assistant part updates before completion
- **WHEN** a provider response produces one or more assistant message parts before the run reaches a final result
- **THEN** the SDK emits part-level updates in the same order those parts are appended to the transcript

### Requirement: Events preserve transcript ordering
The SDK SHALL emit run events in the same logical order that messages, message parts, and tool results are appended to the transcript.

#### Scenario: Model requests multiple tools and emits additional parts in one response
- **WHEN** the loop processes multiple tool calls and structured assistant parts from a single model response
- **THEN** emitted run events preserve the order in which transcript messages and their parts are created

#### Scenario: Session resume does not reorder prior messages
- **WHEN** a run starts from an existing transcript that already contains structured parts
- **THEN** new events are emitted only for newly processed loop activity and do not replay prior transcript state or prior parts out of order
