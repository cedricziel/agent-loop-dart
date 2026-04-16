## 1. Core Builtin Tool Framework

- [x] 1.1 Add a builtin tool factory and shared runtime options in `packages/agent_loop_core` for workspace, timeout, and HTTP/shell configuration.
- [x] 1.2 Add focused core tests that define the expected tool registration surface and workspace-boundary behavior before implementation.

## 2. Read/Search Tooling

- [x] 2.1 Implement `read`, `glob`, and `search` builtin tools with normalized text results and workspace-root enforcement.
- [x] 2.2 Add tests covering successful reads/searches, workspace escape rejection, and result truncation or metadata behavior where applicable.

## 3. File Mutation Tooling

- [x] 3.1 Implement `edit` and `apply_patch` builtin tools with explicit changed/unchanged and failure outcomes.
- [x] 3.2 Add tests covering successful edits, patch failures, and no-write behavior when mutations cannot be applied.

## 4. Command And Network Tooling

- [x] 4.1 Implement `bash` and `webfetch` builtin tools with timeout handling, deterministic text-first results, and stable metadata fields.
- [x] 4.2 Add tests covering successful command execution, timeout failures, fetch truncation, and unsupported content handling.

## 5. Public API And CLI Integration

- [x] 5.1 Expose the builtin tool pack through the public `packages/agent_loop` exports and any SDK convenience surface needed to enable it.
- [x] 5.2 Wire the demo CLI to use the builtin tool pack and update any user-facing docs or examples that reference manual tool setup.

## 6. Verification

- [x] 6.1 Run `dart pub get`, `dart format --output=none --set-exit-if-changed .`, and `dart analyze`.
- [x] 6.2 Run `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"` as the final smoke check.
