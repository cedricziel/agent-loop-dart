## Why

The SDK now has the first foundational pieces of an `opencode`-style loop, but it still models every message as a single string and every tool result as a single string payload. Compared with the OpenCode SDK, that prevents callers from representing richer assistant output such as incremental text, reasoning, file attachments, and tool state transitions, so the next parity tranche should add a structured message-part model.

## What Changes

- Add a structured message-part capability so transcripts can contain typed parts instead of only flat string content.
- Add attachment-aware file parts so assistant and tool output can reference generated or inspected files without forcing everything into plain text.
- Extend run event behavior to emit structured part updates in transcript order, including partial assistant output and tool lifecycle state.
- Extend session behavior so resumed conversations preserve structured parts rather than collapsing prior state back into strings.
- Keep the current text-first flow working as an additive compatibility path while introducing the richer runtime model underneath it.

## Capabilities

### New Capabilities
- `rich-message-parts`: Defines typed transcript content for assistant, user, and tool activity, including text, reasoning, tool, and file parts.

### Modified Capabilities
- `provider-adapters`: Expand normalized provider responses so adapters can produce structured content parts and attachment metadata instead of text-only output.
- `run-events`: Expand lifecycle events so consumers can observe part-level updates and tool state transitions, not only coarse assistant and tool events.
- `conversation-sessions`: Expand resumable session state so prior conversations preserve structured parts and attachments across follow-up runs.

## Impact

- Affects `packages/agent_loop_core` transcript, response, tool result, and event types.
- Affects `packages/agent_loop` public exports and the ergonomics of `AgentLoopSdk` results and streams.
- Affects `packages/agent_loop_cli` so the demo can exercise structured parts and attachment-aware output.
- Introduces additive API surface that future parity work such as retries, richer provider features, and advanced tooling can build on.
