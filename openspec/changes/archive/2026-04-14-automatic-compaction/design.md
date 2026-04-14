## Context

The repository already supports explicit managed-session compaction through persisted compaction metadata, a summary-backed materialized transcript view, and a pluggable summarizer boundary. That closes the first parity gap around bounded session history, but long-lived sessions still rely on callers to notice transcript growth and invoke compaction at the right time.

Automatic compaction is cross-cutting because it touches managed-session configuration, run orchestration, persisted session metadata, and lifecycle events. The design needs to preserve the current guarantees around explicit compaction, branching, approval pauses, delegation, and deterministic testing while adding policy-driven compaction behavior on top.

## Goals / Non-Goals

**Goals:**
- Add an opt-in automatic compaction policy for managed sessions.
- Reuse the existing compaction model and summarizer boundary instead of creating a second compaction path.
- Keep automatic compaction deterministic and observable so callers can test and inspect it.
- Ensure automatic compaction never runs while a session is in an unsafe state, such as an active run step or pending approval pause.
- Preserve compatibility for callers that do not opt in.

**Non-Goals:**
- Automatic compaction for stateless `run()` or `stream()` calls.
- Background workers, timers, or asynchronous compaction outside normal managed-session execution.
- A built-in provider-specific summarizer implementation.
- Full memory management policies such as retrieval, archival storage, or semantic search.

## Decisions

### 1. Model automatic compaction as persisted session policy

Automatic compaction should be configured on a managed session through a small policy object stored with the session state. The policy should define the trigger threshold, retained raw suffix, and summarizer to use when the threshold is crossed.

Why this over a global SDK-only setting:
- It lets different sessions opt into different behavior.
- It keeps branching and reload behavior deterministic because the policy travels with the session.
- It avoids hidden runtime behavior that is disconnected from persisted session state.

Alternative considered:
- Keep policy only on `AgentLoopSdk` or `AgentRuntime`. Rejected because loaded or branched sessions would lose their compaction behavior unless the caller reapplied out-of-band configuration.

### 2. Trigger automatic compaction synchronously at safe managed-session boundaries

The runtime should evaluate automatic compaction only at deterministic managed-session boundaries, such as after a run completes and before the updated session is persisted as the latest state for future prompts. It should not attempt to compact mid-step, during provider streaming, or while approval is pending.

Why this over opportunistic mid-run compaction:
- It avoids mutating session state while the loop is still producing transcript output.
- It preserves current run ordering and transcript semantics.
- It keeps failure handling simpler because compaction happens outside provider/tool execution for the active step.

Alternative considered:
- Trigger compaction immediately when transcript length crosses the threshold during a run. Rejected because it would interfere with event ordering and make the active run state harder to reason about.

### 3. Reuse the explicit compaction path instead of adding a parallel implementation

Automatic compaction should call the same managed-session compaction machinery used by the explicit API, including retained-suffix validation, summary materialization, and session persistence rules. The new behavior should only decide when to invoke compaction, not redefine what compaction means.

Why this over a separate automatic-only compactor:
- It prevents divergence between explicit and automatic session state.
- It keeps the test surface smaller and more reliable.
- It lets future compaction improvements automatically apply to both paths.

Alternative considered:
- Implement a lighter-weight automatic summarization flow that bypasses stored compaction metadata. Rejected because it would create two incompatible forms of compacted session state.

### 4. Introduce a session-scoped summarizer provider, not a serializable summarizer instance

The persisted policy should store configuration needed to resolve a summarizer at runtime, such as a summarizer id or strategy enum, while the actual summarizer implementation is supplied through a runtime registry. This keeps session state serializable without forcing function objects into persistence.

Why this over persisting a concrete summarizer object:
- Session stores need serializable data only.
- It allows deterministic test doubles and pluggable production summarizers.
- It avoids entangling persistence with runtime object graphs.

Alternative considered:
- Store the summarizer object directly on the session handle only. Rejected because reloaded sessions could not continue automatic compaction reliably.

### 5. Surface automatic compaction as explicit lifecycle events

The runtime should emit dedicated lifecycle reporting for automatic compaction decisions and successful compaction execution, including the triggering threshold and resulting compaction metadata. Skipped compaction due to guard conditions should remain inspectable through session state or non-terminal decision events rather than silently disappearing.

Why this over leaving automatic compaction implicit:
- It keeps the behavior debuggable for callers and CLI flows.
- It gives tests a stable way to assert when automatic compaction occurred.
- It matches the repo's existing preference for observable lifecycle transitions.

Alternative considered:
- Expose automatic compaction only through changed transcript state. Rejected because callers would have to infer why a session changed after a run.

## Risks / Trade-offs

- [Automatic compaction may surprise callers] -> Keep it opt-in, session-scoped, and observable through explicit lifecycle events.
- [Persisted policy introduces more session metadata] -> Use one compact policy object with a small serializable shape.
- [Summarizer lookup can fail on reload] -> Make missing summarizer resolution a clear runtime error and document that automatic compaction requires a matching runtime registry.
- [Compaction after every run could create churn] -> Require an explicit threshold policy and only evaluate at safe session boundaries.

## Migration Plan

1. Add policy and runtime resolution types for automatic compaction in `agent_loop_core` and export them publicly.
2. Extend managed-session persistence so sessions can save, reload, and branch with automatic compaction policy metadata.
3. Route policy checks through the existing managed-session compaction path at post-run safe points.
4. Add lifecycle events and public SDK/session APIs for configuring and observing automatic compaction.
5. Cover the behavior with focused tests first, then run repo-level format, analyze, and smoke verification.

Rollback remains straightforward because the feature is additive and opt-in. Disabling or removing automatic compaction leaves manual compaction intact and uncompacted sessions unaffected, while sessions with stored automatic-compaction policy can be treated as unsupported persisted state only if rollback happens before release.

## Open Questions

- Should the first policy trigger use transcript message count only, or also allow part count or serialized size thresholds?
- Should the runtime emit a dedicated event when compaction was considered but skipped because a guard blocked it, or is successful-compaction reporting enough for the first tranche?
- How should summarizer ids be registered through the public SDK so they remain ergonomic without introducing a heavy plugin system yet?
