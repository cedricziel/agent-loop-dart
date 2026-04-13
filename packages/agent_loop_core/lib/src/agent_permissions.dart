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

sealed class AgentPendingApprovalRequest {
  const AgentPendingApprovalRequest({
    required this.runId,
    required this.decision,
  });

  final String runId;
  final AgentPermissionDecision decision;

  AgentPendingApprovalRequest withRunId(String runId);
}

class AgentToolApprovalRequest extends AgentPendingApprovalRequest {
  const AgentToolApprovalRequest({
    required super.runId,
    required super.decision,
    required this.toolCall,
    required this.transcript,
    required this.step,
  });

  final ToolCall toolCall;
  final List<AgentMessage> transcript;
  final int step;

  @override
  AgentToolApprovalRequest withRunId(String runId) {
    return AgentToolApprovalRequest(
      runId: runId,
      decision: decision,
      toolCall: toolCall,
      transcript: transcript,
      step: step,
    );
  }
}

class AgentSubagentApprovalRequest extends AgentPendingApprovalRequest {
  const AgentSubagentApprovalRequest({
    required super.runId,
    required super.decision,
    required this.delegatedAgentId,
    required this.prompt,
  });

  final String delegatedAgentId;
  final String prompt;

  @override
  AgentSubagentApprovalRequest withRunId(String runId) {
    return AgentSubagentApprovalRequest(
      runId: runId,
      decision: decision,
      delegatedAgentId: delegatedAgentId,
      prompt: prompt,
    );
  }
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
  const AgentApprovalRequiredException(this.decision, {this.request});

  final AgentPermissionDecision decision;
  final AgentPendingApprovalRequest? request;
}
