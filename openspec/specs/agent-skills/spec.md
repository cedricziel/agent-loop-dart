## ADDED Requirements

### Requirement: Core exposes first-class agent skill types
`agent_loop_core` SHALL expose public types for discovered skill metadata and fully loaded skill content so SDK and application callers can model Agent Skills-compatible packages without relying on untyped maps.

#### Scenario: Caller inspects discovered skill metadata
- **WHEN** a caller loads available skills without requesting full instructions
- **THEN** the returned skill metadata includes the skill name, description, and source location as stable public fields

#### Scenario: Caller requests fully loaded skill content
- **WHEN** a caller loads a skill's full contents
- **THEN** the returned loaded skill value includes the discovered metadata plus the parsed instruction body and resolved skill root directory

### Requirement: SDK loads skills from known local locations
The SDK SHALL provide a filesystem loading utility for Agent Skills-compatible packages that scans known project and user locations for directories containing `SKILL.md`.

#### Scenario: Loader discovers project-local interoperable skills
- **WHEN** a project contains skills under `.agents/skills`
- **THEN** the loader returns those skills as available project-local entries

#### Scenario: Loader discovers compatibility skill locations
- **WHEN** skills exist under `.claude/skills`, `.opencode/skills`, `~/.claude/skills`, `~/.config/opencode/skills`, or `~/.agents/skills`
- **THEN** the loader includes those skills in discovery using the same public skill types

### Requirement: Project-local discovery walks ancestor directories to the git root
The SDK skill loader SHALL scan project-local skill directories starting at the working directory and continuing through ancestor directories until the repository git root.

#### Scenario: Nested package inherits repository skill directory
- **WHEN** the loader runs from a nested package directory inside a git repository that has a skill directory at the repository root
- **THEN** the repository-root skill directory is included in discovery

#### Scenario: Discovery stops at git root
- **WHEN** the loader reaches the repository git root while scanning ancestor directories
- **THEN** it does not continue scanning parent directories beyond that git root for project-local skill locations

### Requirement: Duplicate skill names resolve deterministically
The SDK skill loader SHALL resolve duplicate skill names using deterministic precedence, and project-local definitions SHALL override user-global definitions with the same skill name.

#### Scenario: Project skill shadows user skill
- **WHEN** a project-local skill and a user-global skill share the same skill name
- **THEN** the loader returns the project-local skill as the effective discovered entry for that name

#### Scenario: Same-scope collisions follow documented search order
- **WHEN** multiple discovered skills in the same scope share the same skill name across supported locations
- **THEN** the loader resolves the effective entry according to the documented search order and returns a stable result across repeated loads

### Requirement: Loader parses discovery metadata from `SKILL.md`
The SDK skill loader SHALL parse discovery metadata from each discovered `SKILL.md` and SHALL only treat directories with a parseable skill name and description as loadable skills.

#### Scenario: Valid skill directory is discovered
- **WHEN** a discovered directory contains a `SKILL.md` with parseable `name` and `description` metadata
- **THEN** the loader returns that skill in the discovered catalog

#### Scenario: Missing required metadata excludes the skill
- **WHEN** a discovered `SKILL.md` is missing a parseable `name` or `description`
- **THEN** the loader skips that entry instead of returning incomplete skill metadata
