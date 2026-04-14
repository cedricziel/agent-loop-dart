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
        expect(events[1], isA<AgentMessagePartEvent>());
        expect(events[2], isA<AgentToolCallEvent>());
        expect(events[3], isA<AgentMessagePartEvent>());
        expect(events[4], isA<AgentToolResultEvent>());
        expect(events[5], isA<AgentAssistantEvent>());
        expect(events[6], isA<AgentMessagePartEvent>());
        expect(events[7], isA<AgentRunCompleteEvent>());
      },
    );

    test('keeps non-streaming providers compatible', () async {
      final loop = AgentLoop(
        provider: _SequenceProvider(<AgentResponse>[
          AgentResponse(text: 'plain reply'),
        ]),
      );

      final events = await loop.stream('hello').toList();

      expect(events.map((event) => event.runtimeType), <Type>[
        AgentAssistantEvent,
        AgentMessagePartEvent,
        AgentRunCompleteEvent,
      ]);
      expect(
        (events.last as AgentRunCompleteEvent).result.output,
        'plain reply',
      );
    });

    test('emits streamed partial output before final tool activity', () async {
      final loop = AgentLoop(
        provider: _StreamingProvider(<List<AgentProviderEvent>>[
          <AgentProviderEvent>[
            const AgentProviderPartialOutputEvent(
              part: TextPart(text: 'Checking '),
            ),
            const AgentProviderPartialOutputEvent(
              part: TextPart(text: 'the clock'),
            ),
            AgentProviderResponseEvent(
              response: AgentResponse(
                parts: const <MessagePart>[
                  TextPart(text: 'Checking '),
                  TextPart(text: 'the clock'),
                ],
                toolCalls: const <ToolCall>[
                  ToolCall(id: 'clock-1', name: 'clock'),
                ],
              ),
            ),
          ],
          <AgentProviderEvent>[
            AgentProviderResponseEvent(
              response: AgentResponse(
                parts: const <MessagePart>[TextPart(text: 'done')],
              ),
            ),
          ],
        ]),
        tools: <AgentTool>[_ClockTool()],
      );

      final events = await loop.stream('time?').toList();

      expect(events[0], isA<AgentMessagePartEvent>());
      expect((events[0] as AgentMessagePartEvent).part, isA<TextPart>());
      expect(events[1], isA<AgentMessagePartEvent>());
      expect(events[2], isA<AgentAssistantEvent>());
      expect(events[3], isA<AgentAssistantEvent>());
      expect(events[4], isA<AgentMessagePartEvent>());
      expect(events[5], isA<AgentToolCallEvent>());
      expect(events.last, isA<AgentRunCompleteEvent>());
      expect(
        (events.last as AgentRunCompleteEvent).result.transcript.last.content,
        'done',
      );
    });

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

    test('derives final output from assistant text parts', () async {
      final loop = AgentLoop(
        provider: _SequenceProvider(<AgentResponse>[
          AgentResponse(
            parts: <MessagePart>[
              const TextPart(text: 'Generated '),
              const FilePart(path: 'build/report.txt', mimeType: 'text/plain'),
              const TextPart(text: 'report'),
            ],
          ),
        ]),
      );

      final result = await loop.run('generate a report');

      expect(result.output, 'Generated report');
      expect(result.transcript.last.parts, hasLength(3));
      expect(result.transcript.last.parts[1], isA<FilePart>());
    });

    test(
      'preserves provider parts and tool activity in transcript order',
      () async {
        final loop = AgentLoop(
          provider: _SequenceProvider(<AgentResponse>[
            AgentResponse(
              parts: <MessagePart>[
                const ReasoningPart(text: 'Need the clock tool first.'),
              ],
              toolCalls: <ToolCall>[
                const ToolCall(id: 'clock-1', name: 'clock'),
              ],
            ),
            AgentResponse(parts: <MessagePart>[const TextPart(text: 'done')]),
          ]),
          tools: <AgentTool>[_ClockTool()],
        );

        final result = await loop.run('time?');

        expect(result.transcript[1].parts.single, isA<ReasoningPart>());
        expect(result.transcript[2].parts.single, isA<ToolPart>());
        expect(
          (result.transcript[2].parts.single as ToolPart).state,
          ToolPartState.pending,
        );
        expect(result.transcript[3].parts.single, isA<ToolPart>());
        expect(
          (result.transcript[3].parts.single as ToolPart).state,
          ToolPartState.completed,
        );
        expect(result.transcript.last.content, 'done');
      },
    );

    test(
      'emits ordered part updates for assistant and tool activity',
      () async {
        final loop = AgentLoop(
          provider: _SequenceProvider(<AgentResponse>[
            AgentResponse(
              parts: <MessagePart>[
                const ReasoningPart(text: 'Need the clock tool first.'),
              ],
              toolCalls: <ToolCall>[
                const ToolCall(id: 'clock-1', name: 'clock'),
              ],
            ),
            AgentResponse(parts: <MessagePart>[const TextPart(text: 'done')]),
          ]),
          tools: <AgentTool>[_ClockTool()],
        );

        final events = await loop.stream('time?').toList();
        final partEvents = events.whereType<AgentMessagePartEvent>().toList();

        expect(partEvents.map((event) => event.part.runtimeType), <Type>[
          ReasoningPart,
          ToolPart,
          ToolPart,
          TextPart,
        ]);
        expect(
          events.indexWhere((event) => event is AgentAssistantEvent),
          lessThan(
            events.indexWhere((event) => event is AgentMessagePartEvent),
          ),
        );
        expect(events.last, isA<AgentRunCompleteEvent>());
      },
    );

    test('does not replay prior part events when resuming a session', () async {
      final loop = AgentLoop(
        provider: _SequenceProvider(<AgentResponse>[
          AgentResponse(
            parts: <MessagePart>[const TextPart(text: 'fresh reply')],
          ),
        ]),
      );
      final session = AgentSession(
        transcript: <AgentMessage>[
          const AgentMessage(
            role: AgentRole.assistant,
            parts: <MessagePart>[
              FilePart(path: 'build/old.txt', mimeType: 'text/plain'),
            ],
          ),
        ],
      );

      final events = await loop.stream('follow up', session: session).toList();
      final partEvents = events.whereType<AgentMessagePartEvent>().toList();

      expect(partEvents, hasLength(1));
      expect(partEvents.single.part, isA<TextPart>());
      expect(partEvents.single.part, isNot(isA<FilePart>()));
    });
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

class _StreamingProvider implements AgentStreamingProvider {
  _StreamingProvider(this._eventSequences);

  final List<List<AgentProviderEvent>> _eventSequences;
  var _index = 0;

  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    throw UnimplementedError('Streaming provider should use streamRespond.');
  }

  @override
  Stream<AgentProviderEvent> streamRespond(AgentTurn turn) async* {
    final events = _index < _eventSequences.length
        ? _eventSequences[_index++]
        : <AgentProviderEvent>[
            AgentProviderResponseEvent(
              response: AgentResponse(text: turn.messages.last.content),
            ),
          ];

    for (final event in events) {
      yield event;
    }
  }
}
