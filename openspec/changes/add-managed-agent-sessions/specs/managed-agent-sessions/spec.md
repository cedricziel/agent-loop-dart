## ADDED Requirements

### Requirement: SDK manages long-lived conversation handles
The SDK SHALL allow callers to create and reopen managed conversation sessions through a stable session identifier instead of requiring the caller to pass raw transcript state into every run.

#### Scenario: Caller creates a new managed session
- **WHEN** a caller requests a new managed session from the SDK
- **THEN** the SDK returns a session handle with a stable session identifier and empty conversation state ready for prompting

#### Scenario: Caller reopens a saved managed session
- **WHEN** a caller loads a previously saved managed session by identifier
- **THEN** the SDK restores the session transcript and metadata so follow-up prompts continue from the saved conversation state

### Requirement: Managed sessions can branch from prior conversation state
The SDK SHALL allow callers to fork a managed session from an existing session so exploratory follow-up work can continue on an independent branch.

#### Scenario: Caller branches an existing session
- **WHEN** a caller creates a branch from an existing managed session
- **THEN** the SDK creates a new session with a distinct identifier whose initial transcript matches the source session at the branch point

#### Scenario: Source session remains unchanged after branch work
- **WHEN** the branched session later receives additional prompts and tool activity
- **THEN** those transcript changes are recorded only on the branched session and do not mutate the source session

### Requirement: Managed sessions persist through a storage boundary
The SDK SHALL persist managed session state through a storage interface so callers can save and later restore sessions without coupling the loop to one concrete backend.

#### Scenario: Session store saves updated conversation state
- **WHEN** a managed session completes a run and persistence is enabled
- **THEN** the SDK writes the updated session identifier, transcript, and branch metadata through the configured session store

#### Scenario: In-memory usage remains supported
- **WHEN** a caller uses managed sessions without configuring durable storage
- **THEN** the SDK still supports the session handle flow through a default non-durable store
