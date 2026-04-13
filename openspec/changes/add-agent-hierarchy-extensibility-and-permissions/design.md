## Context

The repository is moving from a low-level loop SDK toward a higher-level agent runtime. The previous managed-session tranche closes the gap around long-lived session handles, persistence boundaries, and cancellation. The next set of parity gaps versus OpenCode and PI sit above that layer: there is still no notion of named agent profiles, no hierarchical subagent delegation, no per-agent permission model, and no structured extensibility surface for registering runtime hooks or packaged capabilities.

These concerns are linked. Hierarchical delegation depends on stable session/run boundaries. Agent permissions depend on named agent identities. Extensibility needs a stable place to register custom agents, hooks, and future package-like features. Landing them as one coordinated design is safer than adding each feature with a separate ad hoc API.

This change affects core orchestration, public SDK APIs, and the CLI demo. It also adds a new architectural layer above the loop itself, so a design document is warranted before implementation.

## Goals / Non-Goals

**Goals:**
- Add named agent profiles that define prompt, model overrides, mode, visibility, and limits.
- Add hierarchical subagent delegation with parent-child session relationships and explicit delegation boundaries.
- Add permission policies for tools and subagent invocation that can vary per agent profile.
- Add an extensibility surface for registering agents and runtime hooks without pushing those concerns into `AgentLoop`.
- Keep the implementation additive and layered on top of managed sessions.

**Non-Goals:**
- A full marketplace or remote package registry.
- Rich UI approval prompts; the first tranche only needs permission evaluation and surfaced outcomes.
- Arbitrary multi-agent graphs or concurrent swarms; parent-child delegation is enough for the first design.
- A full TUI redesign.

## Decisions

### 1. Add a separate agent-runtime layer above managed sessions

Named agents, subagent delegation, permissions, and hooks should live in a new runtime layer that composes managed sessions instead of extending `AgentLoop` directly. `AgentLoop` remains the primitive orchestrator; the agent runtime decides which agent profile is active, whether delegation is allowed, and how child sessions are created.

Why this over folding everything into `AgentLoopSdk`:
- It keeps the current low-level facade usable for simple integrations.
- It prevents profile, permission, and hook logic from leaking into the loop core.
- It gives future package-like extensions one stable registration surface.

Alternative considered:
- Add agent fields piecemeal to `AgentLoopSdk` and `ManagedAgentSession`. Rejected because it would produce a grab bag of unrelated options without a coherent runtime contract.

### 2. Model named agents as immutable profile definitions plus runtime instances

An `AgentProfile` should describe static intent such as prompt, model override, mode, visibility, and permission policy. Runtime execution state stays on managed sessions and delegated runs.

Why this over fully stateful agent objects:
- Profile definitions are easy to serialize and register.
- Session state and agent definition stay cleanly separated.
- It matches the profile/configuration shape exposed by both OpenCode and PI.

Alternative considered:
- Let each custom agent object own mutable state. Rejected because stateful definitions complicate persistence, testing, and deterministic delegation.

### 3. Restrict first-tranche hierarchy to parent-child delegation

The initial subagent model should only support a parent run delegating a unit of work to one child session at a time, with the child linked back to the parent session and delegating agent profile. Child sessions can themselves delegate later, but the runtime contract remains tree-shaped rather than graph-shaped.

Why this over arbitrary agent graphs:
- Tree semantics are easier to persist and inspect.
- It aligns with the mental model users already expect from child sessions.
- It reduces ambiguity around cancellation, visibility, and event ordering.

Alternative considered:
- Generic graph-based delegation between any sessions. Rejected because it introduces routing and lifecycle complexity before there is a proven need.

### 4. Evaluate permissions through declarative policies with allow/ask/deny outcomes

Permission policy should be declarative and profile-scoped. The first implementation only needs the decision result and its reason surfaced through events and errors. Interactive approval UX can be added later on top of `ask` outcomes.

Why this over booleans per tool:
- It is expressive enough for both safe defaults and future granular matching.
- It aligns with the permission concepts in OpenCode.
- It lets the runtime distinguish policy denial from execution failure.

Alternative considered:
- Boolean enabled/disabled flags only. Rejected because they cannot represent future approval flows and would need another API migration soon after.

### 5. Expose extensibility through registries and hook interfaces, not arbitrary callbacks everywhere

Custom agents, permission evaluators, and runtime interceptors should register through explicit registries/interfaces. The runtime can then apply hooks at stable lifecycle points such as agent selection, pre-delegation, post-delegation, and permission evaluation.

Why this over ad hoc callbacks on constructors:
- It keeps extension points discoverable.
- It gives future packaged capabilities a consistent integration surface.
- It avoids turning every public constructor into a long list of optional closures.

Alternative considered:
- Add one-off callbacks for each new feature. Rejected because it does not scale and produces inconsistent extension semantics.

### 6. Extend events with agent and permission metadata instead of inventing a second telemetry channel

Agent selection, delegation start/end, child-session creation, and permission decisions should all flow through the existing event stream model with additive event types and metadata. Callers should not need a separate hook-only telemetry system just to observe hierarchy or policy outcomes.

Why this over a side-channel observer API:
- It preserves one lifecycle vocabulary for SDK and CLI consumers.
- It keeps ordering relative to transcript mutations and delegated runs.
- It allows future automation to listen to a single stream.

Alternative considered:
- Separate observer APIs for permissions and delegation. Rejected because it fragments observability and complicates consumers.

## Risks / Trade-offs

- [This tranche is broader than a single feature] -> Keep the first implementation minimal in each area: tree-only delegation, profile definitions only, declarative policies only, and a small hook surface.
- [Permission `ask` outcomes may look unfinished without UI prompts] -> Treat `ask` as a structured decision result now and leave approval UX to a follow-up layer.
- [Child session persistence may complicate storage] -> Persist parent id, delegating agent id, and child metadata in the managed-session envelope without requiring a full graph index.
- [Hooks may become a stability burden] -> Start with a very small set of lifecycle hook points and document them as additive.

## Migration Plan

1. Land managed sessions first as the dependency layer.
2. Add immutable agent profile definitions and registration APIs.
3. Add permission evaluation and event surfacing for profile-scoped tool/subagent access.
4. Add parent-child delegation and child session metadata on top of managed sessions.
5. Add runtime hooks and CLI demo wiring.
6. Verify through focused tests and then repo-level verification commands.

Rollback remains straightforward because the lower-level managed-session and stateless loop APIs remain intact. If the higher-level agent runtime needs to be reverted, callers can continue using explicit session handles without profiles or delegation.

## Open Questions

- Should delegated child runs inherit the parent agent's model by default when the child profile has no model override?
- Which hook points are essential in the first tranche beyond pre-delegation, post-delegation, and permission evaluation?
- Should permission rules support only exact tool/subagent names first, or include pattern matching from the start?
