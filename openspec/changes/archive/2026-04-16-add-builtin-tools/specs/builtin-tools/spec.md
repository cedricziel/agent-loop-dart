## ADDED Requirements

### Requirement: SDK exposes a builtin tool pack
The SDK SHALL provide a first-party builtin tool pack that callers can enable without manually defining each tool, and that pack SHALL include `read`, `glob`, `search`, `edit`, `apply_patch`, `bash`, and `webfetch`.

#### Scenario: Caller enables builtin tools for a run
- **WHEN** a caller constructs a loop with the builtin tool pack enabled
- **THEN** the loop advertises all seven builtin tools through the existing tool definition surface without additional caller-defined tool registration

#### Scenario: Builtin tool names stay stable
- **WHEN** a provider inspects the enabled tools for a run
- **THEN** it receives the requested tool names `read`, `glob`, `search`, `edit`, `apply_patch`, `bash`, and `webfetch` exactly as the callable tool identifiers

### Requirement: Filesystem tools stay bounded to the configured workspace
The `read`, `glob`, `search`, `edit`, and `apply_patch` builtin tools SHALL resolve requested paths against the configured workspace root and SHALL reject access outside that workspace.

#### Scenario: Relative path inside workspace succeeds
- **WHEN** a caller invokes a filesystem builtin tool with a relative path that resolves inside the configured workspace root
- **THEN** the tool operates on that resolved path and returns its normal success result

#### Scenario: Path escapes workspace root
- **WHEN** a caller invokes a filesystem builtin tool with a path that resolves outside the configured workspace root
- **THEN** the tool fails without touching the target path and returns a structured workspace-boundary error

### Requirement: Builtin tools expose deterministic text-first results
Each builtin tool SHALL return a normalized text result suitable for transcript storage and model follow-up, and SHALL include stable metadata for tool-specific status such as truncation, exit status, or response details when relevant.

#### Scenario: Bash command completes successfully
- **WHEN** the `bash` builtin tool executes a command that exits successfully
- **THEN** the tool result includes the captured command output and metadata identifying a successful exit status

#### Scenario: Web fetch returns a large response
- **WHEN** the `webfetch` builtin tool retrieves content that exceeds the configured response limit
- **THEN** the tool result contains a text response truncated according to the limit and metadata indicating truncation

### Requirement: Write-capable builtin tools report mutation outcomes clearly
The `edit` and `apply_patch` builtin tools SHALL report whether a requested mutation changed a file, and SHALL fail without partial silent success when the requested update cannot be applied as specified.

#### Scenario: Edit replaces expected content
- **WHEN** the `edit` builtin tool is asked to replace content that matches the current file state
- **THEN** it updates the file and returns a result indicating the file changed successfully

#### Scenario: Patch application does not match target content
- **WHEN** the `apply_patch` builtin tool receives patch instructions that cannot be applied to the current file contents
- **THEN** it leaves the file unchanged and returns an explicit patch-application failure result

### Requirement: Bash and webfetch honor runtime execution limits
The `bash` and `webfetch` builtin tools SHALL enforce configured runtime limits such as timeout and working-directory constraints, and SHALL surface those limit violations as explicit tool failures.

#### Scenario: Bash command exceeds timeout
- **WHEN** the `bash` builtin tool runs longer than the configured timeout
- **THEN** the tool terminates the execution attempt and returns a timeout failure result

#### Scenario: Web fetch uses an unsupported response type
- **WHEN** the `webfetch` builtin tool retrieves content that cannot be normalized into the supported text-oriented response format
- **THEN** the tool returns an explicit unsupported-content failure without emitting a misleading success payload
