## ADDED Requirements

### Requirement: Agent profiles enforce permission policies
The SDK SHALL evaluate tool and subagent access through permission policies attached to the active agent profile.

#### Scenario: Tool invocation is denied by policy
- **WHEN** an active agent attempts to use a tool that its permission policy denies
- **THEN** the SDK blocks the invocation before execution and surfaces the policy denial as a structured runtime outcome

#### Scenario: Delegation is denied by policy
- **WHEN** an active agent attempts to delegate work to a subagent that its permission policy denies
- **THEN** the SDK does not create the child session and surfaces a structured permission denial for that delegation request

### Requirement: Permission outcomes distinguish allow, ask, and deny
The SDK SHALL represent permission decisions with explicit `allow`, `ask`, or `deny` outcomes.

#### Scenario: Permission policy allows an action
- **WHEN** a requested tool call or subagent invocation matches an allow rule
- **THEN** the runtime proceeds without a permission error

#### Scenario: Permission policy returns ask
- **WHEN** a requested tool call or subagent invocation matches an ask rule
- **THEN** the runtime surfaces an approval-required outcome instead of silently running or silently denying the action
