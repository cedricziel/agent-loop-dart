import 'agent_types.dart';

enum AgentPermissionOutcome { allow, ask, deny }

enum AgentPermissionKind { tool, subagent }

class AgentPermissionDecision {
  const AgentPermissionDecision({
    required this.kind,
    required this.subject,
    required this.outcome,
    this.reason,
  });

  final AgentPermissionKind kind;
  final String subject;
  final AgentPermissionOutcome outcome;
  final String? reason;
}

abstract interface class AgentPermissionPolicy {
  Future<AgentPermissionDecision> evaluateTool(ToolCall toolCall);

  Future<AgentPermissionDecision> evaluateSubagent(String agentId);
}

class DeclarativeAgentPermissionPolicy implements AgentPermissionPolicy {
  const DeclarativeAgentPermissionPolicy({
    this.toolPermissions = const <String, AgentPermissionOutcome>{},
    this.subagentPermissions = const <String, AgentPermissionOutcome>{},
    this.defaultOutcome = AgentPermissionOutcome.allow,
  });

  final Map<String, AgentPermissionOutcome> toolPermissions;
  final Map<String, AgentPermissionOutcome> subagentPermissions;
  final AgentPermissionOutcome defaultOutcome;

  @override
  Future<AgentPermissionDecision> evaluateSubagent(String agentId) async {
    return AgentPermissionDecision(
      kind: AgentPermissionKind.subagent,
      subject: agentId,
      outcome: subagentPermissions[agentId] ?? defaultOutcome,
    );
  }

  @override
  Future<AgentPermissionDecision> evaluateTool(ToolCall toolCall) async {
    return AgentPermissionDecision(
      kind: AgentPermissionKind.tool,
      subject: toolCall.name,
      outcome: toolPermissions[toolCall.name] ?? defaultOutcome,
    );
  }
}

class AgentPermissionDeniedException implements Exception {
  const AgentPermissionDeniedException(this.decision);

  final AgentPermissionDecision decision;
}

class AgentApprovalRequiredException implements Exception {
  const AgentApprovalRequiredException(this.decision);

  final AgentPermissionDecision decision;
}
