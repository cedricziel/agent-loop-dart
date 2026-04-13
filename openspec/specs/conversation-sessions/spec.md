## ADDED Requirements

### Requirement: SDK can continue an existing conversation
The SDK SHALL allow a caller to continue an existing conversation from either explicit prior transcript state or a managed session handle so follow-up prompts can build on prior transcript history, including previously recorded structured message parts.

#### Scenario: Caller resumes from prior transcript snapshot
- **WHEN** a caller starts a run with an existing transcript and a new user prompt
- **THEN** the loop includes the prior transcript and its existing structured parts before evaluating the new prompt

#### Scenario: Caller resumes from a managed session handle
- **WHEN** a caller prompts an existing managed session
- **THEN** the SDK uses that session's current transcript state as the basis for the new run without requiring the caller to resupply the transcript

#### Scenario: Result returns updated conversation state
- **WHEN** a resumed run completes successfully
- **THEN** the returned result and owning managed session both include the original transcript entries plus the newly appended messages and structured parts from the resumed run

### Requirement: One-shot runs remain supported
The SDK SHALL continue to support the current one-shot prompt flow for callers that do not need conversation state, while treating text-only behavior as a compatibility view over structured message parts.

#### Scenario: Caller starts without prior state
- **WHEN** a caller uses the SDK without providing any existing transcript
- **THEN** the run behaves as a fresh one-shot conversation and can still be represented entirely through text parts when no richer content is produced

#### Scenario: Existing one-shot usage remains additive
- **WHEN** current callers continue using the existing run entry point
- **THEN** they are not required to construct or manage session state or rich parts directly to get a final response
