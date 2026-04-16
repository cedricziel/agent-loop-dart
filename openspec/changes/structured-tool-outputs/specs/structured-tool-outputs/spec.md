## ADDED Requirements

### Requirement: SDK preserves structured tool outputs across runtime surfaces
The SDK SHALL represent each tool execution result as a structured tool output that can carry a deterministic text rendering, typed metadata, and optional structured content parts, and SHALL preserve that structured output in transcripts, run results, and managed session state.

#### Scenario: Tool result is stored in the transcript
- **WHEN** a tool call completes during a run
- **THEN** the resulting transcript message stores the structured tool output rather than only a flattened output string

#### Scenario: Session resume retains structured tool output
- **WHEN** a later run resumes from a transcript or managed session that already contains prior tool results
- **THEN** the SDK preserves the original structured tool output data for those prior tool results without reparsing text

### Requirement: SDK keeps a deterministic text compatibility view for tool outputs
The SDK SHALL expose a stable text rendering for every structured tool output so text-first callers and provider follow-up prompts can continue consuming tool results without custom serialization logic.

#### Scenario: Text-only caller reads a tool result
- **WHEN** a caller uses the compatibility text view of a structured tool result
- **THEN** the caller receives a deterministic string representation of the same tool output

#### Scenario: Structured output includes metadata and parts
- **WHEN** a tool returns metadata fields or structured content parts in addition to text
- **THEN** the compatibility text view remains available without discarding the structured fields from the canonical output object

### Requirement: Custom tools can return structured tool outputs through the shared contract
The SDK SHALL allow any `AgentTool` implementation, including caller-defined tools, to return the shared structured tool output model instead of being limited to raw strings.

#### Scenario: Custom tool returns metadata
- **WHEN** a caller-defined tool returns a structured output with metadata
- **THEN** the loop records that metadata in the resulting tool output without special handling for builtin tools

#### Scenario: Custom tool returns content parts
- **WHEN** a caller-defined tool returns structured content parts as part of its tool output
- **THEN** the SDK preserves those parts in the tool result surfaced to transcripts and consumers
