import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_loop_core/agent_loop_core.dart';
import 'package:agent_loop_provider_ollama/agent_loop_provider_ollama.dart';
import 'package:test/test.dart';

void main() {
  group('OllamaProvider', () {
    test(
      'sends chat requests over HTTP and normalizes successful responses',
      () async {
        Map<String, Object?>? capturedRequest;
        final server = await _FakeOllamaServer.start((request) async {
          capturedRequest = await request.readJson();
          request.replyJson(<String, Object?>{
            'message': <String, Object?>{
              'role': 'assistant',
              'content': 'Hello from Ollama',
            },
            'done': true,
          });
        });
        addTearDown(server.close);

        final provider = OllamaProvider(
          model: 'llama3.2',
          baseUri: server.baseUri,
          options: const OllamaRequestOptions(temperature: 0.3, numPredict: 32),
        );

        final response = await provider.respond(
          AgentTurn(
            messages: const <AgentMessage>[
              AgentMessage(role: AgentRole.user, content: 'hello'),
            ],
            tools: const <ToolDefinition>[
              ToolDefinition(name: 'clock', description: 'Get the time.'),
            ],
          ),
        );

        expect(response.text, 'Hello from Ollama');
        expect(capturedRequest?['model'], 'llama3.2');
        expect(capturedRequest?['stream'], isFalse);
        expect(
          (capturedRequest?['messages'] as List).single['content'],
          'hello',
        );
        expect(
          (capturedRequest?['tools'] as List).single['function']['name'],
          'clock',
        );
        expect((capturedRequest?['options'] as Map)['num_predict'], 32);
      },
    );

    test(
      'serializes plain content-only messages into outgoing chat payloads',
      () async {
        Map<String, Object?>? capturedRequest;
        final server = await _FakeOllamaServer.start((request) async {
          capturedRequest = await request.readJson();
          request.replyJson(<String, Object?>{
            'message': <String, Object?>{'role': 'assistant', 'content': 'ok'},
            'done': true,
          });
        });
        addTearDown(server.close);

        final provider = OllamaProvider(
          model: 'gemma4:e4b',
          baseUri: server.baseUri,
        );

        await provider.respond(
          const AgentTurn(
            messages: <AgentMessage>[
              AgentMessage(role: AgentRole.user, content: 'What time is it?'),
            ],
            tools: <ToolDefinition>[],
          ),
        );

        expect(
          (capturedRequest?['messages'] as List).single['content'],
          'What time is it?',
        );
      },
    );

    test(
      'streams chunks, assembles the final response, and preserves event order',
      () async {
        final server = await _FakeOllamaServer.start((request) async {
          await request.readJson();
          request.replyStream(<Map<String, Object?>>[
            <String, Object?>{
              'message': <String, Object?>{
                'role': 'assistant',
                'content': 'Hel',
              },
              'done': false,
            },
            <String, Object?>{
              'message': <String, Object?>{
                'role': 'assistant',
                'content': 'lo',
              },
              'done': false,
            },
            <String, Object?>{
              'message': <String, Object?>{
                'role': 'assistant',
                'content': 'Hello',
              },
              'done': true,
            },
          ]);
        });
        addTearDown(server.close);

        final provider = OllamaProvider(
          model: 'llama3.2',
          baseUri: server.baseUri,
        );
        final loop = AgentLoop(provider: provider);

        final events = await loop.stream('hello').toList();

        expect(events[0], isA<AgentMessagePartEvent>());
        expect((events[0] as AgentMessagePartEvent).part, isA<TextPart>());
        expect((events[0] as AgentMessagePartEvent).message.content, 'Hel');
        expect(events[1], isA<AgentMessagePartEvent>());
        expect((events[1] as AgentMessagePartEvent).message.content, 'Hello');
        expect(events[2], isA<AgentAssistantEvent>());
        expect(events[3], isA<AgentRunCompleteEvent>());
        expect((events[3] as AgentRunCompleteEvent).result.output, 'Hello');
      },
    );

    test(
      'preserves tool calls that arrive in non-terminal streaming chunks',
      () async {
        final server = await _FakeOllamaServer.start((request) async {
          await request.readJson();
          request.replyStream(<Map<String, Object?>>[
            <String, Object?>{
              'message': <String, Object?>{
                'role': 'assistant',
                'content': '',
                'tool_calls': <Object?>[
                  <String, Object?>{
                    'id': 'call-get-time',
                    'function': <String, Object?>{
                      'name': 'get_time',
                      'arguments': <String, Object?>{},
                    },
                  },
                ],
              },
              'done': false,
            },
            <String, Object?>{
              'message': <String, Object?>{'role': 'assistant', 'content': ''},
              'done': true,
            },
          ]);
        });
        addTearDown(server.close);

        final provider = OllamaProvider(
          model: 'gemma4:e4b',
          baseUri: server.baseUri,
        );

        final events = await provider
            .streamRespond(
              const AgentTurn(
                messages: <AgentMessage>[
                  AgentMessage(role: AgentRole.user, content: 'time?'),
                ],
                tools: <ToolDefinition>[
                  ToolDefinition(name: 'get_time', description: 'Get time'),
                ],
              ),
            )
            .toList();

        expect(events.last, isA<AgentProviderResponseEvent>());
        final response = (events.last as AgentProviderResponseEvent).response;
        expect(response.toolCalls, hasLength(1));
        expect(response.toolCalls.single.name, 'get_time');
        expect(response.toolCalls.single.id, 'call-get-time');
      },
    );

    test(
      'normalizes tool calls and reasoning parts from Ollama responses',
      () async {
        final server = await _FakeOllamaServer.start((request) async {
          await request.readJson();
          request.replyJson(<String, Object?>{
            'message': <String, Object?>{
              'role': 'assistant',
              'thinking': 'Need the clock tool first.',
              'content': 'Checking the current time.',
              'tool_calls': <Object?>[
                <String, Object?>{
                  'id': 'tool-1',
                  'function': <String, Object?>{
                    'name': 'clock',
                    'arguments': <String, Object?>{'zone': 'utc'},
                  },
                },
              ],
            },
            'done': true,
          });
        });
        addTearDown(server.close);

        final provider = OllamaProvider(
          model: 'llama3.2',
          baseUri: server.baseUri,
        );
        final response = await provider.respond(
          const AgentTurn(
            messages: <AgentMessage>[
              AgentMessage(role: AgentRole.user, content: 'what time is it?'),
            ],
            tools: <ToolDefinition>[],
          ),
        );

        expect(response.parts[0], isA<ReasoningPart>());
        expect(
          (response.parts[0] as ReasoningPart).text,
          'Need the clock tool first.',
        );
        expect(response.parts[1], isA<TextPart>());
        expect(response.toolCalls.single.name, 'clock');
        expect(response.toolCalls.single.input, <String, Object?>{
          'zone': 'utc',
        });
      },
    );

    test(
      'maps HTTP and streaming failures into AgentProviderException',
      () async {
        final failureServer = await _FakeOllamaServer.start((request) async {
          await request.readJson();
          request.replyJson(<String, Object?>{
            'error': 'model not found',
          }, statusCode: 404);
        });
        addTearDown(failureServer.close);

        final provider = OllamaProvider(
          model: 'missing-model',
          baseUri: failureServer.baseUri,
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
                .having((error) => error.provider, 'provider', 'OllamaProvider')
                .having(
                  (error) => error.kind,
                  'kind',
                  AgentProviderFailureKind.invalidRequest,
                )
                .having((error) => error.isRetryable, 'isRetryable', isFalse),
          ),
        );

        final rateLimitedServer = await _FakeOllamaServer.start((
          request,
        ) async {
          await request.readJson();
          request.replyJson(<String, Object?>{
            'error': 'too many requests',
          }, statusCode: 429);
        });
        addTearDown(rateLimitedServer.close);

        final rateLimitedProvider = OllamaProvider(
          model: 'llama3.2',
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
                .having((error) => error.isRetryable, 'isRetryable', isTrue),
          ),
        );

        final brokenStreamServer = await _FakeOllamaServer.start((
          request,
        ) async {
          await request.readJson();
          request.replyRawLines(<String>['{not-json}']);
        });
        addTearDown(brokenStreamServer.close);

        final streamingProvider = OllamaProvider(
          model: 'llama3.2',
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

class _FakeOllamaServer {
  _FakeOllamaServer._(this._server, this.baseUri);

  final HttpServer _server;
  final Uri baseUri;

  static Future<_FakeOllamaServer> start(
    Future<void> Function(_FakeOllamaRequest request) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(() async {
      await for (final request in server) {
        await handler(_FakeOllamaRequest(request));
      }
    }());
    return _FakeOllamaServer._(
      server,
      Uri.parse('http://${server.address.host}:${server.port}/'),
    );
  }

  Future<void> close() => _server.close(force: true);
}

class _FakeOllamaRequest {
  const _FakeOllamaRequest(this._request);

  final HttpRequest _request;

  Future<Map<String, Object?>> readJson() async {
    final body = await _request
        .cast<List<int>>()
        .transform(utf8.decoder)
        .join();
    return Map<String, Object?>.from(jsonDecode(body) as Map);
  }

  void replyJson(Map<String, Object?> payload, {int statusCode = 200}) {
    _request.response.statusCode = statusCode;
    _request.response.headers.contentType = ContentType.json;
    _request.response.write(jsonEncode(payload));
    unawaited(_request.response.close());
  }

  void replyStream(List<Map<String, Object?>> payloads) {
    _request.response.statusCode = 200;
    _request.response.headers.contentType = ContentType(
      'application',
      'x-ndjson',
    );
    for (final payload in payloads) {
      _request.response.writeln(jsonEncode(payload));
    }
    unawaited(_request.response.close());
  }

  void replyRawLines(List<String> lines) {
    _request.response.statusCode = 200;
    _request.response.headers.contentType = ContentType(
      'application',
      'x-ndjson',
    );
    for (final line in lines) {
      _request.response.writeln(line);
    }
    unawaited(_request.response.close());
  }
}
