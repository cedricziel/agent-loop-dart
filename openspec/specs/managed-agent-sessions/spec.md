## ADDED Requirements

### Requirement: SDK manages long-lived conversation handles
The SDK SHALL allow callers to create and reopen managed conversation sessions through a stable session identifier instead of requiring the caller to pass raw transcript state into every run, including managed sessions that participate in parent-child delegation hierarchies.

#### Scenario: Caller creates a new root managed session
- **WHEN** a caller requests a new top-level managed session from the SDK
- **THEN** the SDK returns a session handle with a stable session identifier, no parent session, and empty conversation state ready for prompting

#### Scenario: Caller reopens a saved managed session
- **WHEN** a caller loads a previously saved managed session by identifier
- **THEN** the SDK restores the session transcript and metadata so follow-up prompts continue from the saved conversation state

#### Scenario: Runtime creates a delegated child session
- **WHEN** a parent agent delegates work to an allowed subagent profile
- **THEN** the SDK creates a managed child session with its own stable identifier and metadata linking it to the parent session and delegating agent

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

### Requirement: Managed sessions persist pending approval state
The SDK SHALL persist pending approval metadata through the managed session storage boundary so approval requests survive session reload.

#### Scenario: Session store saves paused approval metadata
- **WHEN** a managed session pauses because a permission decision returned `ask`
- **THEN** the SDK saves the session with its pending approval metadata through the configured session store

#### Scenario: Approval resolution updates stored session state
- **WHEN** a caller approves or denies the pending request on a managed session
- **THEN** the SDK saves the updated session state with the pending approval metadata cleared or replaced by the resumed transcript state

### Requirement: Managed sessions persist pending interactive state
The SDK SHALL persist pending interactive run state through the managed session storage boundary so paused approval and pending question requests survive session reload.

#### Scenario: Session store saves paused question metadata
- **WHEN** a managed session pauses because the model called `ask_user`
- **THEN** the SDK saves the session with its pending question request metadata through the configured session store

#### Scenario: Question resolution updates stored session state
- **WHEN** a caller answers or cancels a pending question request on a managed session
- **THEN** the SDK saves the updated session state with the pending question metadata cleared or replaced by the resumed transcript state
