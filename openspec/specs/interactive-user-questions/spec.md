## ADDED Requirements

### Requirement: SDK exposes a blocking `ask_user` tool for structured human questions
The SDK SHALL expose a built-in `ask_user` tool that a model can call to request structured human input, including a short header, a full question prompt, suggested options, per-option descriptions, and whether multiple suggested options may be selected.

#### Scenario: Model requests a structured question with suggested options
- **WHEN** a model emits a tool call for `ask_user`
- **THEN** the tool input accepted by the SDK includes the question prompt plus any suggested options with labels and descriptions

#### Scenario: Suggested options are guidance rather than a closed answer set
- **WHEN** a model emits a tool call for `ask_user`
- **THEN** the SDK allows the eventual caller answer to include optional freeform text even when suggested options are present

### Requirement: Managed sessions block on `ask_user` until answered or cancelled
The SDK SHALL pause a managed-session run when the model calls `ask_user` and SHALL not continue the loop until the caller either answers the pending question request or cancels it.

#### Scenario: Managed run pauses on `ask_user`
- **WHEN** a managed-session run reaches an `ask_user` tool call
- **THEN** the SDK persists a pending question request and stops emitting subsequent loop progress for that run until the request is resolved

#### Scenario: Caller cancels a pending question request
- **WHEN** a caller cancels the pending `ask_user` request on a managed session
- **THEN** the SDK terminates the paused run without fabricating an `ask_user` tool result

### Requirement: Question answers resume as `ask_user` tool results
The SDK SHALL resume an answered pending question by returning the human answer as the completed `ask_user` tool result for the original tool call, preserving structured selected options and optional unstructured freeform text.

#### Scenario: Caller answers with selected options only
- **WHEN** a caller answers a pending question by selecting one or more suggested options without freeform text
- **THEN** the resumed run receives an `ask_user` tool result that preserves those selected option identifiers as structured output

#### Scenario: Caller answers with freeform text
- **WHEN** a caller answers a pending question with freeform text, with or without selecting suggested options
- **THEN** the resumed run receives an `ask_user` tool result that preserves the freeform text as unstructured text alongside any structured selected option identifiers
