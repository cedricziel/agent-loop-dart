import 'agent_types.dart';

abstract interface class AgentModel {
  Future<AgentResponse> respond(AgentTurn turn);
}

class LoopbackModel implements AgentModel {
  const LoopbackModel();

  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    final latestUserMessage = turn.messages.lastWhere(
      (message) => message.role == AgentRole.user,
      orElse: () => const AgentMessage(role: AgentRole.user, content: ''),
    );

    return AgentResponse(text: latestUserMessage.content);
  }
}
