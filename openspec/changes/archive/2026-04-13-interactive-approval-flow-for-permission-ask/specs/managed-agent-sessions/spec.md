## ADDED Requirements

### Requirement: Managed sessions persist pending approval state
The SDK SHALL persist pending approval metadata through the managed session storage boundary so approval requests survive session reload.

#### Scenario: Session store saves paused approval metadata
- **WHEN** a managed session pauses because a permission decision returned `ask`
- **THEN** the SDK saves the session with its pending approval metadata through the configured session store

#### Scenario: Approval resolution updates stored session state
- **WHEN** a caller approves or denies the pending request on a managed session
- **THEN** the SDK saves the updated session state with the pending approval metadata cleared or replaced by the resumed transcript state
