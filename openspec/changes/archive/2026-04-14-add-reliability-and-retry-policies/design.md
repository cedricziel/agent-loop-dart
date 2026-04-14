## Context

`AgentLoop` currently performs exactly one provider attempt for each model step. Provider failures are wrapped as `AgentProviderException`, but the exception shape does not distinguish transient failures from permanent ones and the loop does not apply any timeout, retry, or backoff policy around either `respond()` or `streamRespond()`.

That keeps the core loop small, but it pushes reliability behavior into each provider package or caller and produces inconsistent outcomes across providers. The existing Ollama provider already maps transport exceptions into the shared exception type, so the runtime now has a stable enough provider boundary to add a first reliability layer without reworking tool execution or session semantics.

## Goals / Non-Goals

**Goals:**
- Add an additive reliability policy surface for provider-backed runs in `agent_loop_core` and re-export it through `agent_loop`.
- Let providers classify failures as retryable or non-retryable through normalized metadata rather than provider-specific logic in callers.
- Apply bounded retry, timeout, and backoff behavior around provider attempts for both non-streaming and streaming providers.
- Emit structured retry lifecycle events so callers can observe retry attempts and retry exhaustion before terminal failure.
- Keep behavior deterministic enough for TDD and repository smoke checks.

**Non-Goals:**
- Retrying tool execution, approval flows, or subagent delegation side effects.
- Adding persistence, metrics backends, or circuit-breaker state shared across runs.
- Designing provider-specific retry heuristics beyond the minimal classification hooks needed for the reference provider.
- Introducing randomized jitter in the first tranche; deterministic backoff is sufficient for the initial change.

## Decisions

### 1. Add a normalized reliability policy object at the loop boundary

Introduce an `AgentReliabilityPolicy` value that is accepted by `AgentLoop` and `AgentLoopSdk`. The policy should include the bounded controls needed by the first tranche: maximum attempts, per-attempt timeout, initial retry delay, delay multiplier, and maximum delay.

Why this over hard-coding retries in providers:
- It gives callers one consistent configuration surface across providers.
- It keeps policy ownership in the orchestrator that already owns step progression and failure propagation.
- It avoids forcing every provider package to reinvent the same retry knobs.

Alternative considered:
- Let each provider package expose its own retry options only. Rejected because the base SDK would still lack a shared reliability contract and callers would get incompatible behavior across providers.

### 2. Keep provider interfaces stable and enrich `AgentProviderException`

Do not add new required methods to `AgentProvider` or `AgentStreamingProvider`. Instead, extend `AgentProviderException` with additive reliability metadata such as failure kind, retryability hint, and optional retry-after duration. Providers can throw the richer exception, while the loop continues to depend on the same interface surface.

Why this over adding a separate classification callback or provider API:
- It keeps the change small and compatible with existing providers.
- It lets providers attach transport-aware context at the point where the failure is detected.
- It preserves the current error boundary while making retry decisions possible.

Alternative considered:
- Add a new provider-side classifier interface. Rejected because it adds more types and lifecycle plumbing than the current repo needs.

### 3. Centralize retry execution in `AgentLoop`

Wrap provider calls in a retry executor inside `AgentLoop` so the same logic covers `respond()` and `streamRespond()`. For streaming providers, an attempt ends only when a terminal `AgentProviderResponseEvent` is received or the attempt fails. Partial streamed output from a failed attempt must not be committed into the transcript; only retry lifecycle events are emitted for failed attempts.

Why this over implementing retries separately in each provider path:
- It preserves one set of semantics for streaming and non-streaming behavior.
- It prevents partial failed-attempt output from leaking into the transcript.
- It keeps retry bookkeeping next to the existing step loop and event emission logic.

Alternative considered:
- Retry only non-streaming providers in the first change. Rejected because it would create surprising reliability gaps exactly where long-lived provider calls are most fragile.

### 4. Make retries opt-in and deterministic in the first tranche

The default policy should remain `AgentReliabilityPolicy.none()` so existing callers keep one-shot semantics unless they opt in. A convenience `standard()` factory can provide a small bounded policy for callers and examples. Backoff should be deterministic rather than jittered so tests can assert exact retry behavior.

Why this over enabling retries by default:
- It avoids changing failure timing and side effects for existing consumers unexpectedly.
- It keeps rollout safe while still providing a first-class capability for callers that need reliability.
- It makes TDD straightforward because retry timing is predictable.

Alternative considered:
- Enable a default retry policy for all provider-backed runs. Rejected for the first change because it would be a silent behavioral change in public APIs.

### 5. Expose retry lifecycle as new run events

Add retry-oriented `AgentRunEvent` types that record attempt number, provider identity, classified failure metadata, chosen delay, and terminal exhaustion. These events should be emitted before a retry sleep begins and before the stream terminates with a final provider failure after the retry budget is exhausted.

Why this over hiding retries behind the final result only:
- It keeps retries observable in the same model as existing run lifecycle events.
- It gives the CLI and examples a straightforward way to explain why a run paused or recovered.
- It avoids forcing callers to infer retries indirectly from wall-clock timing.

Alternative considered:
- Put retry data only on the final exception/result. Rejected because successful runs after retry would still be opaque to observers.

## Risks / Trade-offs

- [Retrying a provider attempt may duplicate vendor-side work] -> Limit retries to failures classified as transient and keep retries opt-in.
- [Streaming retries could leak partial failed output] -> Buffer attempt-local streamed parts and discard them on failed attempts before transcript mutation.
- [Timeout semantics can be ambiguous for long-running streaming providers] -> Define timeout as a bounded per-attempt deadline for the entire provider attempt in the first tranche.
- [Richer exception metadata increases API surface] -> Add only the fields needed for retry policy and keep existing constructor behavior compatible.

## Migration Plan

1. Add the new reliability types and exception metadata in `agent_loop_core` and export them publicly.
2. Implement retry execution and retry lifecycle events in the core loop while preserving one-shot behavior when no policy is configured.
3. Update the Ollama provider to classify transient transport and HTTP failures into the normalized exception shape.
4. Update SDK, CLI, and examples to expose and exercise the policy surface.
5. Add focused tests first for one-shot compatibility, retry success, retry exhaustion, and non-retryable failures.

Rollback is low risk because the feature is additive and callers can return to `AgentReliabilityPolicy.none()` if retry behavior needs to be disabled.

## Open Questions

- Should HTTP 429 and server-side 5xx mapping live entirely in provider packages, or should the core library eventually publish shared helpers for common transport classifications?
- Should a future change add jitter once deterministic retry behavior is established, or is deterministic backoff sufficient for the intended SDK use cases?
