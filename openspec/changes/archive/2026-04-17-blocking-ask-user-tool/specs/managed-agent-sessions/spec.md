## MODIFIED Requirements

### Requirement: Managed sessions persist pending interactive state
The SDK SHALL persist pending interactive run state through the managed session storage boundary so paused approval and pending question requests survive session reload.

#### Scenario: Session store saves paused question metadata
- **WHEN** a managed session pauses because the model called `ask_user`
- **THEN** the SDK saves the session with its pending question request metadata through the configured session store

#### Scenario: Question resolution updates stored session state
- **WHEN** a caller answers or cancels a pending question request on a managed session
- **THEN** the SDK saves the updated session state with the pending question metadata cleared or replaced by the resumed transcript state
