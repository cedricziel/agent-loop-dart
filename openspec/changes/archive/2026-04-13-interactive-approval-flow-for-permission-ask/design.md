## Context

The runtime already evaluates permission policies for tools and subagent delegation and distinguishes `allow`, `ask`, and `deny`. Today, however, an `ask` decision only surfaces as `AgentApprovalRequiredException`, which means managed session callers cannot inspect a pending request, persist it, approve it later, or resume the interrupted run. In practice, `ask` behaves like a hard stop rather than an interactive approval boundary.

This change is cross-cutting because it touches low-level loop/runtime permission handling, managed session persistence, run control, public SDK APIs, and the CLI demo. The design must preserve the existing low-level exception-based behavior for direct loop callers while adding a first-class managed-session approval workflow.

## Goals / Non-Goals

**Goals:**
- Let managed sessions pause on permission `ask` outcomes instead of losing the run context.
- Persist a structured pending approval request so callers can inspect and resolve it after reloading a session.
- Resume the paused run after approval without re-asking the model for the interrupted turn.
- Surface approval lifecycle events in-order alongside the existing run event stream.
- Keep direct `AgentLoop` and low-level runtime APIs additive so existing exception-oriented callers do not break.

**Non-Goals:**
- A rich TUI or GUI approval experience beyond a simple CLI prompt/demo flow.
- Multi-request approval queues within a single session; the first tranche only needs one pending approval at a time because managed sessions already serialize runs.
- Arbitrary policy editing, approval delegation, or long-lived audit storage beyond what the current session store keeps.
- Replacing the existing `AgentPermissionEvent` or low-level permission exceptions.

## Decisions

### 1. Managed-session APIs become approval-aware, but `AgentLoop` stays exception-oriented

The low-level loop will continue to represent `ask` as an approval-required interruption, while managed sessions and the SDK layer will convert that interruption into paused session state plus explicit resolve APIs.

Why this over changing `AgentLoop` to swallow `ask` globally:
- It keeps the primitive loop small and usable for callers that want full manual control.
- It avoids forcing stateless callers into a persistence or approval API they do not need.
- It limits the interactive approval contract to the layer that already owns session lifecycle and persistence.

Alternative considered:
- Make all loop entrypoints return a union result instead of throwing on `ask`. Rejected because it would widen the primitive API substantially and push approval concerns into simple one-shot usage.

### 2. Represent paused work as a serializable pending-approval checkpoint on `AgentSession`

Managed sessions will persist a single structured pending approval record that includes the run id, permission decision, the blocked operation kind, and the minimum continuation payload needed to finish the interrupted step.

For tool approvals, the checkpoint must include the blocked `ToolCall` and the transcript snapshot immediately before tool execution. For subagent approvals, it must include the delegated profile id and prompt. Because managed sessions already allow only one active run, a single pending approval slot is sufficient for the first tranche.

Why this over keeping only an in-memory callback/closure:
- Session reload must preserve the approval request.
- Serializable data is testable and store-agnostic.
- The existing session store already persists `AgentSession`, so adding approval metadata fits the current architecture.

Alternative considered:
- Keep continuation state only in memory and fail if the process restarts. Rejected because it undermines the main value of managed sessions.

### 3. Resume from captured continuation state, not by replaying the model turn

Approving a pending request must continue from the blocked operation rather than invoking the model again for the same turn. The implementation should therefore add an internal continuation path that can execute the approved tool or delegation request and then re-enter the loop with the saved transcript checkpoint.

Why this over simply rerunning the original prompt:
- Replaying the model turn can duplicate reasoning, emit different tool calls, or drift entirely because model output is not guaranteed to be deterministic.
- It would make approval semantics dependent on provider stability rather than the captured request.
- It would be much harder to assert event ordering and transcript correctness.

Alternative considered:
- Reconstruct the turn by rerunning `AgentLoop.run` with the existing transcript. Rejected because it cannot guarantee that the resumed work matches the originally blocked request.

### 4. Approval lifecycle uses additive event types alongside existing permission events

The runtime should keep emitting `AgentPermissionEvent` for every evaluated decision, and add explicit approval lifecycle events for pause and resolution. The new events should carry the same session/run/agent metadata as other managed-session events and remain ordered relative to tool/delegation work.

Expected flow for an `ask` tool decision:
- emit `AgentPermissionEvent(decision: ask)`
- emit `AgentApprovalRequiredEvent(...)`
- persist pending approval and stop the stream without emitting a tool call/result
- when resolved, emit `AgentApprovalResolvedEvent(...)`
- if approved, continue normal tool and assistant events on the same run id
- if denied, end the paused run without executing the blocked operation

Why this over encoding everything into `AgentPermissionEvent` only:
- Consumers need to distinguish policy evaluation from a session entering a paused approval state.
- Resolution is a separate lifecycle step from evaluation.
- It keeps event handling explicit for CLI/demo consumers.

Alternative considered:
- Reuse only `AgentPermissionEvent` with extra fields. Rejected because it conflates evaluation, pause, and resolution phases into one overloaded event type.

### 5. Pending approval keeps exclusive ownership of the run until resolved

A managed session with a pending approval will continue to reserve its run slot. Callers must approve, deny, or explicitly clear the paused run before starting another prompt on the same session.

Why this over allowing a new run while approval is pending:
- The blocked continuation is part of an already-started run and should not be interleaved with unrelated transcript mutations.
- It matches the current single-active-run concurrency model.
- It avoids ambiguous behavior if the transcript changes before the blocked operation resumes.

Alternative considered:
- Auto-cancel the paused run when a new prompt arrives. Rejected because it makes approval behavior implicit and easy to lose by accident.

## Risks / Trade-offs

- [Continuation payload becomes too broad] -> Limit the first tranche to one blocked operation at a time and only capture the minimal fields needed for tool execution or delegation resume.
- [Paused run semantics feel different from existing cancellation semantics] -> Add explicit approval-required and approval-resolved events plus clear session APIs so callers can distinguish the states.
- [Low-level and managed-session behavior diverge] -> Keep the divergence intentional and documented: low-level calls still throw, managed sessions add persistence and resolution on top.
- [Session store implementations need updates] -> Keep approval metadata inside `AgentSession` so existing store interfaces remain unchanged.

## Migration Plan

1. Add approval checkpoint data types and extend `AgentSession` to persist pending approval metadata.
2. Extend the loop/runtime internals to surface enough continuation state when a permission `ask` interrupts tool execution or delegation.
3. Add managed-session APIs to inspect pending approval, approve it, deny it, and resume the paused run.
4. Add approval lifecycle events and annotate them with managed-session metadata.
5. Expose the new approval APIs through `package:agent_loop` exports and wire the CLI demo to prompt interactively.
6. Cover the change with TDD-first tests for tool approval, delegation approval, persistence/reload, event ordering, and run exclusivity.

Rollback remains straightforward because the new behavior is additive at the SDK/session layer. If needed, callers can fall back to the existing exception-based permission handling by using the lower-level loop/runtime entrypoints.

## Open Questions

- Should denying a pending approval emit a dedicated terminal run event in addition to `AgentApprovalResolvedEvent`, or is the resolution event enough for the first tranche?
- Should `abort()` be allowed to cancel a paused-for-approval run, or should callers be required to deny/resolve it explicitly?
- Do we want a single generic `resolvePendingApproval(bool approved)` API, or explicit `approvePendingPermission()` / `denyPendingPermission()` methods for clarity?
