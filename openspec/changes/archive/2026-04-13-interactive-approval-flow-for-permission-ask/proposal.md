## Why

`AgentPermissionOutcome.ask` currently surfaces as an exception and terminates the in-flight run, which leaves callers without a built-in way to approve or reject the request and continue the same session. That blocks any realistic interactive approval UX for tool and subagent permissions even though the runtime already distinguishes `allow`, `ask`, and `deny`.

## What Changes

- Add a resumable approval flow for permission decisions that return `ask` instead of treating them as terminal exceptions only.
- Persist pending approval state on managed sessions so a caller can inspect, approve, deny, and resume after reloading a session.
- Extend run lifecycle events to surface approval-required, approval-resolved, and resumed execution states in order.
- Keep explicit exceptions available for low-level callers that still use direct loop APIs without managed session approval handling.

## Capabilities

### New Capabilities
- `interactive-approval-flow`: Managed sessions can pause on permission `ask` decisions, expose the pending approval request, and resume execution after the caller approves or denies it.

### Modified Capabilities
- `managed-agent-sessions`: Session metadata and persistence now include pending approval state so interactive runs can survive reloads.
- `run-events`: Run lifecycle events now include approval-required and approval-resolution progress for paused/resumed runs.
- `run-control`: Managed session run control now distinguishes paused-for-approval from cancelled or completed runs and allows an existing run to continue after approval.

## Impact

- Affects `packages/agent_loop_core` session management, runtime permission handling, run control, and event models.
- Affects the public SDK surface in `packages/agent_loop` where approval inspection and resolution APIs will be exposed.
- Affects the CLI demo so permission `ask` can demonstrate an interactive approve or deny prompt instead of failing silently.
