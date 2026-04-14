## Why

Managed sessions now support long-lived conversations, branching, delegation, and persistence, but they still retain the full raw transcript forever. That makes real usage increasingly expensive and brittle as sessions grow, and it leaves a clear parity gap versus OpenCode- and PI-style runtimes that can compact older context without losing the conversation's working state.

## What Changes

- Add an explicit session context compaction capability that can replace older transcript segments with a durable summary checkpoint while preserving enough state for follow-up runs.
- Add managed-session APIs for inspecting whether a session can be compacted and for triggering compaction without forcing callers to rebuild session state themselves.
- Define how compacted sessions preserve recent transcript turns, summary text, and lightweight metadata so branching and reload behavior remain stable after compaction.
- Keep compaction opt-in and additive; existing sessions and stateless `run()` / `stream()` flows continue to work unchanged when compaction is not used.

## Capabilities

### New Capabilities
- `session-context-compaction`: Defines how long-lived managed sessions summarize older transcript state into reusable compacted context checkpoints.

### Modified Capabilities
- `managed-agent-sessions`: Add compaction-aware managed session behavior, including compacting a session and resuming later runs from compacted state.
- `conversation-sessions`: Extend persisted session state so resumed conversations can carry compacted summaries in addition to raw transcript turns.

## Impact

- Affects `packages/agent_loop_core` session state, managed-session APIs, transcript handling, and persistence boundaries.
- Affects `packages/agent_loop` public SDK exports and ergonomics for callers working with long-lived sessions.
- Affects CLI and example flows so compaction can be exercised and observed in a realistic local workflow.
- Introduces additive session metadata and summarization contracts that future provider-assisted summarizers or automatic compaction policies can build on.
