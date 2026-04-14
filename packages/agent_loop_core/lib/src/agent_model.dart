import 'agent_types.dart';

abstract interface class AgentProvider {
  Future<AgentResponse> respond(AgentTurn turn);
}

abstract interface class AgentStreamingProvider implements AgentProvider {
  Stream<AgentProviderEvent> streamRespond(AgentTurn turn);
}

sealed class AgentProviderEvent {
  const AgentProviderEvent();
}

class AgentProviderPartialOutputEvent extends AgentProviderEvent {
  const AgentProviderPartialOutputEvent({required this.part});

  final MessagePart part;
}

class AgentProviderResponseEvent extends AgentProviderEvent {
  const AgentProviderResponseEvent({required this.response});

  final AgentResponse response;
}

abstract interface class AgentModel implements AgentProvider {}

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
