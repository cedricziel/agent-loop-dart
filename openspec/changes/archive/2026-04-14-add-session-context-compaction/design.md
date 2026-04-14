## Context

The repository now has the higher-level runtime pieces that earlier OpenCode and PI parity work required: managed sessions, resumable transcript state, branching, permission-aware approval pauses, delegation, and retry-aware provider execution. What it still lacks is any way to shrink long-lived session state once a conversation becomes large.

Today every managed session persists its full transcript in `AgentSession.transcript`, and every follow-up run replays that full history back into the loop. That keeps the implementation simple, but it means conversation cost and prompt size grow monotonically. The managed-session design explicitly deferred compaction and summarization, so this change needs to add that capability without undermining the current session, branching, and persistence contracts.

This work crosses `agent_loop_core`, the public `agent_loop` package, and the CLI/examples surface. It also changes stored session shape and how resumed runs reconstruct provider-facing context, so the design should make those decisions explicit before implementation.

## Goals / Non-Goals

**Goals:**
- Add an explicit, opt-in compaction flow for managed sessions.
- Preserve a stable conversation experience after compaction by retaining recent raw turns and a durable summary of older turns.
- Keep compaction independent from any one model provider by introducing a small summarizer boundary.
- Preserve existing branching, reload, and approval semantics after a session has been compacted.

**Non-Goals:**
- Automatic background compaction or policy-driven compaction thresholds.
- Provider-specific summarization logic baked directly into `AgentLoop`.
- Full semantic memory, retrieval, or vector indexing.
- Compaction for stateless transcript-only `run()` / `stream()` entry points.

## Decisions

### 1. Store compaction as session metadata, not as irreversible transcript rewriting

Compacted state should live in a dedicated `AgentSession` metadata field rather than replacing older history with a fabricated assistant or system message inside the persisted transcript itself. The stored session keeps only the uncompacted recent suffix in `transcript`, while compaction metadata records the summary text and the amount of history it replaced.

Why this over mutating the transcript with a synthetic summary message:
- It keeps persisted transcript entries truthful to actual runtime messages.
- It makes compaction observable and reversible at the session-envelope level.
- It avoids mixing summary bookkeeping with user-visible conversation history.

Alternative considered:
- Rewrite the stored transcript by swapping older turns for a generated system message. Rejected because it blurs real transcript data with runtime-derived summaries and makes later evolution of compaction metadata harder.

### 2. Materialize compacted context at run time through a synthetic summary prefix

When a compacted managed session starts a new run, the runtime should build a provider-facing transcript view that includes the session's existing leading system prompt, then a synthetic system summary message derived from the compaction metadata, then the recent raw suffix and the new user prompt. This lets the core loop continue working with ordinary `AgentMessage` values while keeping stored session state compact.

Why this over teaching providers a brand-new compacted message type:
- It preserves the current provider adapter contract.
- It keeps the core loop changes localized to session materialization.
- It allows the summary to be expressed in a role providers already understand.

Alternative considered:
- Add a new transcript part or provider-only message role for compacted summaries. Rejected because it would force broader provider and transcript API churn for a capability that can be represented with existing message shapes.

### 3. Introduce a dedicated summarizer boundary for compaction

Compaction should depend on a small interface such as a session compactor/summarizer that receives the candidate historical transcript segment and returns summary text plus any optional metadata the session should persist. Managed sessions use that boundary when callers explicitly trigger compaction.

Why this over hard-coding a built-in summarization algorithm:
- It keeps the runtime provider-agnostic.
- It supports deterministic test doubles and simple local heuristics.
- It leaves room for future provider-assisted summarizers without changing the managed-session API again.

Alternative considered:
- Reuse the active session provider to summarize history automatically. Rejected because it couples compaction behavior to the current model configuration and complicates failure handling, permissions, and deterministic testing.

### 4. Compact only a prefix and always preserve a recent raw suffix

The compaction API should operate on a prefix of the conversation and require that a caller preserve at least a configurable recent suffix of raw messages. The session store then saves the summary plus only the preserved suffix as the remaining transcript.

Why this over full-session summarization:
- It keeps recent tool interactions and assistant wording available for near-term follow-up turns.
- It lowers the risk of summary drift across short-running conversations.
- It matches the practical goal of bounding growth rather than replacing the full transcript with one summary blob.

Alternative considered:
- Replace the entire transcript with one summary. Rejected because it would lose too much near-term context and make post-compaction behavior much less predictable.

### 5. Branches inherit the compacted session state exactly as stored

Branching should copy both the current raw suffix and any compaction metadata from the source session. A branch starts from the source session's already-compacted state rather than attempting to re-expand or re-summarize history.

Why this over reconstructing raw history for branches:
- It preserves the existing branch-by-copy mental model.
- It avoids needing a second hidden archive of compacted-away messages.
- It keeps branch creation cheap and deterministic.

Alternative considered:
- Retain compacted-away raw history in a hidden store for branch reconstruction. Rejected because that would defeat the storage-reduction goal of compaction and introduce new persistence complexity.

## Risks / Trade-offs

- [Summary quality can drift from the original history] -> Keep compaction explicit, preserve a raw recent suffix, and make the summarizer pluggable so callers can choose an appropriate strategy.
- [Synthetic summary context may interact poorly with existing system prompts] -> Always place the summary after any original system prompt and define a stable summary envelope format.
- [Session persistence shape becomes more complex] -> Add one dedicated compaction metadata object instead of several loosely related fields.
- [Callers may compact too aggressively] -> Expose a guard such as `canCompact` and require a minimum retained suffix in the API contract.

## Migration Plan

1. Add session compaction metadata types and managed-session APIs behind additive exports.
2. Add a compaction boundary and materialized transcript reconstruction for compacted sessions.
3. Extend the session store and persistence tests to save and reload compacted state.
4. Add public SDK and CLI/example coverage for explicit compaction flows.
5. Verify with focused tests first, then repo-level format, analyze, and CLI smoke commands.

Rollback is straightforward because compaction is additive and opt-in. Reverting the feature would leave existing uncompacted sessions unchanged, while compacted sessions could be treated as unsupported persisted state only if the change were rolled back before release.

## Open Questions

- Should the first API expose only summary text, or should it also allow lightweight structured metadata such as key facts or tool outputs?
- Should compaction skip sessions with pending approvals entirely, or merely reject compaction while an approval is outstanding?
- Does the CLI need a dedicated demo command for compaction in the first tranche, or is SDK-level test coverage plus a minimal example enough?
