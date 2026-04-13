import 'dart:io';

import 'package:agent_loop/agent_loop.dart';

class ClockTool implements AgentTool {
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'clock',
    description: 'Returns the current local timestamp.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
    },
  );

  @override
  Future<String> execute(Map<String, Object?> input) async {
    return DateTime.now().toIso8601String();
  }
}

class DemoModel implements AgentModel {
  const DemoModel();

  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    final lastMessage = turn.messages.last;

    if (lastMessage.role == AgentRole.tool && lastMessage.toolResult != null) {
      return AgentResponse(
        parts: <MessagePart>[
          TextPart(
            text:
                'The tool `${lastMessage.toolResult!.name}` returned ${lastMessage.toolResult!.output}.',
          ),
        ],
      );
    }

    final latestUserMessage = turn.messages.lastWhere(
      (message) => message.role == AgentRole.user,
      orElse: () => const AgentMessage(role: AgentRole.user, content: ''),
    );
    final prompt = latestUserMessage.content.toLowerCase();

    if (prompt.contains('time') &&
        turn.tools.any((tool) => tool.name == 'clock')) {
      return AgentResponse(
        parts: <MessagePart>[
          const ReasoningPart(text: 'Need the clock tool first.'),
        ],
        toolCalls: <ToolCall>[ToolCall(id: 'clock-1', name: 'clock')],
      );
    }

    if (prompt.contains('report')) {
      return AgentResponse(
        parts: <MessagePart>[
          const TextPart(text: 'Generated report'),
          const FilePart(path: 'build/report.txt', mimeType: 'text/plain'),
        ],
      );
    }

    return AgentResponse(
      parts: <MessagePart>[
        TextPart(text: 'Demo model response: ${latestUserMessage.content}'),
      ],
    );
  }
}

String? formatPartForLog(MessagePart part) => switch (part) {
  ReasoningPart(text: final text) => 'assistant:reasoning $text',
  FilePart(path: final path, mimeType: final mimeType) =>
    'assistant:file $path ($mimeType)',
  ToolPart(name: final name, state: ToolPartState.pending) =>
    'tool:pending $name',
  ToolPart(
    name: final name,
    state: ToolPartState.completed,
    output: final output,
  ) =>
    'tool:completed $name => ${output ?? ''}',
  TextPart() => null,
};

Future<ManagedAgentSession> createManagedDemoSession(AgentLoopSdk sdk) async {
  final session = await sdk.createSession();
  return sdk.loadSession(session.id);
}

Future<int> runCli(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run packages/agent_loop_cli/bin/agent_loop.dart <prompt>',
    );
    return 64;
  }

  final sdk = AgentLoopSdk(
    model: const DemoModel(),
    tools: <AgentTool>[ClockTool()],
    systemPrompt: 'You are a compact coding agent.',
  );
  final session = await createManagedDemoSession(sdk);

  AgentRunResult? result;

  await for (final event in session.stream(args.join(' '))) {
    switch (event) {
      case AgentRunStartEvent():
        // Managed sessions add explicit run lifecycle metadata.
        break;
      case AgentMessagePartEvent(part: final part):
        final line = formatPartForLog(part);
        if (line != null && line.isNotEmpty) {
          stderr.writeln(line);
        }
      case AgentAssistantEvent(message: final message)
          when message.toolCall != null:
        stderr.writeln('assistant: ${message.content}');
      case AgentToolCallEvent():
        // Tool parts already describe pending tool state.
        break;
      case AgentToolResultEvent():
        // Tool parts already describe completed tool state.
        break;
      case AgentRunCompleteEvent(result: final completedResult):
        result = completedResult;
      case AgentRunCancelledEvent():
        stderr.writeln('run:cancelled');
      case AgentAssistantEvent():
        // Keep normal assistant text on stdout via the final result only.
        break;
    }
  }

  stdout.writeln(result?.output ?? '');
  return 0;
}
