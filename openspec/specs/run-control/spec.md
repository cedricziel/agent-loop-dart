## ADDED Requirements

### Requirement: Managed sessions can cancel active runs
The SDK SHALL allow a caller to cancel an in-flight managed session run through the session handle.

#### Scenario: Caller aborts an active run
- **WHEN** a caller requests cancellation for a managed session that currently has an active run
- **THEN** the SDK stops further loop progress for that run and surfaces a terminal cancelled state through the managed session lifecycle

#### Scenario: Cancelling an idle session is safe
- **WHEN** a caller requests cancellation for a managed session that does not have an active run
- **THEN** the SDK performs no loop mutation and reports that no active run was cancelled

### Requirement: Managed sessions serialize active runs
The SDK SHALL allow only one active run at a time for a given managed session.

#### Scenario: Caller starts a second run while one is active
- **WHEN** a caller attempts to prompt a managed session that already has an active run
- **THEN** the SDK rejects the new request with a structured concurrency error instead of interleaving transcript mutations

#### Scenario: Caller starts a new run after prior completion
- **WHEN** a managed session has no active run because the previous run completed or was cancelled
- **THEN** the SDK allows a new prompt to start and assigns it a new run identifier
