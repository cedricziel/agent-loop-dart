## Context

Today the repository has a deliberately small shape: `AgentLoop` owns a transcript of string-only messages, `AgentModel` exposes a single `respond` call, `AgentTool` executes string-returning tools, and `AgentLoopSdk` is a thin wrapper. That makes the code easy to understand, but it leaves three core product gaps versus an `opencode`-style SDK: there is no provider-facing adapter layer, no observable execution stream, and no way to continue a conversation from existing state.

These gaps are more foundational than retries, richer content parts, or advanced CLI ergonomics. If the project invests in those later features before it has provider, event, and session primitives, it risks reworking the core API twice.

## Goals / Non-Goals

**Goals:**
- Add a provider adapter contract that sits between `AgentLoop` and concrete model backends.
- Add a structured event model that allows callers to observe loop progress as it happens.
- Add a session-oriented entry point so runs can resume from prior messages.
- Keep the first tranche small enough to land without introducing unnecessary abstraction or package sprawl.

**Non-Goals:**
- Full multimodal content parts in this tranche.
- Automatic retry/backoff policy beyond the minimum provider failure surface needed for correctness.
- Durable persistence backends; this tranche only needs resumable state shape, not storage implementations.
- Broad CLI UX redesign beyond exercising the new primitives.

## Decisions

### 1. Introduce provider adapters as a first-class runtime boundary

The current `AgentModel.respond` API is too thin to express provider-specific concerns such as request metadata, tool-call encoding, or transport failures. The SDK should introduce a provider adapter abstraction in `agent_loop_core` and keep provider-specific translation behind that interface.

Why this over keeping `AgentModel` as-is:
- It creates one stable integration point for OpenAI-like backends instead of pushing provider details into each caller.
- It prevents the loop from learning provider-specific message or tool-call formats.

Alternative considered:
- Extend `AgentModel` directly with more optional parameters. Rejected because it would mix core orchestration concerns with provider transport concerns and make the public surface harder to evolve.

### 2. Model loop progress as typed events rather than callback-specific hooks

Instead of adding separate callback arguments for tool start, tool finish, or final output, the SDK should define a typed run event stream. The loop can emit events in order and the higher-level SDK facade can expose them as a `Stream` or equivalent subscription mechanism.

Why this over per-hook callbacks:
- It scales as new lifecycle stages are added.
- It gives CLI and library consumers the same observability model.
- It avoids a proliferation of constructor parameters on `AgentLoop` and `AgentLoopSdk`.

Alternative considered:
- Add optional callbacks to `run()`. Rejected because the API becomes brittle and uneven once there are more than a few event types.

### 3. Resume conversations by accepting explicit session state

The loop should support continuing from an existing transcript supplied by the caller, rather than owning all history internally. The core package should define the transcript/session shape and the SDK should expose an ergonomic way to pass prior state into a new run.

Why this over adding internal mutable sessions to `AgentLoopSdk`:
- It keeps core logic testable and deterministic.
- It avoids hidden state in the public facade.
- It lets consumers decide whether state lives in memory, on disk, or elsewhere.

Alternative considered:
- Add a stateful `AgentLoopSdk.chat()` object that mutates internal history. Rejected for the first tranche because it hides too much behavior and makes persistence harder to control.

### 4. Defer richer content parts until provider and session shapes stabilize

String-only content is a real gap, but it should not be the first investment. Provider adapters, eventing, and session state create the structural seams needed to add richer content later with less churn.

Why this sequencing works:
- Provider adapters define how richer content will travel to backends.
- Session state defines how richer content persists between runs.
- Run events define how richer content is surfaced to consumers.

## Risks / Trade-offs

- [New abstractions increase surface area] -> Keep the first adapter and event model minimal, and reuse existing types where possible.
- [Public API churn in `agent_loop`] -> Route new behavior through additive APIs first and avoid removing the current one-shot `run()` flow in the initial change.
- [Session support could imply persistence requirements] -> Keep persistence explicitly out of scope and accept caller-supplied state only.
- [Provider adapter work may tempt immediate provider-specific implementations] -> Land the abstraction and one demo-backed implementation first, then add real providers in follow-up changes.

## Migration Plan

1. Add the new core types and keep existing one-shot usage working.
2. Update the public SDK facade to expose the new additive APIs.
3. Update the CLI demo to exercise events and resumed transcripts.
4. Follow with provider-specific implementations after the abstraction is proven in the repo.

Rollback is straightforward because the initial tranche is additive; callers can continue using the existing `run(prompt: ...)` path if the new APIs need to be reverted.

## Open Questions

- Should provider adapters return a single normalized response type, or should streaming providers surface partial events directly into the run event stream?
- Should session state be represented as raw transcript messages only, or as a richer `AgentSession` wrapper that can grow metadata later?
- Should tool execution failures become structured events, structured tool results, or both?
