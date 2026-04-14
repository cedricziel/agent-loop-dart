## Why

Managed sessions can now be compacted explicitly, but long-lived conversations still grow until a caller notices and invokes compaction manually. That leaves an important OpenCode and PI gap: the runtime cannot proactively keep session context bounded, so real usage remains more expensive and brittle than it needs to be.

## What Changes

- Add an opt-in automatic compaction policy for managed sessions so the SDK can compact older context before transcript growth becomes problematic.
- Add managed-session configuration for deciding when automatic compaction should run, how much recent raw history to retain, and which summarizer to use.
- Ensure automatic compaction respects existing run, branching, persistence, and approval semantics instead of compacting at unsafe times.
- Surface automatic compaction decisions and outcomes through session metadata and lifecycle events so callers can observe when the runtime compacted context automatically.

## Capabilities

### New Capabilities
- `automatic-session-compaction`: Defines opt-in policy-driven compaction for managed sessions, including triggers, guards, and observable outcomes.

### Modified Capabilities
- `session-context-compaction`: Extend compaction behavior from manual-only operation to support runtime-triggered compaction using the existing compaction model.
- `managed-agent-sessions`: Add session-level configuration and lifecycle behavior for automatic compaction in long-lived managed conversations.
- `run-events`: Add observable events or equivalent lifecycle reporting for automatic compaction decisions and completed compaction work.

## Impact

- Affects `packages/agent_loop_core` managed-session state, compaction orchestration, and event types.
- Affects `packages/agent_loop` public SDK APIs for creating sessions with automatic compaction behavior.
- Affects CLI and example flows so automatic compaction can be exercised and inspected during long-running sessions.
- Builds on the existing summarizer boundary rather than introducing provider-specific compaction logic into the core loop.
