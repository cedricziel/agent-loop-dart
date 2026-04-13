## 1. Approval Checkpoint Model

- [x] 1.1 Add failing core tests for tool and subagent `ask` decisions pausing managed sessions with persisted pending approval metadata.
- [x] 1.2 Extend the core session and permission types with a serializable pending approval/checkpoint model that can represent blocked tool and delegation work.
- [x] 1.3 Update the loop/runtime internals to capture the continuation payload needed to resume approved work without replaying the model turn.

## 2. Managed Session Approval Flow

- [x] 2.1 Add failing tests for inspecting, approving, and denying pending approval requests on managed sessions, including reload behavior.
- [x] 2.2 Implement managed-session APIs that expose the pending approval request and let callers approve or deny it.
- [x] 2.3 Enforce run exclusivity while approval is pending and resume or terminate the paused run correctly after resolution.

## 3. Events And Public Surface

- [x] 3.1 Add failing tests for approval lifecycle event ordering across pause, resolution, resume, and denial flows.
- [x] 3.2 Add the new approval lifecycle event types and thread them through managed-session event annotation and exports.
- [x] 3.3 Expose the approval-aware APIs from `package:agent_loop` and update the CLI demo to prompt interactively when permission `ask` occurs.

## 4. Verification

- [x] 4.1 Run focused package tests for the new approval flow behavior in `agent_loop_core` and `agent_loop`.
- [x] 4.2 Run repo verification: `dart pub get`, `dart format --output=none --set-exit-if-changed .`, `dart analyze`, and `dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"`.
