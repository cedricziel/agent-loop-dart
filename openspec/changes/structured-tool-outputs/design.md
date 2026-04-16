## Context

`agent_loop_core` already preserves structured assistant content through `MessagePart` and exposes structured run lifecycle events, but tool execution still crosses the runtime boundary as a single rendered string. That mismatch means the builtin tools already compute metadata internally, yet the public API discards it before the transcript, session state, and event stream can retain it.

This change crosses the core tool contract, transcript-bearing types, builtin tool implementations, and any consumer that renders tool results. It changes the public runtime data model, so a design document is warranted before implementation.

## Goals / Non-Goals

**Goals:**
- Introduce one shared structured tool output model for all tools.
- Preserve a deterministic text rendering so existing text-first callers continue to work.
- Store structured tool outputs in transcripts, sessions, and run events without forcing provider-specific logic into the loop.
- Reuse the same model for builtin tool success and failure payloads so metadata survives end to end.

**Non-Goals:**
- Changing provider-side tool call normalization or adding provider-specific tool result transport.
- Designing a bespoke result type for every builtin tool.
- Adding binary blob storage or durable artifact persistence for tool outputs in this tranche.
- Reworking the CLI into a richer interactive UI.

## Decisions

### Decision: Add a canonical `ToolOutput` model and keep `ToolResult` as the transcript envelope

The least disruptive option is to keep `ToolResult` as the object that ties a result back to a tool call while adding a nested structured payload object that becomes the source of truth. That lets the runtime preserve call identity and transcript ordering without replacing every result-bearing type at once.

Alternative considered: replace `ToolResult.output` with arbitrary maps or a top-level union.
Why not: it would weaken the public contract, make rendering inconsistent, and create broader API churn than necessary.

### Decision: Treat rendered text as a derived compatibility view, not the canonical payload

Structured tool outputs should include a stable text representation, but metadata and optional content parts must remain available as first-class fields. The loop, sessions, and events should carry the structured object; callers that only need text can keep using the rendered string view.

Alternative considered: keep string output canonical and ask consumers to reparse metadata from text.
Why not: it would preserve the current limitation and make event consumers depend on tool-specific formatting conventions.

### Decision: Extend the `AgentTool` contract to return structured output directly

Tools should produce the shared structured payload rather than returning raw strings that the loop has to reinterpret later. This keeps the execution boundary typed, lets custom tools participate in the same model as builtin tools, and avoids special cases where only builtin tools can expose metadata.

Alternative considered: keep `AgentTool.execute` returning `String` and bolt structured output onto builtin tools only.
Why not: it would split the tool ecosystem into incompatible result shapes and prevent custom tools from using the same transcript and event semantics.

### Decision: Reuse existing `MessagePart` support for optional structured tool content

Tool outputs should be able to carry ordered `MessagePart` items in addition to text and metadata. That keeps tool-generated files, text fragments, or future richer payloads aligned with the existing structured-content model instead of inventing a parallel representation just for tools.

Alternative considered: restrict tool outputs to text plus metadata only.
Why not: it would block parity with the runtime's structured content direction and force a second migration when tools need richer payloads later.

### Decision: Migrate builtin tools through a shared helper that builds `ToolOutput`

The builtin tool pack already has an internal `_BuiltinToolResult` with status, metadata, and sections. The implementation should evolve that helper into the public structured output shape so each builtin tool keeps one normalization path for success and failure.

Alternative considered: rewrite each builtin tool independently around ad hoc map payloads.
Why not: it would duplicate formatting logic and make it harder to preserve deterministic text output across tools.

## Risks / Trade-offs

- [Public API churn for custom tools] -> Keep the new result model small, additive where possible, and document the text rendering path for straightforward migrations.
- [Event and transcript consumers may accidentally keep reading only text] -> Make the structured payload the primary field on result-bearing types and update examples to read from it directly.
- [Metadata keys may become inconsistent across builtin tools] -> Preserve the existing deterministic key sorting and shared helper path so all builtin tools serialize text views uniformly.
- [Optional `MessagePart` payloads could blur the line between assistant and tool content] -> Scope them strictly to tool results and keep call/result envelopes unchanged in the transcript.

## Migration Plan

1. Add the public structured tool output types and update exports.
2. Update `AgentTool`, `ToolResult`, and result-bearing run event types to carry structured output plus a text compatibility view.
3. Refactor builtin tools to construct the shared tool output model without changing their existing rendered text semantics.
4. Update tests, examples, and CLI rendering to use structured outputs where appropriate.
5. Run repo verification and keep rollback simple by reverting the additive type and contract changes together.

Rollback is straightforward because the change is self-contained within the tool execution boundary and its consumers; reverting the new tool output model restores the prior string-only behavior.

## Open Questions

- Should the public compatibility string stay named `output`, or should `output` become structured and `text` become the explicit compatibility field?
- Which builtin tool metadata fields should be documented as stable API versus implementation detail?
- Should tool-generated `MessagePart` payloads be optional for all tools, or required whenever a tool returns non-text content?
