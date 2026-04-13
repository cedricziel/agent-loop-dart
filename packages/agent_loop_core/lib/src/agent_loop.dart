import 'agent_model.dart';
import 'agent_tool.dart';
import 'agent_types.dart';

class AgentLoop {
  AgentLoop({
    AgentProvider? provider,
    AgentModel? model,
    Iterable<AgentTool> tools = const <AgentTool>[],
    this.systemPrompt,
    this.maxSteps = 8,
  }) : assert(
         provider != null || model != null,
         'Provide either an AgentProvider or an AgentModel.',
       ),
       _provider = provider ?? model!,
       _tools = ToolRegistry(tools);

  final AgentProvider _provider;
  final ToolRegistry _tools;
  final String? systemPrompt;
  final int maxSteps;

  Future<AgentRunResult> run(
    String prompt, {
    AgentSession? session,
    List<AgentMessage> transcript = const <AgentMessage>[],
  }) async {
    AgentRunResult? result;

    await for (final event in stream(
      prompt,
      session: session,
      transcript: transcript,
    )) {
      if (event is AgentRunCompleteEvent) {
        result = event.result;
      }
    }

    return result ??
        (throw StateError('Agent loop completed without a final result.'));
  }

  Stream<AgentRunEvent> stream(
    String prompt, {
    AgentSession? session,
    List<AgentMessage> transcript = const <AgentMessage>[],
  }) async* {
    final workingTranscript = <AgentMessage>[
      ...?session?.transcript,
      ...transcript,
    ];

    if (workingTranscript.isEmpty) {
      final configuredSystemPrompt = systemPrompt;
      if (configuredSystemPrompt != null) {
        workingTranscript.add(
          AgentMessage(role: AgentRole.system, content: configuredSystemPrompt),
        );
      }
    }

    workingTranscript.add(AgentMessage(role: AgentRole.user, content: prompt));

    for (var step = 1; step <= maxSteps; step++) {
      final response = await _respond(workingTranscript);

      if (response.toolCalls.isEmpty) {
        final message = AgentMessage(
          role: AgentRole.assistant,
          content: response.parts.isEmpty ? (response.text ?? '') : '',
          parts: response.parts,
        );
        workingTranscript.add(message);
        yield AgentAssistantEvent(message: message);
        for (final part in message.parts) {
          yield AgentMessagePartEvent(message: message, part: part);
        }

        final result = AgentRunResult(
          output: message.content,
          transcript: List.unmodifiable(workingTranscript),
          session: AgentSession(transcript: workingTranscript),
          steps: step,
        );

        yield AgentRunCompleteEvent(result: result);
        return;
      }

      if (response.parts.isNotEmpty) {
        final assistantMessage = AgentMessage(
          role: AgentRole.assistant,
          parts: response.parts,
        );
        workingTranscript.add(assistantMessage);
        yield AgentAssistantEvent(message: assistantMessage);
        for (final part in assistantMessage.parts) {
          yield AgentMessagePartEvent(message: assistantMessage, part: part);
        }
      }

      for (final toolCall in response.toolCalls) {
        final assistantMessage = AgentMessage(
          role: AgentRole.assistant,
          content: 'Calling tool `${toolCall.name}`',
          parts: <MessagePart>[
            ToolPart(
              callId: toolCall.id,
              name: toolCall.name,
              state: ToolPartState.pending,
              input: toolCall.input,
            ),
          ],
          toolCall: toolCall,
        );
        workingTranscript.add(assistantMessage);
        yield AgentAssistantEvent(message: assistantMessage);
        for (final part in assistantMessage.parts) {
          yield AgentMessagePartEvent(message: assistantMessage, part: part);
        }
        yield AgentToolCallEvent(call: toolCall);

        final tool = _tools[toolCall.name];
        final output = tool == null
            ? 'Tool `${toolCall.name}` is not registered.'
            : await tool.execute(toolCall.input);

        final toolResult = ToolResult(
          callId: toolCall.id,
          name: toolCall.name,
          output: output,
        );

        final toolMessage = AgentMessage(
          role: AgentRole.tool,
          content: output,
          parts: <MessagePart>[
            ToolPart(
              callId: toolCall.id,
              name: toolCall.name,
              state: ToolPartState.completed,
              input: toolCall.input,
              output: output,
            ),
          ],
          toolResult: toolResult,
        );
        workingTranscript.add(toolMessage);
        for (final part in toolMessage.parts) {
          yield AgentMessagePartEvent(message: toolMessage, part: part);
        }
        yield AgentToolResultEvent(result: toolResult);
      }
    }

    throw StateError(
      'Agent loop exceeded maxSteps=$maxSteps without a final response.',
    );
  }

  Future<AgentResponse> _respond(List<AgentMessage> transcript) async {
    try {
      return await _provider.respond(
        AgentTurn(
          messages: List.unmodifiable(transcript),
          tools: _tools.definitions,
        ),
      );
    } on AgentProviderException {
      rethrow;
    } catch (error, stackTrace) {
      throw AgentProviderException(
        provider: _provider.runtimeType.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
