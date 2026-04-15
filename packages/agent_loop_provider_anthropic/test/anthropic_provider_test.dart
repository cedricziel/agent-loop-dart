import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_loop_core/agent_loop_core.dart';
import 'package:agent_loop_provider_anthropic/agent_loop_provider_anthropic.dart';
import 'package:test/test.dart';

void main() {
  group('AnthropicProvider', () {
    test(
      'sends messages requests over HTTP and normalizes responses',
      () async {
        Map<String, Object?>? capturedRequest;
        String? capturedApiKey;
        String? capturedVersion;
        final server = await _FakeAnthropicServer.start((request) async {
          capturedApiKey = request.header('x-api-key');
          capturedVersion = request.header('anthropic-version');
          capturedRequest = await request.readJson();
          request.replyJson(<String, Object?>{
            'id': 'msg_1',
            'type': 'message',
            'role': 'assistant',
            'content': <Object?>[
              <String, Object?>{'type': 'text', 'text': 'Hello from Claude'},
            ],
          });
        });
        addTearDown(server.close);

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-7-sonnet-latest',
          baseUri: server.baseUri,
          options: const AnthropicRequestOptions(
            maxTokens: 256,
            temperature: 0.2,
          ),
        );

        final response = await provider.respond(
          const AgentTurn(
            messages: <AgentMessage>[
              AgentMessage(role: AgentRole.system, content: 'Be concise.'),
              AgentMessage(role: AgentRole.user, content: 'hello'),
            ],
            tools: <ToolDefinition>[
              ToolDefinition(name: 'clock', description: 'Get the time.'),
            ],
          ),
        );

        expect(response.text, 'Hello from Claude');
        expect(capturedApiKey, 'test-key');
        expect(capturedVersion, '2023-06-01');
        expect(capturedRequest?['model'], 'claude-3-7-sonnet-latest');
        expect(capturedRequest?['max_tokens'], 256);
        expect(capturedRequest?['stream'], isFalse);
        expect(capturedRequest?['system'], 'Be concise.');
        expect((capturedRequest?['messages'] as List).single['role'], 'user');
        expect(
          ((capturedRequest?['messages'] as List).single['content'] as List)
              .single['text'],
          'hello',
        );
        expect((capturedRequest?['tools'] as List).single['name'], 'clock');
      },
    );

    test('serializes tool results into Anthropic tool_result blocks', () async {
      Map<String, Object?>? capturedRequest;
      final server = await _FakeAnthropicServer.start((request) async {
        capturedRequest = await request.readJson();
        request.replyJson(<String, Object?>{
          'id': 'msg_2',
          'type': 'message',
          'role': 'assistant',
          'content': <Object?>[
            <String, Object?>{'type': 'text', 'text': 'done'},
          ],
        });
      });
      addTearDown(server.close);

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-7-sonnet-latest',
        baseUri: server.baseUri,
      );

      await provider.respond(
        const AgentTurn(
          messages: <AgentMessage>[
            AgentMessage(
              role: AgentRole.assistant,
              parts: <MessagePart>[
                ToolPart(
                  callId: 'tool-1',
                  name: 'clock',
                  state: ToolPartState.pending,
                  input: <String, Object?>{'zone': 'utc'},
                ),
              ],
              toolCall: ToolCall(
                id: 'tool-1',
                name: 'clock',
                input: <String, Object?>{'zone': 'utc'},
              ),
            ),
            AgentMessage(
              role: AgentRole.tool,
              toolResult: ToolResult(
                callId: 'tool-1',
                name: 'clock',
                output: '2026-04-15T10:00:00Z',
              ),
            ),
          ],
          tools: <ToolDefinition>[],
        ),
      );

      final messages = capturedRequest?['messages'] as List;
      expect(messages, hasLength(2));
      expect(messages[0]['role'], 'assistant');
      expect((messages[0]['content'] as List).single['type'], 'tool_use');
      expect(messages[1]['role'], 'user');
      expect((messages[1]['content'] as List).single['type'], 'tool_result');
      expect((messages[1]['content'] as List).single['tool_use_id'], 'tool-1');
    });

    test(
      'streams text chunks, assembles the final response, and preserves order',
      () async {
        final server = await _FakeAnthropicServer.start((request) async {
          await request.readJson();
          request.replySse(<_SseFrame>[
            _SseFrame(
              event: 'content_block_start',
              data: <String, Object?>{
                'index': 0,
                'content_block': <String, Object?>{'type': 'text', 'text': ''},
              },
            ),
            _SseFrame(
              event: 'content_block_delta',
              data: <String, Object?>{
                'index': 0,
                'delta': <String, Object?>{'type': 'text_delta', 'text': 'Hel'},
              },
            ),
            _SseFrame(
              event: 'content_block_delta',
              data: <String, Object?>{
                'index': 0,
                'delta': <String, Object?>{'type': 'text_delta', 'text': 'lo'},
              },
            ),
            _SseFrame(
              event: 'content_block_stop',
              data: <String, Object?>{'index': 0},
            ),
            _SseFrame(event: 'message_stop', data: <String, Object?>{}),
          ]);
        });
        addTearDown(server.close);

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-7-sonnet-latest',
          baseUri: server.baseUri,
        );
        final loop = AgentLoop(provider: provider);

        final events = await loop.stream('hello').toList();

        expect(events[0], isA<AgentMessagePartEvent>());
        expect((events[0] as AgentMessagePartEvent).message.content, 'Hel');
        expect(events[1], isA<AgentMessagePartEvent>());
        expect((events[1] as AgentMessagePartEvent).message.content, 'Hello');
        expect(events[2], isA<AgentAssistantEvent>());
        expect(events[3], isA<AgentRunCompleteEvent>());
        expect((events[3] as AgentRunCompleteEvent).result.output, 'Hello');
      },
    );

    test(
      'normalizes tool calls and reasoning parts from Anthropic responses',
      () async {
        final server = await _FakeAnthropicServer.start((request) async {
          await request.readJson();
          request.replyJson(<String, Object?>{
            'id': 'msg_3',
            'type': 'message',
            'role': 'assistant',
            'content': <Object?>[
              <String, Object?>{
                'type': 'thinking',
                'thinking': 'Need the clock tool first.',
              },
              <String, Object?>{
                'type': 'tool_use',
                'id': 'toolu_1',
                'name': 'clock',
                'input': <String, Object?>{'zone': 'utc'},
              },
            ],
          });
        });
        addTearDown(server.close);

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-7-sonnet-latest',
          baseUri: server.baseUri,
        );
        final response = await provider.respond(
          const AgentTurn(
            messages: <AgentMessage>[
              AgentMessage(role: AgentRole.user, content: 'what time is it?'),
            ],
            tools: <ToolDefinition>[
              ToolDefinition(name: 'clock', description: 'Get the time.'),
            ],
          ),
        );

        expect(response.parts.single, isA<ReasoningPart>());
        expect(
          (response.parts.single as ReasoningPart).text,
          'Need the clock tool first.',
        );
        expect(response.toolCalls.single.id, 'toolu_1');
        expect(response.toolCalls.single.name, 'clock');
        expect(response.toolCalls.single.input, <String, Object?>{
          'zone': 'utc',
        });
      },
    );

    test(
      'preserves tool calls that arrive via streaming input_json_delta events',
      () async {
        final server = await _FakeAnthropicServer.start((request) async {
          await request.readJson();
          request.replySse(<_SseFrame>[
            _SseFrame(
              event: 'content_block_start',
              data: <String, Object?>{
                'index': 0,
                'content_block': <String, Object?>{
                  'type': 'tool_use',
                  'id': 'toolu_1',
                  'name': 'clock',
                  'input': <String, Object?>{},
                },
              },
            ),
            _SseFrame(
              event: 'content_block_delta',
              data: <String, Object?>{
                'index': 0,
                'delta': <String, Object?>{
                  'type': 'input_json_delta',
                  'partial_json': '{"zone":"utc"}',
                },
              },
            ),
            _SseFrame(
              event: 'content_block_stop',
              data: <String, Object?>{'index': 0},
            ),
            _SseFrame(event: 'message_stop', data: <String, Object?>{}),
          ]);
        });
        addTearDown(server.close);

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-7-sonnet-latest',
          baseUri: server.baseUri,
        );

        final events = await provider
            .streamRespond(
              const AgentTurn(
                messages: <AgentMessage>[
                  AgentMessage(role: AgentRole.user, content: 'time?'),
                ],
                tools: <ToolDefinition>[
                  ToolDefinition(name: 'clock', description: 'Get the time.'),
                ],
              ),
            )
            .toList();

        final response = (events.last as AgentProviderResponseEvent).response;
        expect(response.toolCalls, hasLength(1));
        expect(response.toolCalls.single.name, 'clock');
        expect(response.toolCalls.single.input, <String, Object?>{
          'zone': 'utc',
        });
      },
    );

    test(
      'maps HTTP and streaming failures into AgentProviderException',
      () async {
        final invalidRequestServer = await _FakeAnthropicServer.start((
          request,
        ) async {
          await request.readJson();
          request.replyJson(<String, Object?>{
            'error': <String, Object?>{
              'type': 'invalid_request_error',
              'message': 'model not found',
            },
          }, statusCode: 404);
        });
        addTearDown(invalidRequestServer.close);

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'missing-model',
          baseUri: invalidRequestServer.baseUri,
        );

        await expectLater(
          provider.respond(
            const AgentTurn(
              messages: <AgentMessage>[
                AgentMessage(role: AgentRole.user, content: 'hello'),
              ],
              tools: <ToolDefinition>[],
            ),
          ),
          throwsA(
            isA<AgentProviderException>()
                .having(
                  (error) => error.provider,
                  'provider',
                  'AnthropicProvider',
                )
                .having(
                  (error) => error.kind,
                  'kind',
                  AgentProviderFailureKind.invalidRequest,
                )
                .having((error) => error.isRetryable, 'isRetryable', isFalse),
          ),
        );

        final rateLimitedServer = await _FakeAnthropicServer.start((
          request,
        ) async {
          await request.readJson();
          request.replyJson(
            <String, Object?>{
              'error': <String, Object?>{
                'type': 'rate_limit_error',
                'message': 'too many requests',
              },
            },
            statusCode: 429,
            headers: <String, String>{HttpHeaders.retryAfterHeader: '2'},
          );
        });
        addTearDown(rateLimitedServer.close);

        final rateLimitedProvider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-7-sonnet-latest',
          baseUri: rateLimitedServer.baseUri,
        );

        await expectLater(
          rateLimitedProvider.respond(
            const AgentTurn(
              messages: <AgentMessage>[
                AgentMessage(role: AgentRole.user, content: 'hello'),
              ],
              tools: <ToolDefinition>[],
            ),
          ),
          throwsA(
            isA<AgentProviderException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  AgentProviderFailureKind.rateLimited,
                )
                .having((error) => error.isRetryable, 'isRetryable', isTrue)
                .having(
                  (error) => error.retryAfter,
                  'retryAfter',
                  const Duration(seconds: 2),
                ),
          ),
        );

        final brokenStreamServer = await _FakeAnthropicServer.start((
          request,
        ) async {
          await request.readJson();
          request.replyRawSse(<String>[
            'event: content_block_start',
            'data: {not-json}',
            '',
          ]);
        });
        addTearDown(brokenStreamServer.close);

        final streamingProvider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-7-sonnet-latest',
          baseUri: brokenStreamServer.baseUri,
        );

        await expectLater(
          streamingProvider
              .streamRespond(
                const AgentTurn(
                  messages: <AgentMessage>[
                    AgentMessage(role: AgentRole.user, content: 'hello'),
                  ],
                  tools: <ToolDefinition>[],
                ),
              )
              .drain<void>(),
          throwsA(
            isA<AgentProviderException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  AgentProviderFailureKind.protocol,
                )
                .having((error) => error.isRetryable, 'isRetryable', isFalse),
          ),
        );
      },
    );
  });
}

