import 'package:agent_loop_core/agent_loop_core.dart';
import 'package:test/test.dart';

void main() {
  group('AgentLoop', () {
    test('normalizes tool calls and records tool results', () async {
      final loop = AgentLoop(
        provider: _SequenceProvider(<AgentResponse>[
          AgentResponse(
            toolCalls: <ToolCall>[
              const ToolCall(
                id: 'clock-1',
                name: 'clock',
                input: <String, Object?>{'zone': 'utc'},
              ),
            ],
          ),
          AgentResponse(text: 'It is noon.'),
        ]),
        tools: <AgentTool>[_ClockTool()],
      );

      final result = await loop.run('What time is it?');

      expect(result.output, 'It is noon.');
      expect(result.transcript[0].role, AgentRole.user);
      expect(result.transcript[1].toolCall?.name, 'clock');
      expect(result.transcript[2].toolResult?.output, '2026-04-13T12:00:00Z');
      expect(result.session.transcript, hasLength(result.transcript.length));
    });

    test('wraps provider failures distinctly from tool failures', () async {
      final loop = AgentLoop(provider: _ThrowingProvider());

      await expectLater(
        loop.run('hello'),
        throwsA(
          isA<AgentProviderException>().having(
            (error) => error.cause,
            'cause',
            isA<StateError>(),
          ),
        ),
      );
    });

    test(
      'emits ordered lifecycle events for tool execution and completion',
      () async {
        final loop = AgentLoop(
          provider: _SequenceProvider(<AgentResponse>[
            AgentResponse(
              toolCalls: <ToolCall>[
                const ToolCall(id: 'clock-1', name: 'clock'),
              ],
            ),
            AgentResponse(text: 'done'),
          ]),
          tools: <AgentTool>[_ClockTool()],
        );

        final events = await loop.stream('time?').toList();

        expect(events[0], isA<AgentAssistantEvent>());
        expect(events[1], isA<AgentToolCallEvent>());
        expect(events[2], isA<AgentToolResultEvent>());
        expect(events[3], isA<AgentAssistantEvent>());
        expect(events[4], isA<AgentRunCompleteEvent>());
      },
    );

    test(
      'resumes from prior session while keeping one-shot flow additive',
      () async {
        final loop = AgentLoop(provider: const LoopbackModel());

        final first = await loop.run('hello');
        final resumed = await loop.run('follow up', session: first.session);

        expect(first.output, 'hello');
        expect(resumed.output, 'follow up');
        expect(resumed.transcript.map((message) => message.content), <String>[
          'hello',
          'hello',
          'follow up',
          'follow up',
        ]);
      },
    );
  });
}

class _ClockTool implements AgentTool {
  @override
  ToolDefinition get definition =>
      const ToolDefinition(name: 'clock', description: 'Returns a fixed time.');

  @override
  Future<String> execute(Map<String, Object?> input) async {
    return '2026-04-13T12:00:00Z';
  }
}

class _SequenceProvider implements AgentProvider {
  _SequenceProvider(this._responses);

  final List<AgentResponse> _responses;
  var _index = 0;

  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    if (_index >= _responses.length) {
      return AgentResponse(text: turn.messages.last.content);
    }

    return _responses[_index++];
  }
}

class _ThrowingProvider implements AgentProvider {
  @override
  Future<AgentResponse> respond(AgentTurn turn) {
    throw StateError('provider failed');
  }
}
