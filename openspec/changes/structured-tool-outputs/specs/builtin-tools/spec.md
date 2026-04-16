## MODIFIED Requirements

### Requirement: Builtin tools expose deterministic text-first results
Each builtin tool SHALL return a shared structured tool output suitable for transcript storage and model follow-up, and that output SHALL include a deterministic text rendering plus stable metadata for tool-specific status such as truncation, exit status, or response details when relevant.

#### Scenario: Bash command completes successfully
- **WHEN** the `bash` builtin tool executes a command that exits successfully
- **THEN** the tool result includes a structured output whose text rendering contains the captured command output and whose metadata identifies a successful exit status

#### Scenario: Web fetch returns a large response
- **WHEN** the `webfetch` builtin tool retrieves content that exceeds the configured response limit
- **THEN** the tool result contains a structured output whose text rendering is truncated according to the limit and whose metadata indicates truncation

### Requirement: Write-capable builtin tools report mutation outcomes clearly
The `edit` and `apply_patch` builtin tools SHALL report whether a requested mutation changed a file through the shared structured tool output contract, and SHALL fail without partial silent success when the requested update cannot be applied as specified.

#### Scenario: Edit replaces expected content
- **WHEN** the `edit` builtin tool is asked to replace content that matches the current file state
- **THEN** it updates the file and returns a structured output indicating the file changed successfully

#### Scenario: Patch application does not match target content
- **WHEN** the `apply_patch` builtin tool receives patch instructions that cannot be applied to the current file contents
- **THEN** it leaves the file unchanged and returns an explicit patch-application failure through the structured tool output contract