class _FakeAnthropicServer {
  _FakeAnthropicServer._(this._server, this.baseUri);

  final HttpServer _server;
  final Uri baseUri;

  static Future<_FakeAnthropicServer> start(
    Future<void> Function(_FakeAnthropicRequest request) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(() async {
      await for (final request in server) {
        await handler(_FakeAnthropicRequest(request));
      }
    }());
    return _FakeAnthropicServer._(
      server,
      Uri.parse('http://${server.address.host}:${server.port}/'),
    );
  }

  Future<void> close() => _server.close(force: true);
}

class _FakeAnthropicRequest {
  const _FakeAnthropicRequest(this._request);

  final HttpRequest _request;

  String? header(String name) => _request.headers.value(name);

  Future<Map<String, Object?>> readJson() async {
    final body = await _request
        .cast<List<int>>()
        .transform(utf8.decoder)
        .join();
    return Map<String, Object?>.from(jsonDecode(body) as Map);
  }

  void replyJson(
    Map<String, Object?> payload, {
    int statusCode = 200,
    Map<String, String> headers = const <String, String>{},
  }) {
    _request.response.statusCode = statusCode;
    _request.response.headers.contentType = ContentType.json;
    for (final entry in headers.entries) {
      _request.response.headers.set(entry.key, entry.value);
    }
    _request.response.write(jsonEncode(payload));
    unawaited(_request.response.close());
  }

  void replySse(List<_SseFrame> frames) {
    _request.response.statusCode = 200;
    _request.response.headers.contentType = ContentType('text', 'event-stream');
    for (final frame in frames) {
      _request.response.writeln('event: ${frame.event}');
      _request.response.writeln('data: ${jsonEncode(frame.data)}');
      _request.response.writeln();
    }
    unawaited(_request.response.close());
  }

  void replyRawSse(List<String> lines) {
    _request.response.statusCode = 200;
    _request.response.headers.contentType = ContentType('text', 'event-stream');
    for (final line in lines) {
      _request.response.writeln(line);
    }
    unawaited(_request.response.close());
  }
}

class _SseFrame {
  const _SseFrame({required this.event, required this.data});

  final String event;
  final Map<String, Object?> data;
}
