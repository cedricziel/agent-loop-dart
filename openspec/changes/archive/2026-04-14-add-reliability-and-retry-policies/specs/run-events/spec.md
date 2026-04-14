## ADDED Requirements

### Requirement: SDK emits retry lifecycle events for provider reliability
The SDK SHALL expose retry lifecycle events in the run event stream whenever a configured provider reliability policy performs or exhausts provider retries.

#### Scenario: Retryable failure emits a retry event before the next attempt
- **WHEN** a provider attempt fails with a retryable failure and the reliability policy allows another attempt
- **THEN** the SDK emits a retry lifecycle event that records the failed attempt and the delay before the next attempt

#### Scenario: Exhausted retries emit a terminal exhaustion event
- **WHEN** a retryable provider failure reaches the configured attempt limit without a successful response
- **THEN** the SDK emits a retry exhaustion event before terminating the run with the final provider failure

### Requirement: Failed retry attempts do not mutate transcript ordering
The SDK SHALL keep failed provider attempts observable through retry lifecycle events without appending partial failed-attempt output into the persisted transcript.

#### Scenario: Failed streamed attempt emits retry metadata without partial transcript writes
- **WHEN** a streaming provider emits partial output and the attempt later fails before a terminal response
- **THEN** the SDK emits retry lifecycle events for the failed attempt and does not append that failed-attempt partial output into the transcript

#### Scenario: Successful retry preserves normal run completion ordering
- **WHEN** a later provider retry succeeds after one or more failed attempts
- **THEN** the SDK emits the successful assistant and completion events in normal order after the prior retry lifecycle events
