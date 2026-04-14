## Why

The SDK currently treats provider calls as one-shot operations, which leaves common transient failures such as timeouts, connection resets, and rate limits entirely up to each caller or provider package to handle. Now that provider adapters and streaming support exist, the missing reliability layer has become a real product gap because the same run can fail nondeterministically across providers without any shared retry contract.

## What Changes

- Add a first-class reliability policy capability that defines how provider requests opt into bounded retries, timeout budgets, and backoff for transient failures.
- Define normalized retry semantics so providers can classify retryable failures consistently without baking provider-specific policy rules into `AgentLoop` call sites.
- Expose retry attempts and final exhaustion through the runtime surface so callers and the CLI can understand whether a run succeeded immediately, succeeded after retries, or failed after the retry budget was exhausted.
- Keep tool execution behavior unchanged in this change; retry behavior applies to provider transport and response acquisition, not to arbitrary tool side effects.

## Capabilities

### New Capabilities
- `reliability-policies`: Defines bounded timeout, backoff, and retry policy behavior for provider-backed runs, including observability of retry attempts and terminal exhaustion.

### Modified Capabilities
- `provider-adapters`: Extend provider adapter requirements so providers can surface retryable versus non-retryable failures through a normalized reliability contract.
- `run-events`: Expose retry attempts and terminal retry exhaustion through the existing run event model.

## Impact

- Affects `packages/agent_loop_core` provider-facing runtime types, loop orchestration, and streaming execution flow.
- Affects `packages/agent_loop` public SDK exports and configuration surface for callers that want to opt into or customize retry behavior.
- Affects `packages/agent_loop_provider_ollama` so the reference provider can classify transient transport failures and participate in the shared retry contract.
- Affects CLI and example flows so retries are visible during smoke runs and demo usage.
