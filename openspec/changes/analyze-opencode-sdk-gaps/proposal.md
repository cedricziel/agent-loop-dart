## Why

The current SDK is a useful scaffold, but it is still a demo-grade loop rather than an `opencode`-style integration surface. The highest-value gaps are the lack of real provider adapters, the lack of observable run events, and the lack of resumable conversation state, so those are the best places to invest first.

## What Changes

- Define a first-class provider adapter capability so the SDK can target real model backends instead of only a demo `AgentModel` implementation.
- Define a run event stream so callers can observe assistant output, tool calls, tool results, and termination without polling the final result.
- Define conversation session support so callers can resume prior transcripts instead of being limited to one-shot prompts.
- Sequence these capabilities as the first investment tranche for the SDK, while explicitly deferring broader parity work such as richer content parts and advanced retry policies until these foundations exist.

## Capabilities

### New Capabilities
- `provider-adapters`: Standardize how the SDK integrates with real model providers, including tool-call translation and provider failures.
- `run-events`: Expose structured lifecycle events for loop execution, including model responses, tool execution, and final completion.
- `conversation-sessions`: Allow callers to start from prior transcript state and continue an existing conversation across multiple runs.

### Modified Capabilities

None.

## Impact

- Affects `packages/agent_loop_core` runtime interfaces and orchestration behavior.
- Affects `packages/agent_loop` public SDK facade and the public API surface exported to consumers.
- Affects `packages/agent_loop_cli` demo wiring so the CLI can exercise the upgraded SDK behavior.
- Establishes the roadmap and contract for the next implementation phase in OpenSpec.
