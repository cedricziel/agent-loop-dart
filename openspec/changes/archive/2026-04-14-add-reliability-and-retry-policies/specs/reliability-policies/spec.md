## ADDED Requirements

### Requirement: SDK supports configurable provider reliability policies
The SDK SHALL allow callers to configure a bounded reliability policy for provider-backed runs that controls maximum attempts, per-attempt timeout, and retry backoff behavior.

#### Scenario: Caller keeps one-shot behavior
- **WHEN** a caller does not configure a reliability policy for a provider-backed run
- **THEN** the SDK performs a single provider attempt and preserves existing one-shot behavior

#### Scenario: Caller enables bounded retries
- **WHEN** a caller configures a reliability policy with multiple allowed attempts
- **THEN** the SDK retries retryable provider failures only up to the configured attempt limit and delay policy

### Requirement: Reliability policies apply only to provider attempts
The SDK SHALL apply reliability policies to provider request execution and provider response acquisition only, without retrying tool execution or other side-effecting runtime work.

#### Scenario: Retryable provider failure is retried before any tool execution
- **WHEN** a provider attempt fails with a retryable failure before the loop reaches tool execution
- **THEN** the SDK may retry the provider attempt according to the configured reliability policy

#### Scenario: Tool failure is not retried by provider policy
- **WHEN** a tool execution fails after a successful provider response
- **THEN** the SDK does not retry that tool execution as part of the provider reliability policy

### Requirement: Reliability policies preserve terminal provider failure semantics
The SDK SHALL fail the run with a provider error when a failure is non-retryable or when the configured retry budget is exhausted.

#### Scenario: Non-retryable failure fails immediately
- **WHEN** a provider attempt fails with a non-retryable failure classification
- **THEN** the SDK terminates the run without performing another provider attempt

#### Scenario: Retry budget exhaustion fails the run
- **WHEN** a retryable provider failure continues until the configured attempt budget is exhausted
- **THEN** the SDK terminates the run with the terminal provider failure after the last allowed attempt
