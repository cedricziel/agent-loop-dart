## ADDED Requirements

### Requirement: Managed sessions can compact automatically from policy
The SDK SHALL allow a managed session to opt into automatic compaction through a persisted policy that defines when compaction runs and how much recent raw transcript state is retained.

#### Scenario: Eligible session compacts automatically after a run
- **WHEN** a managed session has automatic compaction enabled and the session state exceeds the configured compaction threshold after a run completes
- **THEN** the SDK automatically compacts the configured historical prefix using the policy's retained suffix settings before the session is persisted for the next prompt

#### Scenario: Session below threshold remains unchanged
- **WHEN** a managed session has automatic compaction enabled but the session state does not exceed the configured compaction threshold after a run completes
- **THEN** the SDK persists the updated session without invoking compaction

### Requirement: Automatic compaction only runs at safe managed-session boundaries
The SDK SHALL evaluate automatic compaction only at managed-session boundaries where the session is not actively executing or paused for approval.

#### Scenario: Active run does not compact mid-execution
- **WHEN** an automatic-compaction-managed session is still executing provider or tool work for the current run
- **THEN** the SDK does not mutate session transcript or compaction state until the run reaches a safe post-run boundary

#### Scenario: Pending approval blocks automatic compaction
- **WHEN** an automatic-compaction-managed session ends a run in a paused approval state
- **THEN** the SDK does not perform automatic compaction until the approval is resolved and a later safe boundary is reached
