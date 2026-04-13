## Context

The repository already has the first structural pieces of an `opencode`-style SDK: a provider boundary, resumable session state, and a run event stream. The remaining gap is that the runtime still treats messages and tool results as flat strings. That keeps the code simple, but it means the SDK cannot represent incremental assistant output, provider reasoning text, attachment references, or richer tool lifecycle state in a way that survives transcript storage and session resume.

This change crosses `agent_loop_core`, the public `agent_loop` facade, and the CLI demo. It also changes core data model expectations, so a design document is warranted before implementation.

## Goals / Non-Goals

**Goals:**
- Introduce a typed message-part model that can represent text, reasoning, tool activity, and file references.
- Preserve transcript and session continuity using structured parts rather than collapsing rich output back into strings.
- Expand provider normalization and run events so part-level updates flow through one consistent runtime model.
- Keep the current text-oriented entry points usable as an additive compatibility layer.

**Non-Goals:**
- Full OpenCode feature parity across sessions, PTYs, permissions, or server APIs.
- Durable attachment storage or file upload infrastructure beyond representing file references in the transcript.
- Advanced retry, compaction, or permission workflows.
- Rewriting the CLI into a TUI; it only needs enough support to exercise the richer model.

## Decisions

### 1. Keep `AgentMessage` as the transcript envelope and add typed parts inside it

The current transcript model already has stable message roles and is used throughout the loop, session, and result types. The least disruptive approach is to preserve the message envelope and introduce a `parts` collection that carries structured content.

Why this over replacing `AgentMessage` entirely:
- It keeps existing transcript ordering and role semantics intact.
- It allows an additive migration path for existing callers.
- It limits the number of public types that must change at once.

Alternative considered:
- Replace `AgentMessage.content` with a completely new top-level message union. Rejected because it would create larger public API churn for little benefit in this tranche.

### 2. Treat text as one part type, not as a separate compatibility system

Text should become a first-class `MessagePart` variant rather than staying as the only real payload while richer data lives somewhere else. That gives every provider and every consumer one canonical content model.

Why this over bolting on optional attachment fields:
- It keeps all content in one ordered sequence.
- It matches how richer OpenCode-style outputs evolve over time.
- It avoids special cases where text and non-text payloads drift apart.

Alternative considered:
- Add optional `attachments` and `reasoning` fields alongside `content`. Rejected because it would spread ordered assistant output across unrelated fields and make event streaming harder.

### 3. Normalize provider responses into complete part objects before mutating the transcript

Provider adapters should remain the single translation boundary. `AgentLoop` should only deal with normalized part types, normalized tool calls, and normalized failures, without learning provider-specific response shapes.

Why this over letting the loop build parts itself:
- It preserves the existing architectural separation between orchestration and provider transport.
- It keeps new providers easier to add later.
- It avoids leaking provider quirks into session and event handling.

Alternative considered:
- Let adapters return partial raw payloads and have the loop convert them. Rejected because it would make loop logic provider-aware again.

### 4. Emit part-level events while retaining a simple terminal result

The run stream should evolve to expose structured part updates and tool state transitions, because that is where callers get real-time observability. The final run result can still expose a simple terminal output for compatibility, derived from the structured transcript when needed.

Why this over only changing the final result:
- Streaming is where rich output matters most.
- It keeps transcript and event models aligned.
- It allows the CLI and future SDK consumers to react to intermediate structure instead of reconstructing it later.

Alternative considered:
- Only store parts in the final transcript and keep coarse events. Rejected because consumers would lose incremental semantics such as partial text and tool progress.

### 5. Represent file attachments as transcript references, not embedded file contents

This tranche should model file parts as references with metadata such as path, mime type, and optional labels. The transcript should not become a storage layer for binary payloads.

Why this over embedding file bytes:
- It keeps transcript objects small and serializable.
- It avoids introducing storage and transport concerns prematurely.
- It still provides enough structure for CLI rendering and session resume.

Alternative considered:
- Inline file content directly in transcript parts. Rejected because it couples runtime state to storage concerns and makes future persistence harder.

## Risks / Trade-offs

- [Public API growth in core transcript types] -> Keep the initial part taxonomy small and additive, and preserve text-oriented convenience access where possible.
- [Providers may not support every part type] -> Require adapters to emit only the parts they can prove and allow text-only normalization as the fallback path.
- [CLI output could become noisy or confusing] -> Add a minimal rendering strategy for file and tool parts without attempting a full TUI redesign.
- [Compatibility helpers may hide the canonical model too long] -> Document that parts are the source of truth and treat derived string output as transitional.

## Migration Plan

1. Add the new part types and extend transcript-bearing core types to carry them.
2. Update provider normalization to emit structured parts while preserving text-only fallback behavior.
3. Update the run event stream and result model to surface part-level activity.
4. Update the public SDK facade and exports.
5. Update the CLI demo and add focused tests before broad verification.

Rollback remains straightforward because the initial implementation is additive: callers can continue using text-oriented flows while the richer model is introduced underneath.

## Open Questions

- Should the compatibility `output` string include only final assistant text parts, or also summarize file and tool parts for text-only callers?
- Should reasoning parts be preserved in every transcript by default, or be optional depending on provider support and caller configuration?
- Should file parts point only to local workspace paths, or also support remote URLs in the first tranche?
