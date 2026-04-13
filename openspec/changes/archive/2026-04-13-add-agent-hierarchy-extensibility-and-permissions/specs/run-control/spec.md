## MODIFIED Requirements

### Requirement: Managed sessions can cancel active runs
The SDK SHALL allow a caller to cancel an in-flight managed session run through the session handle, including delegated child runs.

#### Scenario: Caller aborts an active delegated child run
- **WHEN** a caller requests cancellation for a managed child session that currently has an active delegated run
- **THEN** the SDK stops further loop progress for that child run and surfaces a terminal cancelled state through the child session lifecycle

#### Scenario: Parent cancellation does not silently orphan active child work
- **WHEN** a caller cancels a parent session while a delegated child run is active
- **THEN** the runtime surfaces explicit cancellation behavior for the affected child run instead of leaving it in an indeterminate active state

### Requirement: Managed sessions serialize active runs
The SDK SHALL allow only one active run at a time for a given managed session, while treating parent and child sessions as distinct concurrency scopes.

#### Scenario: Parent and child sessions each run one active task
- **WHEN** a parent session and one of its child sessions each start a run
- **THEN** the runtime enforces single-active-run semantics independently for each session instead of collapsing all hierarchy work into one global lock

#### Scenario: Same session rejects a second active run
- **WHEN** a caller attempts to prompt a managed session that already has an active run
- **THEN** the SDK rejects the new request with a structured concurrency error instead of interleaving transcript mutations
