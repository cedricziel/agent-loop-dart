## 1. Core Skill Types

- [x] 1.1 Add failing core tests that define the public discovered-skill and loaded-skill type surface expected by callers.
- [x] 1.2 Implement and export first-class skill types from `packages/agent_loop_core` for discovered metadata and fully loaded skill content.

## 2. Skill Parsing And Discovery

- [x] 2.1 Add failing SDK tests for parsing `SKILL.md` metadata, skipping entries missing required metadata, and loading full instruction bodies.
- [x] 2.2 Implement SDK parsing helpers for Agent Skills-compatible `SKILL.md` files and full-content loading.

## 3. Known-Place Loading

- [x] 3.1 Add failing SDK tests for discovering skills from `.agents/skills`, `.claude/skills`, `.opencode/skills`, `~/.agents/skills`, `~/.claude/skills`, and `~/.config/opencode/skills`.
- [x] 3.2 Implement the known-place skill loader utility with project-local ancestor scanning up to the git root.

## 4. Precedence And Public API

- [x] 4.1 Add failing SDK tests for deterministic duplicate-name resolution, including project-over-user precedence and stable same-scope ordering.
- [x] 4.2 Implement precedence resolution and expose the explicit SDK loading entry point for callers.
- [x] 4.3 Update public exports, docs, and any examples that should show explicit skill loading before runtime use.

## 5. Verification

- [x] 5.1 Run `dart pub get`, `dart format --output=none --set-exit-if-changed .`, and `dart analyze`.
- [x] 5.2 Run `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"` as the final smoke check.
