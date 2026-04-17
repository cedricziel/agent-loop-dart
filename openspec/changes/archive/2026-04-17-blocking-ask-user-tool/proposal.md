## Why

The SDK already supports model-driven tool calls and managed-session pauses for approval, but it has no first-class way for a model to stop and request structured human input before continuing. In practice this forces callers to either overload binary approval prompts, invent ad hoc out-of-band UI flows, or let the model guess when it should have asked a human.

This change is needed because the runtime already has most of the necessary control flow for pausing and resuming a managed run, and the recent structured tool output work gives the SDK a natural place to deliver the human answer back to the model as a tool result rather than flattening it into an unrelated user message.

## What Changes

- Add a built-in blocking `ask_user` tool that lets the model present a structured question with a header, question text, suggested options, and per-option descriptions.
- Make `ask_user` pause the active managed-session run until the caller either supplies an answer or cancels the request.
- Return the human answer to the model as the `ask_user` tool call result, preserving structured selected options plus optional unstructured freeform text.
- Extend managed-session and run-event surfaces so callers can inspect, persist, answer, or cancel pending question requests.

## Capabilities

### New Capabilities
- `interactive-user-questions`: Models can request structured human input through a blocking built-in tool that pauses the current managed run until resolved.

### Modified Capabilities
- `managed-agent-sessions`: Managed sessions persist and resume pending interactive question requests in addition to approval pauses.
- `run-events`: Managed-session event streams expose question-required and question-resolved lifecycle reporting around paused interactive questions.
- `builtin-tools`: The built-in tool set includes `ask_user` as an interactive collaboration tool.

## Impact

- Affected code in `packages/agent_loop_core`, especially the builtin tool registry, managed-session pause/resume flow, transcript-bearing runtime types, and run events.
- Public SDK exports in `packages/agent_loop` and `packages/agent_loop_core` will need updates for question request and answer types.
- CLI/example rendering paths will need a question prompt flow rather than only binary approval prompts.
- Stateless loop execution may remain unsupported for blocking questions unless a separate non-managed resolution surface is designed later.
