## MODIFIED Requirements

### Requirement: Managed sessions persist through a storage boundary
The SDK SHALL persist managed session state through a storage interface so callers can save and later restore sessions without coupling the loop to one concrete backend, including any stored compaction metadata alongside the remaining raw transcript, branch metadata, and any configured automatic compaction policy.

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

#### Scenario: Session store saves automatic compaction policy
- **WHEN** a caller creates or updates a managed session with automatic compaction enabled and persistence is enabled
- **THEN** the SDK writes the automatic compaction policy together with the session's transcript and metadata through the configured session store

#### Scenario: Caller reloads a session with automatic compaction enabled
- **WHEN** a caller loads a previously saved managed session that contains automatic compaction policy metadata
- **THEN** the SDK restores that policy so later runs continue evaluating automatic compaction with the same persisted settings
