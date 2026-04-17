## Context

The repository already ships repo-local skills for external harnesses such as OpenCode and Claude, but the Dart runtime itself has no first-class notion of an agent skill. Today a caller can configure profiles, permissions, hooks, and tools, yet skills remain out-of-band filesystem content with no public type model and no SDK loader for discovering them from the common Agent Skills locations.

This change intentionally targets the minimum useful layer. It should make skills visible to Dart callers as data and provide a standard loader for known locations, while avoiding premature decisions about activation, transcript injection, subagent execution, or skill-specific permission semantics.

## Goals / Non-Goals

**Goals:**
- Add public core types that represent discovered skill metadata and fully loaded skill content.
- Add SDK utilities for loading skills from known local filesystem locations.
- Support the portable `.agents/skills` convention plus pragmatic compatibility locations for `.claude/skills` and `.opencode/skills`.
- Define deterministic precedence between project and user scopes so callers get stable results.
- Keep the API explicit so callers can load skills first and then decide how to expose or activate them.

**Non-Goals:**
- Automatic skill activation inside `AgentLoop` or `AgentRuntime`.
- A built-in `skill` tool or slash-command invocation surface.
- Claude-specific frontmatter extensions such as forked execution, shell interpolation, or invocation controls.
- A remote registry, package manager, or live file watching.

## Decisions

### 1. Model skills as public core data types

`agent_loop_core` should define the shared skill vocabulary because skills are part of the runtime contract, not just an SDK implementation detail. The minimum useful split is between discovered metadata and loaded content.

Why this over keeping skills entirely in the SDK package:
- It lets callers and future providers reason about skills using stable public types.
- It avoids encoding skill metadata as untyped maps or SDK-private classes.
- It creates a clean substrate for later activation or permission work without requiring another core API addition.

Alternative considered:
- Keep skills as SDK-only loader results. Rejected because the concept would remain invisible to the core public model and harder to reuse across packages.

### 2. Keep loading explicit instead of hiding it in SDK construction

The first tranche should expose a loader utility or loader object that callers invoke directly before building higher-level behavior around the returned skills.

Why this over implicit async loading in `AgentLoopSdk` construction:
- It keeps SDK construction synchronous and predictable.
- It makes discovery policy testable without coupling it to runtime creation.
- It lets callers choose whether to load skills at startup, lazily, or not at all.

Alternative considered:
- Add a `skillLoader` parameter directly to `AgentLoopSdk`. Rejected for the initial tranche because it couples filesystem discovery to runtime setup too early.

### 3. Support known ecosystem locations rather than inventing a new native path first

The loader should scan the interoperable `.agents/skills` convention and the compatibility locations already used by popular harnesses in this repository: `.claude/skills` and `.opencode/skills`.

Project scope should scan from the current working directory up through ancestor directories until the git root. User scope should scan the corresponding home-directory locations.

Why this over adding a new `.agent_loop/skills` or `~/.agent_loop/skills` location now:
- The open Agent Skills materials recommend `.agents/skills` for cross-client interoperability.
- This repository already carries `.claude/skills` and `.opencode/skills`, so compatibility is immediately useful.
- Avoiding a new native location keeps the first release simpler and reduces path proliferation.

Alternative considered:
- Define an agent-loop-specific skills directory from day one. Rejected because the ecosystem-compatible locations already satisfy the minimum use case.

### 4. Use deterministic precedence with project-local override behavior

The loader should prefer project-local skills over user-global skills for the same skill name. Within a scope, search order should be fixed and documented so collisions resolve predictably.

Why this over merging all collisions or treating duplicates as hard errors:
- Project-local override behavior matches the ecosystem guidance for skills.
- Deterministic shadowing is easier for callers to understand than partial merges.
- Hard errors would make compatibility locations much less practical in real repositories.

Alternative considered:
- Fail on any duplicate name. Rejected because it would make shared user skill sets awkward and diverge from established client behavior.

### 5. Limit the first loader to standard metadata extraction and full-content loading

The loader should parse the `SKILL.md` frontmatter needed for discovery and expose the body content when a skill is fully loaded. It does not need to execute scripts, validate every optional file, or interpret harness-specific frontmatter extensions.

Why this over implementing advanced skill semantics now:
- The open standard's core value is progressive disclosure of metadata and content.
- The repo's immediate need is representing and discovering skills, not yet running them.
- It keeps the first implementation small enough to land before activation design solidifies.

Alternative considered:
- Add activation and execution semantics in the same change. Rejected because those behaviors deserve separate API and transcript decisions.

## Risks / Trade-offs

- [The loader may ossify path choices too early] -> Limit the first design to additive known locations and keep the public loading surface configurable enough for future extension.
- [Compatibility directories can produce duplicate skill names] -> Document precedence clearly and add tests for project-over-user and same-scope ordering.
- [Callers may expect activation behavior once skills can be loaded] -> Keep the API and docs explicit that this tranche only models and discovers skills.
- [Lenient parsing choices can affect interoperability] -> Preserve required metadata expectations and document any tolerated deviations in tests and loader docs.

## Migration Plan

1. Add the public core skill types and export them.
2. Add SDK-side filesystem loading utilities and parsing logic for known locations.
3. Add tests covering discovery locations, ancestor scanning, metadata parsing, and precedence.
4. Update docs and examples so callers know how to load skills explicitly.
5. Validate with the normal repo verification commands.

Rollback remains straightforward because the change is additive. Removing the loader or skill types would not affect existing loop/session behavior.

## Open Questions

- Should the initial loader surface diagnostics for malformed skills, or only return successfully loaded entries?
- Should same-scope precedence prefer `.agents/skills` over compatibility directories, or simply follow documented search order?
- Do we want to expose one combined `loadAgentSkills()` helper, lower-level location scanners, or both in the first SDK API?
