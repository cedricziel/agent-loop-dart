## MODIFIED Requirements

### Requirement: SDK manages long-lived conversation handles
The SDK SHALL allow callers to create and reopen managed conversation sessions through a stable session identifier, including managed sessions that participate in parent-child delegation hierarchies.

#### Scenario: Caller creates a new root managed session
- **WHEN** a caller requests a new top-level managed session from the SDK
- **THEN** the SDK returns a session handle with a stable session identifier, no parent session, and empty conversation state ready for prompting

#### Scenario: Runtime creates a delegated child session
- **WHEN** a parent agent delegates work to an allowed subagent profile
- **THEN** the SDK creates a managed child session with its own stable identifier and metadata linking it to the parent session and delegating agent

### Requirement: Managed sessions can branch from prior conversation state
The SDK SHALL allow callers to fork a managed session from an existing session so exploratory follow-up work can continue on an independent branch, while preserving parent-child delegation metadata on the new branch.

#### Scenario: Caller branches an existing root or child session
- **WHEN** a caller creates a branch from an existing managed session
- **THEN** the SDK creates a new session with a distinct identifier whose initial transcript matches the source session at the branch point and whose parent-child metadata remains internally consistent for the new branch

#### Scenario: Source session remains unchanged after branch work
- **WHEN** the branched session later receives additional prompts, tool activity, or delegated child work
- **THEN** those changes are recorded only on the branched session tree and do not mutate the source session
