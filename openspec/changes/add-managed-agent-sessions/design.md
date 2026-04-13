## Context

The current repository has the lower-level building blocks that earlier OpenCode parity work called for: normalized providers, resumable transcript/session snapshots, structured message parts, and a run event stream. What it does not have is the higher-level runtime surface that both OpenCode and PI expose to SDK consumers.

Today `AgentLoopSdk` is a very small facade around `AgentLoop`. Callers must hold transcript state themselves, decide how to persist it, and build any long-lived session lifecycle on top of `run()` or `stream()`. That is workable for a demo loop, but it means common workflows such as reopening a conversation, branching from a prior point, or cancelling an active run all require custom integration code outside the SDK.

This change crosses `agent_loop_core`, the public `agent_loop` package, and the CLI demo. It also changes the public SDK ergonomics, so a design document is warranted before implementation.

## Goals / Non-Goals

**Goals:**
- Add a managed session handle API that gives SDK consumers a stable object for long-lived conversations.
- Allow managed sessions to be created, reopened, and branched without exposing storage policy inside `AgentLoop`.
- Add explicit run lifecycle control for managed sessions, including cancellation and session-scoped identifiers in emitted events.
- Preserve the current stateless `run()` and `stream()` flow as an additive compatibility path.

**Non-Goals:**
- Durable database-backed persistence or sync across machines.
- Permission prompts, custom agent profiles, or subagent orchestration.
- Full context compaction and summarization workflows.
- Multi-run concurrency inside a single session; the first tranche only needs one active run per session.

## Decisions

### 1. Introduce a stateful `ManagedAgentSession` on top of the existing core loop

The new surface should live above `AgentLoop`, not replace it. `AgentLoop` remains the deterministic orchestrator over explicit transcript state, while `ManagedAgentSession` becomes the convenience layer that owns mutable session metadata and delegates each prompt to the core loop.

Why this over making `AgentLoop` itself stateful:
- It preserves the testable core shape that the repo already has.
- It keeps the public ergonomic layer separate from the low-level orchestration API.
- It allows callers to keep using explicit transcript-driven flows when they do not want SDK-managed state.

Alternative considered:
- Add mutable session state directly to `AgentLoopSdk`. Rejected because it would blur the boundary between a stateless facade and the core runtime, and it would make future persistence or branching harder to factor cleanly.

### 2. Model persistence as a small session store boundary

Managed sessions should save and restore through an interface such as `AgentSessionStore`, with a default in-memory implementation for tests and demo use. The store persists SDK-managed session envelopes, not arbitrary loop internals.

Why this over writing files directly from the session object:
- It keeps storage policy out of the runtime surface.
- It allows tests to use deterministic in-memory stores.
- It gives the CLI a simple path to exercise persistence without forcing one backend onto library users.

Alternative considered:
- Postpone persistence entirely and only keep managed sessions in memory. Rejected because create/load semantics are a central reason to add a managed session API in the first place.

### 3. Use branch-by-copy semantics for session branching

Branching should create a new managed session with its own session identifier and a copied transcript baseline from the source branch. The source branch remains unchanged after the fork.

Why this over shared mutable history:
- It is simple to reason about.
- It matches the common mental model from OpenCode and PI session trees without needing full tree storage in the first tranche.
- It avoids subtle bugs where two active handles unexpectedly mutate the same transcript.

Alternative considered:
- Introduce parent/child tree nodes with shared storage immediately. Rejected because it adds storage and indexing complexity before the SDK proves the higher-level session handle API.

### 4. Represent active runs with explicit cancellation state and per-session serialization

Each managed session should allow at most one active run at a time. A run receives a generated run identifier and an `AbortController`-like cancellation path. Starting a second run while one is active should fail fast with a structured SDK error instead of silently queuing work.

Why this over queuing subsequent runs:
- It keeps the first implementation deterministic and small.
- It matches the existing loop shape, which assumes one transcript mutation flow at a time.
- It avoids hidden scheduling behavior in the public API.

Alternative considered:
- Built-in queuing per session. Rejected because queued runs raise ordering, cancellation, and persistence questions that are unnecessary for the first managed-session tranche.

### 5. Extend run events with session and run metadata instead of inventing a second event system

Managed sessions should still emit the same core lifecycle stream, but events need enough metadata to identify the owning session and active run. Additive event types for run start and run cancellation fit better than a separate callback-only API.

Why this over dedicated callbacks on `ManagedAgentSession`:
- It keeps event observability consistent with the existing `run-events` capability.
- It avoids two parallel models for tracking loop progress.
- It gives the CLI and future SDK consumers one event vocabulary.

Alternative considered:
- Expose `onStart`, `onCancel`, and `onComplete` callbacks only on managed sessions. Rejected because that fragments the API and forces callers to combine callbacks with streams.

## Risks / Trade-offs

- [Public API grows noticeably] -> Keep the first session handle API minimal: create, load, branch, prompt/stream, abort, and inspect transcript state.
- [Persistence shape could ossify too early] -> Persist only stable session envelope fields such as session id, parent id, transcript, and lightweight metadata.
- [Cancellation semantics may differ across providers] -> Treat cancellation as a best-effort run termination boundary and document that provider transport may stop at the next awaitable boundary.
- [Branching without full trees may be limiting] -> Include parent session identifiers in stored metadata so tree-aware storage can be added later without breaking the branch contract.

## Migration Plan

1. Add core managed-session and persistence abstractions behind additive exports.
2. Extend event types with session/run metadata and cancellation terminal states.
3. Add the public SDK managed-session facade while keeping current stateless APIs working.
4. Update the CLI demo to create, resume, and cancel a managed session run.
5. Verify with focused tests first, then the repo-level format/analyze/smoke commands.

Rollback is straightforward because the existing stateless SDK entry points remain intact. If the managed session layer needs to be reverted, callers can continue using explicit transcript-based runs.

## Open Questions

- Should aborted runs return a distinct terminal result type, or should cancellation only surface through events and thrown errors?
- How much session metadata should be public in the first tranche beyond `id`, optional `parentId`, and transcript state?
- Should the default CLI persistence store be ephemeral in-memory state or a small file-backed store under the workspace?
