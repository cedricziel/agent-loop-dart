## Context

The runtime already has a durable pause-and-resume path for permission approvals on managed sessions. That machinery is close to what `ask_user` needs, but the semantics are different enough that it should not be modeled as approval with extra fields.

`ask_user` is triggered by a model tool call, yet it behaves like a human-interaction checkpoint rather than a normal environment tool. The model should invoke it as a tool, the runtime should pause instead of completing the tool immediately, and the eventual human answer should return to the model as the completed tool result for that specific call.

## Goals / Non-Goals

**Goals:**
- Let models ask structured human questions through a built-in `ask_user` tool.
- Preserve a stable, inspectable question request object in managed-session state.
- Block the current managed run until the question is answered or cancelled.
- Resume the same run by emitting an `ask_user` tool result tied to the original tool call.
- Support suggested options with descriptions while always leaving room for optional freeform human input.

**Non-Goals:**
- Building a generic form engine or arbitrary schema-driven questionnaire system.
- Replacing the existing permission approval flow.
- Reframing human answers as new top-level user messages in the transcript.
- Defining a stateless blocking-question flow outside managed sessions in this tranche.

## Decisions

### Decision: Keep the model trigger as a tool call

`ask_user` should appear to the model as an ordinary built-in tool definition so providers can expose it through the existing tool-calling surface. This keeps the model contract simple and avoids provider-specific side channels for asking humans questions.

Alternative considered: add a provider-agnostic non-tool control channel for question requests.
Why not: it would complicate provider integration and make question requests a special case outside the established tool-call model.

### Decision: Treat question handling as a managed-session pause, not normal tool execution

Although the model invokes `ask_user` as a tool, the runtime should not execute it like `read` or `bash`. Instead it should pause the active managed run, persist a pending question request, and wait for the caller to answer or cancel.

Alternative considered: execute `ask_user` immediately and require the caller to poll or inject answers later.
Why not: it would let the loop progress without the human answer and break the requirement that the current run blocks until resolved.

### Decision: Return the human answer as the `ask_user` tool result

When the caller answers a pending question, the runtime should synthesize the completed tool result for the original `ask_user` call and resume the paused run from that point. This preserves tool-call causality, transcript ordering, and compatibility with the model's existing expectation that tool calls produce tool results.

Alternative considered: inject the answer as a new user message.
Why not: it would weaken the connection to the original `ask_user` call and make the transcript less precise for replay, inspection, and event consumers.

### Decision: Keep the request structured, but treat freeform reply text as unstructured

The question request should carry structured suggested options with labels and descriptions, plus a `multiple` flag. The answer should preserve selected option identifiers as structured data while storing optional freeform user text as plain unstructured text rather than pretending it is machine-validated structure.

Alternative considered: make the answer fully structured through arbitrary schemas.
Why not: it would turn the capability into a form engine, complicate CLI rendering, and encourage downstream parsing of human language as if it were reliable structured data.

### Decision: Model pending question requests alongside, but separately from, approval requests

The runtime already persists `pendingApproval` state. `ask_user` should introduce a sibling pending-question concept with its own resolution and cancellation semantics rather than overloading approval-specific types.

Alternative considered: extend approval request types to cover user questions.
Why not: question requests are not binary allow/deny decisions, and cancellation is not the same as denial.

## Risks / Trade-offs

- [Interactive complexity grows in managed sessions] -> Keep the initial question model intentionally small: header, question, suggested options with descriptions, `multiple`, selected option ids, and optional freeform text.
- [CLI and UI consumers may overfit to options] -> Document that options are suggestions only and that freeform text remains the authoritative unstructured answer channel.
- [Question cancellation semantics may be ambiguous] -> Specify cancellation as terminating the paused question flow without fabricating a tool result.
- [Stateless loop callers may expect the same feature] -> Scope the initial capability to managed sessions and document that blocking question resolution requires a persisted run handle.

## Migration Plan

1. Add public request/answer models for interactive questions and export them through the SDK surface.
2. Introduce the built-in `ask_user` tool definition and intercept its execution inside managed-session pause/resume handling.
3. Extend session persistence and run events to carry pending question state and resolution/cancellation lifecycle reporting.
4. Update CLI/example flows to render structured questions and submit answers or cancellation.
5. Add verification coverage for pause persistence, answer resumption as tool result, and cancellation behavior.

Rollback is straightforward because the capability is additive: remove the built-in tool, pending-question types, and managed-session pause path together to restore the existing non-interactive behavior.

## Open Questions

- Should the initial API require stable option ids, or infer ids from labels when omitted?
- Should cancelling a pending question emit a dedicated terminal question-cancelled event, or reuse the existing run-cancelled surface?
- Should managed sessions allow callers to answer with freeform text only, with no selected options, in all cases?
