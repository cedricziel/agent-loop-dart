## MODIFIED Requirements

### Requirement: Managed sessions can branch from prior conversation state
The SDK SHALL allow callers to fork a managed session from an existing session so exploratory follow-up work can continue on an independent branch, while preserving parent-child delegation metadata and any stored compaction state on the new branch.

#### Scenario: Caller branches an existing root or child session
- **WHEN** a caller creates a branch from an existing managed session
- **THEN** the SDK creates a new session with a distinct identifier whose initial transcript matches the source session at the branch point and whose parent-child metadata remains internally consistent for the new branch

#### Scenario: Source session remains unchanged after branch work
- **WHEN** the branched session later receives additional prompts, tool activity, or delegated child work
- **THEN** those changes are recorded only on the branched session tree and do not mutate the source session

#### Scenario: Branch inherits compacted session state
- **WHEN** a caller branches a managed session that already contains compaction metadata
- **THEN** the SDK copies that compaction metadata into the new branch together with the branch's initial raw transcript state

### Requirement: Managed sessions persist through a storage boundary
The SDK SHALL persist managed session state through a storage interface so callers can save and later restore sessions without coupling the loop to one concrete backend, including any stored compaction metadata alongside the remaining raw transcript and branch metadata.

#### Scenario: Session store saves updated conversation state
- **WHEN** a managed session completes a run and persistence is enabled
- **THEN** the SDK writes the updated session identifier, transcript, and branch metadata through the configured session store

#### Scenario: In-memory usage remains supported
- **WHEN** a caller uses managed sessions without configuring durable storage
- **THEN** the SDK still supports the session handle flow through a default non-durable store

#### Scenario: Session store saves compacted session state
- **WHEN** a caller compacts a managed session and persistence is enabled
- **THEN** the SDK writes the updated session identifier, remaining raw transcript, and compaction metadata through the configured session store

#### Scenario: Caller reloads a compacted session
- **WHEN** a caller loads a previously saved managed session that contains compaction metadata
- **THEN** the SDK restores both the remaining raw transcript and the persisted compaction metadata so later runs resume from the compacted state
