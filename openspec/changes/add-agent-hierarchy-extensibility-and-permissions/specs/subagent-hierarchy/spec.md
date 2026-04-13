## ADDED Requirements

### Requirement: Agents can delegate to hierarchical subagents
The SDK SHALL allow an agent profile to delegate work to a named subagent that runs in a child session linked to the parent session.

#### Scenario: Parent agent delegates work to a subagent
- **WHEN** an active parent agent requests delegated work from an allowed subagent profile
- **THEN** the SDK creates a child session, runs the delegated work under that subagent profile, and links the child session to the parent session

#### Scenario: Child session preserves delegation lineage
- **WHEN** a delegated child session completes
- **THEN** the SDK retains metadata identifying the parent session and delegating agent so the child run can be traced back through the hierarchy

### Requirement: Delegation remains tree-structured
The SDK SHALL represent delegated work as parent-child session relationships rather than arbitrary cross-linked session graphs.

#### Scenario: Caller inspects child sessions for a parent
- **WHEN** a caller requests child-session information for a parent session
- **THEN** the SDK returns only the direct child sessions created through delegation from that parent

#### Scenario: Child delegation stays attached to one parent
- **WHEN** the runtime creates a child session for delegated work
- **THEN** that child session is associated with exactly one parent session at creation time
