## MODIFIED Requirements

### Requirement: SDK can continue an existing conversation
The SDK SHALL allow a caller to continue an existing conversation from either explicit prior transcript state or a managed session handle so follow-up prompts can build on prior transcript history, including previously recorded structured message parts and any persisted compacted session summary.

#### Scenario: Caller resumes from prior transcript snapshot
- **WHEN** a caller starts a run with an existing transcript and a new user prompt
- **THEN** the loop includes the prior transcript and its existing structured parts before evaluating the new prompt

#### Scenario: Caller resumes from a managed session handle
- **WHEN** a caller prompts an existing managed session
- **THEN** the SDK uses that session's current conversation state as the basis for the new run without requiring the caller to resupply the transcript

#### Scenario: Caller resumes from a compacted managed session
- **WHEN** a caller prompts a managed session whose older history has been compacted into a persisted summary
- **THEN** the SDK reconstructs the provider-facing context from that summary plus the session's retained raw transcript before evaluating the new prompt

#### Scenario: Result returns updated conversation state
- **WHEN** a resumed run completes successfully
- **THEN** the returned result and owning managed session both include the original conversation state plus the newly appended messages and structured parts from the resumed run, preserving any existing compacted summary metadata when present
