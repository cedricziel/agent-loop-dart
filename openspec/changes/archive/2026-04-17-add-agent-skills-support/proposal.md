## Why

The runtime now has profiles, delegation, permissions, and extensibility hooks, but it still cannot represent or discover portable agent skills in the way Claude Code, OpenCode, and pi do. Adding first-class skill types and SDK-level loading creates a minimal interoperability layer now, while keeping richer activation and execution semantics open for later changes.

## What Changes

- Add first-class core types for discovered and loaded agent skills so skills are modeled as part of the public runtime vocabulary instead of opaque harness configuration.
- Add SDK utilities for loading skills from known local filesystem locations using the Agent Skills directory format and `SKILL.md` metadata.
- Support standards-oriented and compatibility skill locations, including `.agents/skills`, `.claude/skills`, and `.opencode/skills`, with deterministic precedence across project and user scopes.
- Keep the initial scope limited to type modeling and loading/discovery; automatic activation, transcript injection, subagent execution, and skill-specific permissions remain follow-up work.

## Capabilities

### New Capabilities
- `agent-skills`: Core skill types and SDK loading/discovery for Agent Skills-compatible `SKILL.md` packages.

### Modified Capabilities

## Impact

- Affects `packages/agent_loop_core` public types and exports for skill metadata and loaded skill content.
- Affects `packages/agent_loop` SDK APIs by adding known-place skill loading utilities.
- Affects documentation and examples so callers understand which locations are scanned and how precedence works.
- Establishes the minimum substrate for later skill activation, permissions, and delegated execution work without forcing those behaviors into this tranche.
