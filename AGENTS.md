# AGENTS

## Workspace
- This repo uses Dart Pub Workspaces via the root `pubspec.yaml`; run `dart pub get` from the repo root, not separately inside each package.
- There is no `melos`, task runner, pre-commit config, or repo-local OpenCode config here. Prefer plain `dart` commands.

## Verification
- Match CI when verifying changes: `dart pub get`, `dart format --output=none --set-exit-if-changed .`, `dart analyze`, then `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`.
- There is currently no test suite and no `test/` directories; the CLI smoke run in CI is the only executable behavior check.

## Package Boundaries
- `packages/agent_loop_core` contains the real loop primitives and orchestration. `lib/src/agent_loop.dart` owns the transcript, tool execution, and `maxSteps` termination.
- `packages/agent_loop` is only the public facade: `lib/agent_loop.dart` re-exports `agent_loop_core` and `lib/src/sdk.dart` wraps `AgentLoop` as `AgentLoopSdk`.
- `packages/agent_loop_cli` is a demo app, not extra core logic. The actual CLI entrypoint is `bin/agent_loop.dart`; most behavior lives in `lib/src/run_cli.dart`.

## Public API
- If you add public SDK/core types, update the package export files (`packages/agent_loop/lib/agent_loop.dart` or `packages/agent_loop_core/lib/agent_loop_core.dart`). New files under `lib/src/` are not public by themselves.

## Repo Conventions
- Linting is just `package:lints/recommended` plus `avoid_print: false`, so CLI code may legitimately use `stdout`, `stderr`, and printing.
