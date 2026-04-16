## Why

The SDK can execute model-requested tools, but every caller currently has to define common local tools such as file reads, search, patching, shell execution, and web fetches themselves. Adding a supported builtin tool pack makes the loop usable out of the box for code-editing workflows and gives the project a clear contract for the tool behavior the CLI and future SDK consumers can rely on.

## What Changes

- Add a builtin tool capability that packages `read`, `glob`, `search`, `edit`, `apply_patch`, `bash`, and `webfetch` behind the existing tool execution surface.
- Define consistent input, output, and failure behavior for each builtin tool so providers and callers can depend on stable tool contracts.
- Expose an SDK entrypoint that lets callers opt into the builtin tool pack without manually recreating tool definitions.
- Document the filesystem, process, and network constraints the builtin tool pack enforces while running inside the current workspace.

## Capabilities

### New Capabilities
- `builtin-tools`: First-party builtin tools for local file inspection, file editing, shell execution, and web content retrieval.

### Modified Capabilities

## Impact

- Affected code: `packages/agent_loop_core` tool registration and execution plumbing, the public `packages/agent_loop` facade, and the demo CLI defaults in `packages/agent_loop_cli`.
- APIs: Adds a new public way to construct or enable a standard builtin tool set for runs.
- Systems: Local filesystem access, local process execution, and outbound HTTP fetching behavior need explicit runtime guards and normalized error handling.
