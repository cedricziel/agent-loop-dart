## Why

After the earlier OpenCode parity work, this repo now has provider adapters, resumable transcript state, run events, and rich message parts. The next clear gap versus both the OpenCode SDK and the PI framework is that our public surface is still just a thin `run()` and `stream()` wrapper, with no managed session object, no lifecycle control for active runs, and no higher-level way to branch or persist conversations without each caller rebuilding those concerns by hand.

## What Changes

- Add a managed session API in the public SDK so callers can create, load, and continue long-lived conversations through a stable session handle instead of passing raw transcript lists into each call.
- Add session branching so callers can fork a follow-up conversation from an earlier session state without mutating the original branch.
- Add run lifecycle control so active session runs can be observed and cancelled through the session handle instead of only consuming a terminal stream.
- Add a persistence boundary for saving and restoring managed sessions without baking storage policy into `AgentLoop` itself.
- Keep the current stateless `run()` and `stream()` entry points as additive compatibility APIs.
- Explicitly defer permissions, custom agent profiles, and full compaction workflows to follow-up changes once a managed session surface exists.

## Capabilities

### New Capabilities
- `managed-agent-sessions`: High-level SDK session handles for creating, resuming, branching, and persisting conversations.
- `run-control`: Session-scoped lifecycle control for observing active runs and cancelling them safely.

### Modified Capabilities
- `conversation-sessions`: Extend session behavior from caller-supplied transcript snapshots to SDK-managed conversation state that can be resumed through a stable session object.
- `run-events`: Extend lifecycle events so managed sessions can expose run start, cancellation, and session-scoped progress in addition to the existing transcript events.

## Impact

- Affects `packages/agent_loop_core` session, event, and orchestration types.
- Affects `packages/agent_loop` public SDK facade and exported API shape.
- Affects `packages/agent_loop_cli` so the demo can exercise managed sessions and cancellation.
- Introduces additive persistence abstractions for SDK-managed sessions without requiring a durable backend in the first implementation tranche.
