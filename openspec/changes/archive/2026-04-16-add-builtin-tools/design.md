## Context

`agent_loop_core` already knows how to surface tool definitions to providers and execute tool calls during a run, but the repo does not ship a standard tool pack for common coding-agent workflows. The requested builtin set crosses package boundaries: core needs concrete tool implementations and registration helpers, the public facade needs a supported API for enabling them, and the CLI should be able to opt into the same pack instead of carrying one-off tool wiring later.

The tool set also mixes very different side effects. `read`, `glob`, and `search` need workspace-bounded filesystem reads; `edit` and `apply_patch` need deterministic file mutation; `bash` needs process execution with controlled working-directory behavior; and `webfetch` needs outbound HTTP with normalized text-oriented results. The design needs one coherent contract for tool naming, arguments, result formatting, and guardrails so the SDK remains predictable across providers.

## Goals / Non-Goals

**Goals:**
- Ship a first-party builtin tool pack covering `read`, `glob`, `search`, `edit`, `apply_patch`, `bash`, and `webfetch`.
- Keep the builtin tools aligned with the existing tool abstraction so providers do not need special handling.
- Expose a public SDK entrypoint that makes the builtin pack easy to enable for callers and the demo CLI.
- Normalize error and success payloads so transcript storage and model follow-up calls stay stable.
- Bound tool execution to the current workspace and explicit runtime inputs instead of hidden global state.

**Non-Goals:**
- Adding approval-policy changes or new permission semantics beyond the existing tool permission model.
- Reproducing every OpenCode/GitHub Copilot tool affordance such as image rendering, rich streaming shell output, or remote sandboxing.
- Introducing persistent tool state, caching layers, or background job execution.

## Decisions

### Decision: Implement builtin tools inside `agent_loop_core` as a packaged factory
The builtin tools should live in `packages/agent_loop_core` because execution semantics, transcript integration, and future policy checks are core runtime concerns. A single factory such as `createBuiltinTools(...)` can return the concrete tool definitions while keeping the public `agent_loop` package as a re-exporting facade.

Alternative considered: implement builtin tools only in the CLI.
Why not: that would make the demo app useful, but it would not create a reusable SDK capability and would duplicate behavior once other callers need the same tools.

### Decision: Use one shared runtime context for workspace, shell, and HTTP constraints
The builtin pack should be constructed from an explicit options object that carries the workspace root, default shell working directory, network client configuration, and any tool-specific limits. This keeps the tools deterministic in tests and avoids scattering path-resolution or timeout rules across seven separate constructors.

Alternative considered: let every tool accept its own independent options.
Why not: the duplicated configuration would make it easier for callers to accidentally create inconsistent workspace boundaries between read, edit, search, and bash.

### Decision: Model file-editing as two tools with distinct contracts
`edit` should cover targeted file replacement and small in-place updates, while `apply_patch` should accept patch text and return a structured patch-application outcome. Keeping both tools explicit matches the requested scope and avoids overloading a single generic file-write tool with incompatible input styles.

Alternative considered: expose only `apply_patch` and treat simple edits as generated patches.
Why not: direct edit operations are simpler for providers to call for straightforward replacements and reduce unnecessary patch parsing for common cases.

### Decision: Return text-first results with stable metadata fields
Each builtin tool should return a text payload the model can consume directly, plus lightweight structured metadata where necessary for callers or future events. That keeps compatibility with the current transcript-oriented runtime while still allowing tools like `bash` and `webfetch` to surface exit status, truncation, or response metadata consistently.

Alternative considered: return bespoke Dart objects per tool and serialize them later.
Why not: that adds complexity at the runtime boundary and makes provider-independent tool handling harder to reason about.

### Decision: Verify behavior with focused core tests and the existing CLI smoke check
The repo currently relies on formatting, analysis, and a CLI smoke run in CI. The builtin tool change should add targeted tests around the tool factory and individual high-risk behaviors in `agent_loop_core`, then keep the existing CLI smoke run as an integration sanity check.

Alternative considered: rely only on the CLI smoke run.
Why not: the side-effect-heavy tools need narrower characterization tests to make TDD practical and to catch regressions in path bounding, command execution, and patch application.

## Risks / Trade-offs

- Workspace-bound path handling can still be subtle across relative paths and symlinks. -> Resolve canonical paths before access checks and test both accepted and rejected path shapes.
- Shell execution is inherently higher risk than read-only tools. -> Require an explicit working directory, capture exit code/stdout/stderr predictably, and enforce timeouts from the shared runtime options.
- `webfetch` output can become large or non-textual. -> Normalize to text-oriented responses, capture content type and truncation metadata, and fail clearly for unsupported payloads.
- Two write-capable tools (`edit` and `apply_patch`) increase API surface area. -> Keep their contracts deliberately narrow and document when callers should prefer one over the other.
- Public SDK exposure may lock in naming quickly. -> Use the requested tool names directly and keep the initial configuration surface minimal so follow-up changes remain additive.
