import 'agent_model.dart';
import 'agent_tool.dart';
import 'agent_types.dart';

class AgentLoop {
  AgentLoop({
    required AgentModel model,
    Iterable<AgentTool> tools = const <AgentTool>[],
    this.systemPrompt,
    this.maxSteps = 8,
  }) : _model = model,
       _tools = ToolRegistry(tools);

  final AgentModel _model;
  final ToolRegistry _tools;
  final String? systemPrompt;
  final int maxSteps;

  Future<AgentRunResult> run(String prompt) async {
    final transcript = <AgentMessage>[];

    if (systemPrompt case final systemPrompt?) {
      transcript.add(
        AgentMessage(role: AgentRole.system, content: systemPrompt),
      );
    }

    transcript.add(AgentMessage(role: AgentRole.user, content: prompt));

    for (var step = 1; step <= maxSteps; step++) {
      final response = await _model.respond(
        AgentTurn(
          messages: List.unmodifiable(transcript),
          tools: _tools.definitions,
        ),
      );

      if (response.toolCalls.isEmpty) {
        final text = response.text ?? '';
        transcript.add(AgentMessage(role: AgentRole.assistant, content: text));
        return AgentRunResult(
          output: text,
          transcript: List.unmodifiable(transcript),
          steps: step,
        );
      }

      for (final toolCall in response.toolCalls) {
        transcript.add(
          AgentMessage(
            role: AgentRole.assistant,
            content: 'Calling tool `${toolCall.name}`',
            toolCall: toolCall,
          ),
        );

        final tool = _tools[toolCall.name];
        final output = tool == null
            ? 'Tool `${toolCall.name}` is not registered.'
            : await tool.execute(toolCall.input);

        transcript.add(
          AgentMessage(
            role: AgentRole.tool,
            content: output,
            toolResult: ToolResult(
              callId: toolCall.id,
              name: toolCall.name,
              output: output,
            ),
          ),
        );
      }
    }

    throw StateError(
      'Agent loop exceeded maxSteps=$maxSteps without a final response.',
    );
  }
}
