## ADDED Requirements

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
