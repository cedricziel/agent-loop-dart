## MODIFIED Requirements

### Requirement: Provider failures are surfaced predictably
The SDK SHALL surface provider request failures through a consistent error boundary so callers can distinguish provider failures from loop termination and tool execution results, including normalized metadata that identifies whether a failure is retryable for SDK-managed reliability policies.

#### Scenario: Provider request fails before a final response
- **WHEN** the provider adapter cannot complete a model request
- **THEN** the run fails with a provider-specific failure surfaced through the normalized SDK error path

#### Scenario: Tool failures remain distinct from provider failures
- **WHEN** a tool execution fails after a successful provider response
- **THEN** the loop does not report that failure as a provider adapter error

#### Scenario: Provider classifies a transient failure as retryable
- **WHEN** a provider encounters a transient transport or server-side failure that can be retried safely
- **THEN** it surfaces that failure through the normalized provider error boundary with retryable reliability metadata

#### Scenario: Provider classifies a permanent failure as non-retryable
- **WHEN** a provider encounters a failure that should not be retried, such as invalid caller input or unsupported provider behavior
- **THEN** it surfaces that failure through the normalized provider error boundary without marking it retryable
