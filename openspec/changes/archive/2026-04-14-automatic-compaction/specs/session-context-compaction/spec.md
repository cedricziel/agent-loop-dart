## MODIFIED Requirements

### Requirement: Managed sessions can compact older context explicitly
The SDK SHALL allow a caller to compact a managed session by summarizing an older prefix of conversation history while retaining a configurable recent suffix of raw transcript messages, and SHALL preserve the same compaction model when compaction is triggered automatically by managed-session policy.

#### Scenario: Caller compacts an eligible session
- **WHEN** a caller requests compaction for a managed session with enough historical messages to preserve the required recent suffix
- **THEN** the SDK replaces the compacted prefix with stored compaction metadata containing the generated summary and keeps the preserved recent suffix as the session's remaining raw transcript

#### Scenario: Automatic policy compacts an eligible session
- **WHEN** a managed session with automatic compaction enabled reaches its configured compaction threshold at a safe session boundary
- **THEN** the SDK applies the same stored compaction metadata model and retained raw suffix rules used by explicit compaction

#### Scenario: Caller cannot compact below the retained suffix floor
- **WHEN** a caller requests compaction for a managed session that does not contain enough historical messages beyond the configured retained suffix
- **THEN** the SDK rejects the request without mutating the session state

### Requirement: Compaction uses a pluggable summarizer boundary
The SDK SHALL require compaction to execute through an explicit summarizer boundary so callers can provide deterministic or provider-assisted summary generation without coupling the runtime to one built-in algorithm, including when automatic compaction resolves a summarizer from persisted managed-session policy.

#### Scenario: Summarizer receives the compacted transcript segment
- **WHEN** compaction starts for a managed session
- **THEN** the SDK passes the selected historical transcript prefix to the configured summarizer and persists the summary result it returns as compaction metadata

#### Scenario: Automatic compaction resolves a configured summarizer
- **WHEN** automatic compaction is triggered for a managed session that stores a summarizer identifier or equivalent runtime compaction strategy
- **THEN** the SDK resolves the configured summarizer through the runtime boundary before performing compaction
