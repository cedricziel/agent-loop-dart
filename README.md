# agent-loop-dart

A small Dart monorepo for building agent loops in the style of the `opencode` SDK: a model adapter, a tool registry, and an orchestrator that keeps stepping until the model returns a final answer.

## Workspace layout

- `packages/agent_loop_core`: core loop abstractions and orchestration.
- `packages/agent_loop`: public SDK facade built on top of the core package.
- `packages/agent_loop_cli`: a small CLI that exercises the loop with a demo model and tool.

## Quick start

```bash
dart pub get
dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"
```

## Design

The initial scaffold keeps the responsibilities narrow:

- `AgentModel` describes a model backend that can either answer directly or request tool calls.
- `AgentTool` describes a callable tool with a JSON-like input schema and string output.
- `AgentLoop` owns the transcript, executes tool calls, and stops when the model emits a final response.
- `AgentLoopSdk` is the package-level entry point for consumers.

This is intentionally small, so the next iteration can add real provider adapters, streaming, retries, richer content parts, and persistent conversation state without undoing the basic package shape.
