## Why

Tool execution results are currently flattened into plain text, which makes it hard for callers to inspect tool metadata, preserve non-text payload details, or render tool outcomes consistently across transcripts, event streams, and future provider integrations. This change is needed now because the repo already carries structured message parts and run events, but tool results remain the last major runtime artifact that loses structure at the public API boundary.

## What Changes

- Add a structured tool output model that can carry a text view plus typed metadata and optional structured content parts.
- Update loop transcript, run event, and session surfaces to retain structured tool outputs instead of only a single output string.
- Preserve compatibility for existing text-first flows by continuing to expose a deterministic text rendering for tool results.
- Update builtin tool implementations to emit structured results through the shared tool output contract rather than formatting everything up front as plain text.

## Capabilities

### New Capabilities
- `structured-tool-outputs`: Represent tool execution results as structured runtime data that can be stored, streamed, and rendered consistently while still providing a text fallback.

### Modified Capabilities
- `builtin-tools`: Builtin tools will return structured results through the shared tool output contract while preserving their current deterministic text view.
- `run-events`: Tool result events will carry structured tool output data so consumers can observe metadata and structured content without reparsing text.

## Impact

- Affected code in `packages/agent_loop_core`, especially `agent_tool.dart`, `agent_types.dart`, `agent_loop.dart`, and `builtin_tools.dart`.
- Public SDK exports in `packages/agent_loop` and `packages/agent_loop_core` will likely need updates for any new public result types.
- Example and CLI rendering paths may need small updates to display structured tool output cleanly.
- Provider integrations should remain largely unchanged because tool execution happens after provider responses are normalized.
