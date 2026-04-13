## Why

Compared with OpenCode and PI, the repo still lacks three connected pieces of the higher-level agent runtime: hierarchical subagents, first-class extensibility hooks, and configurable agent permissions/profiles. Managed sessions close the lower-level session gap, but without these additional layers the SDK still cannot express multi-agent delegation, safe agent specialization, or user-defined runtime customization in the way those systems do.

## What Changes

- Add hierarchical subagent support so a primary agent can delegate work to specialized child agents with explicit parent-child session relationships.
- Add agent profiles so callers can define named agents with prompts, models, step limits, and visibility/mode metadata.
- Add permission policies so tools and delegated subagents can be allowed, denied, or gated per agent profile.
- Add an extensibility surface for registering agent definitions, runtime hooks, and optional packaged capabilities without pushing those concerns into `AgentLoop` itself.
- Extend event behavior so agent transitions, delegation boundaries, and permission decisions are observable through the SDK lifecycle stream.
- Keep the implementation additive and explicitly sequence it after managed sessions rather than collapsing all behavior into one monolithic runtime rewrite.

## Capabilities

### New Capabilities
- `subagent-hierarchy`: Parent-child agent delegation, child sessions, and hierarchical execution structure.
- `agent-profiles`: Named agent definitions with prompts, model overrides, and mode metadata.
- `agent-permissions`: Per-agent permission policies for tools, edits, shell access, and subagent invocation.
- `agent-extensibility`: Registration points for custom agents, runtime hooks, and packaged capability loading.

### Modified Capabilities
- `managed-agent-sessions`: Extend managed sessions to support parent-child relationships and child session discovery.
- `run-control`: Extend run control to cover delegated child runs and agent-boundary cancellation semantics.
- `run-events`: Extend lifecycle events to include agent selection, delegation, permission outcomes, and child-run boundaries.

## Impact

- Affects `packages/agent_loop_core` agent definitions, delegation orchestration, session metadata, and event types.
- Affects `packages/agent_loop` public SDK APIs for creating/configuring agents and invoking subagents.
- Affects `packages/agent_loop_cli` so the demo can exercise named agents, delegation, and permission-aware behavior.
- Introduces additive configuration and extension points that future skills/packages can build on.
