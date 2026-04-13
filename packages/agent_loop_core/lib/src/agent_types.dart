import 'agent_tool.dart';

enum AgentRole { system, user, assistant, tool }

class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    this.input = const <String, Object?>{},
  });

  final String id;
  final String name;
  final Map<String, Object?> input;
}

class ToolResult {
  const ToolResult({
    required this.callId,
    required this.name,
    required this.output,
  });

  final String callId;
  final String name;
  final String output;
}

class AgentMessage {
  const AgentMessage({
    required this.role,
    required this.content,
    this.toolCall,
    this.toolResult,
  });

  final AgentRole role;
  final String content;
  final ToolCall? toolCall;
  final ToolResult? toolResult;
}

class AgentResponse {
  AgentResponse({this.text, this.toolCalls = const <ToolCall>[]})
    : assert(
        text != null || toolCalls.isNotEmpty,
        'A response must include text or at least one tool call.',
      );

  final String? text;
  final List<ToolCall> toolCalls;
}

class AgentRunResult {
  const AgentRunResult({
    required this.output,
    required this.transcript,
    required this.session,
    required this.steps,
  });

  final String output;
  final List<AgentMessage> transcript;
  final AgentSession session;
  final int steps;
}

class AgentTurn {
  const AgentTurn({required this.messages, required this.tools});

  final List<AgentMessage> messages;
  final List<ToolDefinition> tools;
}

class AgentSession {
  AgentSession({required List<AgentMessage> transcript})
    : transcript = List.unmodifiable(transcript);

  final List<AgentMessage> transcript;
}

class AgentProviderException implements Exception {
  const AgentProviderException({
    required this.provider,
    required this.cause,
    required this.stackTrace,
  });

  final String provider;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() =>
      'AgentProviderException(provider: $provider, cause: $cause)';
}

sealed class AgentRunEvent {
  const AgentRunEvent();
}

class AgentAssistantEvent extends AgentRunEvent {
  const AgentAssistantEvent({required this.message});

  final AgentMessage message;
}

class AgentToolCallEvent extends AgentRunEvent {
  const AgentToolCallEvent({required this.call});

  final ToolCall call;
}

class AgentToolResultEvent extends AgentRunEvent {
  const AgentToolResultEvent({required this.result});

  final ToolResult result;
}

class AgentRunCompleteEvent extends AgentRunEvent {
  const AgentRunCompleteEvent({required this.result});

  final AgentRunResult result;
}
