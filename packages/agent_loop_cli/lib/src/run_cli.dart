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
        text:
            'The tool `${lastMessage.toolResult!.name}` returned ${lastMessage.toolResult!.output}.',
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
        toolCalls: <ToolCall>[ToolCall(id: 'clock-1', name: 'clock')],
      );
    }

    return AgentResponse(
      text: 'Demo model response: ${latestUserMessage.content}',
    );
  }
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

  final result = await sdk.run(prompt: args.join(' '));
  stdout.writeln(result.output);
  return 0;
}
