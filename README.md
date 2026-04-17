# agent-loop-dart

A small Dart monorepo for building agent loops in the style of the `opencode` SDK: a model adapter, a tool registry, builtin coding-agent tools, and an orchestrator that keeps stepping until the model returns a final answer.

## Workspace layout

- `packages/agent_loop_core`: core loop abstractions and orchestration.
- `packages/agent_loop`: public SDK facade built on top of the core package.
- `packages/agent_loop_cli`: a small CLI that exercises the loop with a demo model and tool.
- `packages/agent_loop_provider_anthropic`: optional Anthropic provider package built on the core adapter boundary.
- `packages/agent_loop_provider_ollama`: optional Ollama provider package built on the core adapter boundary.
- `packages/agent_loop_examples`: runnable examples, including Ollama-backed and Anthropic-backed loops.

## Quick start

```bash
dart pub get
dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"
```

To use the builtin coding-agent tools, pass `builtinToolOptions: BuiltinToolOptions(workspaceRoot: Directory.current)` when constructing `AgentLoopSdk`, or call `createBuiltinTools(...)` directly and pass the returned tools into a loop.

To discover Agent Skills-compatible packages from known local locations, call `discoverAgentSkills()` from the `agent_loop` package and load any selected skill with `loadAgentSkill(...)`:

```dart
import 'package:agent_loop/agent_loop.dart';

Future<void> main() async {
  final skills = await discoverAgentSkills();
  if (skills.isEmpty) {
    return;
  }

  final loaded = await loadAgentSkill(skills.first);
  print('${loaded.name}: ${loaded.instructions}');
}
```

The SDK currently scans these locations and returns skill metadata with deterministic precedence:

- project and ancestor directories up to the git root:
  `.agents/skills`, `.claude/skills`, `.opencode/skills`
- user directories:
  `~/.agents/skills`, `~/.claude/skills`, `~/.config/opencode/skills`

This tranche only models and loads skills. It does not automatically activate them inside `AgentLoop` or `AgentRuntime` yet.

To use a real provider, add an optional provider package such as `agent_loop_provider_anthropic` or `agent_loop_provider_ollama` rather than expecting `agent_loop` or `agent_loop_core` to carry provider-specific transport code.

To run the loop locally against Ollama:

```bash
OLLAMA_MODEL=gemma4:e4b dart run packages/agent_loop_examples/bin/local_loop.dart "Explain what this repo does."
```

To run the loop against Anthropic:

```bash
ANTHROPIC_API_KEY=... dart run packages/agent_loop_examples/bin/anthropic_loop.dart "Explain what this repo does."
```

## Design

The initial scaffold keeps the responsibilities narrow:

- `AgentModel` describes a model backend that can either answer directly or request tool calls.
- `AgentStreamingProvider` adds optional provider-side streaming without breaking non-streaming providers.
- `AgentTool` describes a callable tool with a JSON-like input schema and string output.
- `createBuiltinTools(...)` packages a first-party `read`, `glob`, `search`, `edit`, `apply_patch`, `bash`, and `webfetch` tool set behind that same surface.
- `AgentLoop` owns the transcript, executes tool calls, and stops when the model emits a final response.
- `AgentLoopSdk` is the package-level entry point for consumers.

The runtime now includes provider adapters, retries, rich message parts, managed sessions, and a builtin tool pack while keeping the package shape small and additive.
