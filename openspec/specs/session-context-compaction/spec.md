## ADDED Requirements

### Requirement: Managed sessions can compact older context explicitly
The SDK SHALL allow a caller to compact a managed session by summarizing an older prefix of conversation history while retaining a configurable recent suffix of raw transcript messages.

#### Scenario: Caller compacts an eligible session
- **WHEN** a caller requests compaction for a managed session with enough historical messages to preserve the required recent suffix
- **THEN** the SDK replaces the compacted prefix with stored compaction metadata containing the generated summary and keeps the preserved recent suffix as the session's remaining raw transcript

#### Scenario: Caller cannot compact below the retained suffix floor
- **WHEN** a caller requests compaction for a managed session that does not contain enough historical messages beyond the configured retained suffix
- **THEN** the SDK rejects the request without mutating the session state

### Requirement: Compaction uses a pluggable summarizer boundary
The SDK SHALL require compaction to execute through an explicit summarizer boundary so callers can provide deterministic or provider-assisted summary generation without coupling the runtime to one built-in algorithm.

#### Scenario: Summarizer receives the compacted transcript segment
- **WHEN** compaction starts for a managed session
- **THEN** the SDK passes the selected historical transcript prefix to the configured summarizer and persists the summary result it returns as compaction metadata

### Requirement: Compacted sessions resume with summary-backed context
The SDK SHALL reconstruct provider-facing context for a compacted managed session by combining the persisted compaction summary with the retained raw transcript suffix before evaluating the next user prompt.

#### Scenario: Follow-up run uses compacted summary and recent raw turns
- **WHEN** a caller prompts a managed session that has previously been compacted
- **THEN** the SDK resumes the conversation from the stored summary plus the retained recent raw transcript instead of requiring the compacted-away raw messages to remain in session storage
