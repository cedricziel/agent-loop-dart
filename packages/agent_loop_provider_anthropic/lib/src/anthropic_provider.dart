import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_loop_core/agent_loop_core.dart';

class AnthropicProvider implements AgentStreamingProvider {
  AnthropicProvider({
    required this.apiKey,
    required this.model,
    Uri? baseUri,
    this.options = const AnthropicRequestOptions(),
    this.anthropicVersion = '2023-06-01',
    HttpClient? httpClient,
  }) : baseUri = baseUri ?? Uri.parse('https://api.anthropic.com/'),
       _httpClient = httpClient;

  final String apiKey;
  final String model;
  final Uri baseUri;
  final AnthropicRequestOptions options;
  final String anthropicVersion;
  final HttpClient? _httpClient;

  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    final payload = await _send(turn, stream: false);
    return _normalizeResponse(payload);
  }

  @override
  Stream<AgentProviderEvent> streamRespond(AgentTurn turn) async* {
    final client = _httpClient ?? HttpClient();
    try {
      final request = await client.postUrl(_messagesUri());
      _applyHeaders(request);
      request.write(jsonEncode(_requestBody(turn, stream: true)));

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final payload = await _readJsonBody(response);
        throw _httpError(
          _errorMessage(payload, response.statusCode),
          response.statusCode,
          retryAfter: _parseRetryAfter(response.headers),
        );
      }

      final blocks = <_AnthropicContentBlock>[];
      await for (final event in _decodeSse(response)) {
        switch (event.event) {
          case 'ping':
            continue;
          case 'error':
            final payload = _decodeJsonMap(event.data);
            throw _streamError(payload);
          case 'content_block_start':
            final payload = _decodeJsonMap(event.data);
            final index = _readIndex(payload);
            final block = _blockFromPayload(payload['content_block']);
            _setBlock(blocks, index, block);
            for (final part in block.initialParts) {
              yield AgentProviderPartialOutputEvent(part: part);
            }
          case 'content_block_delta':
            final payload = _decodeJsonMap(event.data);
            final index = _readIndex(payload);
            final delta = payload['delta'];
            if (delta is! Map) {
              continue;
            }
            final part = _applyDelta(
              _blockAt(blocks, index),
              Map<String, Object?>.from(delta),
            );
            if (part != null) {
              yield AgentProviderPartialOutputEvent(part: part);
            }
          case 'content_block_stop':
            final payload = _decodeJsonMap(event.data);
            final index = _readIndex(payload);
            _finalizeBlock(_blockAt(blocks, index));
          case 'message_start':
          case 'message_delta':
          case 'message_stop':
            continue;
          default:
            continue;
        }
      }

      final finalResponse = AgentResponse(
        parts: _responsePartsFromBlocks(blocks),
        toolCalls: _toolCallsFromBlocks(blocks),
      );
      yield AgentProviderResponseEvent(response: finalResponse);
    } on AgentProviderException {
      rethrow;
    } on SocketException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: 'AnthropicProvider',
        cause: error,
        stackTrace: stackTrace,
        kind: AgentProviderFailureKind.network,
        isRetryable: true,
      );
    } on HttpException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: 'AnthropicProvider',
        cause: error,
        stackTrace: stackTrace,
        kind: AgentProviderFailureKind.network,
        isRetryable: true,
      );
    } finally {
      if (_httpClient == null) {
        client.close(force: true);
      }
    }
  }

  Future<Map<String, Object?>> _send(
    AgentTurn turn, {
    required bool stream,
  }) async {
    final client = _httpClient ?? HttpClient();
    try {
      final request = await client.postUrl(_messagesUri());
      _applyHeaders(request);
      request.write(jsonEncode(_requestBody(turn, stream: stream)));

      final response = await request.close();
      final payload = await _readJsonBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpError(
          _errorMessage(payload, response.statusCode),
          response.statusCode,
          retryAfter: _parseRetryAfter(response.headers),
        );
      }

      return payload;
    } on AgentProviderException {
      rethrow;
    } on SocketException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: 'AnthropicProvider',
        cause: error,
        stackTrace: stackTrace,
        kind: AgentProviderFailureKind.network,
        isRetryable: true,
      );
    } on HttpException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: 'AnthropicProvider',
        cause: error,
        stackTrace: stackTrace,
        kind: AgentProviderFailureKind.network,
        isRetryable: true,
      );
    } finally {
      if (_httpClient == null) {
        client.close(force: true);
      }
    }
  }

  Uri _messagesUri() => baseUri.resolve('/v1/messages');

  void _applyHeaders(HttpClientRequest request) {
    request.headers.contentType = ContentType.json;
    request.headers.set('x-api-key', apiKey);
    request.headers.set('anthropic-version', anthropicVersion);
  }

  Map<String, Object?> _requestBody(AgentTurn turn, {required bool stream}) {
    final system = _systemPrompt(turn.messages);
    final body = <String, Object?>{
      'model': model,
      'max_tokens': options.maxTokens,
      'stream': stream,
      'messages': _requestMessages(turn.messages),
    };

    if (system != null && system.isNotEmpty) {
      body['system'] = system;
    }

    if (turn.tools.isNotEmpty) {
      body['tools'] = turn.tools.map(_toolToJson).toList(growable: false);
    }

    body.addAll(options.toJson());
    return body;
  }

  String? _systemPrompt(List<AgentMessage> messages) {
    final systemMessages = <String>[];
    for (final message in messages) {
      if (message.role != AgentRole.system) {
        break;
      }
      if (message.content.isNotEmpty) {
        systemMessages.add(message.content);
      }
    }
    if (systemMessages.isEmpty) {
      return null;
    }
    return systemMessages.join('\n\n');
  }

  List<Map<String, Object?>> _requestMessages(List<AgentMessage> transcript) {
    final messages = <_OutgoingAnthropicMessage>[];
    for (final message in transcript) {
      if (message.role == AgentRole.system) {
        continue;
      }
      final normalized = _toAnthropicMessage(message);
      if (normalized == null || normalized.content.isEmpty) {
        continue;
      }

      if (messages.isNotEmpty && messages.last.role == normalized.role) {
        messages.last.content.addAll(normalized.content);
      } else {
        messages.add(normalized);
      }
    }

    return messages.map((message) => message.toJson()).toList(growable: false);
  }

  _OutgoingAnthropicMessage? _toAnthropicMessage(AgentMessage message) {
    switch (message.role) {
      case AgentRole.user:
        return _OutgoingAnthropicMessage(
          role: 'user',
          content: _userContentBlocks(message),
        );
      case AgentRole.assistant:
        return _OutgoingAnthropicMessage(
          role: 'assistant',
          content: _assistantContentBlocks(message),
        );
      case AgentRole.tool:
        return _OutgoingAnthropicMessage(
          role: 'user',
          content: _toolResultBlocks(message),
        );
      case AgentRole.system:
        return null;
    }
  }

  List<Map<String, Object?>> _userContentBlocks(AgentMessage message) {
    final blocks = <Map<String, Object?>>[];
    for (final part in message.parts) {
      switch (part) {
        case TextPart(text: final text) when text.isNotEmpty:
          blocks.add(<String, Object?>{'type': 'text', 'text': text});
        case FilePart(path: final path, mimeType: final mimeType):
          blocks.add(<String, Object?>{
            'type': 'text',
            'text': 'File reference: $path ($mimeType)',
          });
        case TextPart():
          continue;
        case ReasoningPart():
          continue;
        case ToolPart():
          continue;
      }
    }

    if (blocks.isEmpty && message.content.isNotEmpty) {
      blocks.add(<String, Object?>{'type': 'text', 'text': message.content});
    }
    return blocks;
  }

  List<Map<String, Object?>> _assistantContentBlocks(AgentMessage message) {
    final blocks = <Map<String, Object?>>[];
    var hasToolUseBlock = false;

    for (final part in message.parts) {
      switch (part) {
        case TextPart(text: final text) when text.isNotEmpty:
          blocks.add(<String, Object?>{'type': 'text', 'text': text});
        case FilePart(path: final path, mimeType: final mimeType):
          blocks.add(<String, Object?>{
            'type': 'text',
            'text': 'File reference: $path ($mimeType)',
          });
        case ToolPart(
          callId: final callId,
          name: final name,
          state: ToolPartState.pending,
          input: final input,
        ):
          hasToolUseBlock = true;
          blocks.add(<String, Object?>{
            'type': 'tool_use',
            'id': callId,
            'name': name,
            'input': input,
          });
        case TextPart():
          continue;
        case ReasoningPart():
          continue;
        case ToolPart(state: ToolPartState.completed):
          continue;
      }
    }

    if (!hasToolUseBlock) {
      if (message.toolCall case final toolCall?) {
        blocks.add(<String, Object?>{
          'type': 'tool_use',
          'id': toolCall.id,
          'name': toolCall.name,
          'input': toolCall.input,
        });
      }
    }

    if (blocks.isEmpty && message.content.isNotEmpty) {
      blocks.add(<String, Object?>{'type': 'text', 'text': message.content});
    }
    return blocks;
  }

  List<Map<String, Object?>> _toolResultBlocks(AgentMessage message) {
    if (message.toolResult case final result?) {
      return <Map<String, Object?>>[
        <String, Object?>{
          'type': 'tool_result',
          'tool_use_id': result.callId,
          'content': result.output,
        },
      ];
    }

    if (message.content.isEmpty) {
      return const <Map<String, Object?>>[];
    }
    return <Map<String, Object?>>[
      <String, Object?>{'type': 'text', 'text': message.content},
    ];
  }

  Map<String, Object?> _toolToJson(ToolDefinition tool) => <String, Object?>{
    'name': tool.name,
    'description': tool.description,
    'input_schema': tool.inputSchema,
  };

  AgentResponse _normalizeResponse(Map<String, Object?> payload) {
    final content = payload['content'];
    final blocks = content is List
        ? content.map(_blockFromPayload).toList(growable: false)
        : const <_AnthropicContentBlock>[];
    return AgentResponse(
      parts: _responsePartsFromBlocks(blocks),
      toolCalls: _toolCallsFromBlocks(blocks),
    );
  }

  List<MessagePart> _responsePartsFromBlocks(
    List<_AnthropicContentBlock> blocks,
  ) {
    final parts = <MessagePart>[];
    for (final block in blocks) {
      switch (block.type) {
        case 'text':
          if (block.text.isNotEmpty) {
            parts.add(TextPart(text: block.text));
          }
        case 'thinking':
          if (block.text.isNotEmpty) {
            parts.add(ReasoningPart(text: block.text));
          }
        case 'tool_use':
          continue;
        default:
          continue;
      }
    }
    return List<MessagePart>.unmodifiable(parts);
  }

  List<ToolCall> _toolCallsFromBlocks(List<_AnthropicContentBlock> blocks) {
    final toolCalls = <ToolCall>[];
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      if (block.type != 'tool_use' ||
          block.name == null ||
          block.name!.isEmpty) {
        continue;
      }
      toolCalls.add(
        ToolCall(
          id: block.id ?? 'anthropic-tool-${index + 1}',
          name: block.name!,
          input: block.input,
        ),
      );
    }
    return List<ToolCall>.unmodifiable(toolCalls);
  }

  Future<Map<String, Object?>> _readJsonBody(
    HttpClientResponse response,
  ) async {
    final body = await response
        .cast<List<int>>()
        .transform(utf8.decoder)
        .join();
    if (body.isEmpty) {
      return <String, Object?>{};
    }
    try {
      return _decodeJsonMap(body);
    } on AgentProviderException {
      rethrow;
    }
  }

  Stream<_SseEvent> _decodeSse(HttpClientResponse response) async* {
    final lines = response
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String? event;
    final data = <String>[];
    await for (final line in lines) {
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          yield _SseEvent(event: event ?? 'message', data: data.join('\n'));
        }
        event = null;
        data.clear();
        continue;
      }

      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
    }

    if (data.isNotEmpty) {
      yield _SseEvent(event: event ?? 'message', data: data.join('\n'));
    }
  }

  _AnthropicContentBlock _blockFromPayload(Object? rawBlock) {
    if (rawBlock is! Map) {
      return _AnthropicContentBlock(type: 'unknown');
    }

    final block = Map<String, Object?>.from(rawBlock);
    final type = block['type'];
    if (type is! String || type.isEmpty) {
      return _AnthropicContentBlock(type: 'unknown');
    }

    switch (type) {
      case 'text':
        return _AnthropicContentBlock(
          type: type,
          text: block['text'] is String ? block['text']! as String : '',
        );
      case 'thinking':
        return _AnthropicContentBlock(
          type: type,
          text: block['thinking'] is String ? block['thinking']! as String : '',
        );
      case 'tool_use':
        return _AnthropicContentBlock(
          type: type,
          id: block['id'] as String?,
          name: block['name'] as String?,
          input: _normalizeMap(block['input']),
        );
      default:
        return _AnthropicContentBlock(type: type);
    }
  }

  int _readIndex(Map<String, Object?> payload) {
    final index = payload['index'];
    if (index is int) {
      return index;
    }
    throw _providerError(
      'stream payload is missing a valid content block index',
    );
  }

  _AnthropicContentBlock _blockAt(
    List<_AnthropicContentBlock> blocks,
    int index,
  ) {
    if (index < 0 || index >= blocks.length) {
      throw _providerError(
        'stream referenced unknown content block index $index',
      );
    }
    return blocks[index];
  }

  void _setBlock(
    List<_AnthropicContentBlock> blocks,
    int index,
    _AnthropicContentBlock block,
  ) {
    while (blocks.length <= index) {
      blocks.add(_AnthropicContentBlock(type: 'unknown'));
    }
    blocks[index] = block;
  }

  MessagePart? _applyDelta(
    _AnthropicContentBlock block,
    Map<String, Object?> delta,
  ) {
    final type = delta['type'];
    if (type is! String || type.isEmpty) {
      return null;
    }

    switch (type) {
      case 'text_delta':
        final textDelta = delta['text'];
        if (textDelta is! String || textDelta.isEmpty) {
          return null;
        }
        block.text += textDelta;
        return TextPart(text: textDelta);
      case 'thinking_delta':
        final thinkingDelta = delta['thinking'];
        if (thinkingDelta is! String || thinkingDelta.isEmpty) {
          return null;
        }
        block.text += thinkingDelta;
        return ReasoningPart(text: thinkingDelta);
      case 'input_json_delta':
        final partialJson = delta['partial_json'];
        if (partialJson is String && partialJson.isNotEmpty) {
          block.inputJsonBuffer.write(partialJson);
        }
        return null;
      default:
        return null;
    }
  }

  void _finalizeBlock(_AnthropicContentBlock block) {
    if (block.type != 'tool_use') {
      return;
    }
    final partialJson = block.inputJsonBuffer.toString();
    if (partialJson.isEmpty) {
      return;
    }
    final decoded = jsonDecode(partialJson);
    block.input = _normalizeMap(decoded);
  }

  String _errorMessage(Map<String, Object?> payload, int statusCode) {
    final error = payload['error'];
    if (error is Map) {
      final errorMap = Map<String, Object?>.from(error);
      final type = errorMap['type'];
      final message = errorMap['message'];
      if (message is String && message.isNotEmpty) {
        final prefix = type is String && type.isNotEmpty ? '$type: ' : '';
        return 'Anthropic request failed ($statusCode): $prefix$message';
      }
    }
    return 'Anthropic request failed with status $statusCode.';
  }

  AgentProviderException _streamError(Map<String, Object?> payload) {
    final message = _errorMessage(payload, 500);
    final error = payload['error'];
    final type = error is Map ? error['type'] : null;
    final kind = switch (type) {
      'rate_limit_error' => AgentProviderFailureKind.rateLimited,
      'overloaded_error' => AgentProviderFailureKind.unavailable,
      'invalid_request_error' => AgentProviderFailureKind.invalidRequest,
      _ => AgentProviderFailureKind.protocol,
    };
    return AgentProviderException(
      provider: 'AnthropicProvider',
      cause: StateError(message),
      stackTrace: StackTrace.current,
      kind: kind,
      isRetryable:
          kind == AgentProviderFailureKind.rateLimited ||
          kind == AgentProviderFailureKind.unavailable,
    );
  }

  AgentProviderException _providerError(String message) =>
      AgentProviderException(
        provider: 'AnthropicProvider',
        cause: StateError(message),
        stackTrace: StackTrace.current,
        kind: AgentProviderFailureKind.protocol,
      );

  AgentProviderException _httpError(
    String message,
    int statusCode, {
    Duration? retryAfter,
  }) {
    final isRetryable =
        statusCode == 408 ||
        statusCode == 409 ||
        statusCode == 429 ||
        statusCode >= 500;
    final kind = switch (statusCode) {
      408 => AgentProviderFailureKind.timeout,
      409 => AgentProviderFailureKind.unavailable,
      429 => AgentProviderFailureKind.rateLimited,
      final code when code >= 500 => AgentProviderFailureKind.unavailable,
      400 || 401 || 403 || 404 => AgentProviderFailureKind.invalidRequest,
      _ => AgentProviderFailureKind.protocol,
    };
    return AgentProviderException(
      provider: 'AnthropicProvider',
      cause: StateError(message),
      stackTrace: StackTrace.current,
      kind: kind,
      isRetryable: isRetryable,
      retryAfter: retryAfter,
    );
  }

  Duration? _parseRetryAfter(HttpHeaders headers) {
    final value = headers.value(HttpHeaders.retryAfterHeader);
    if (value == null || value.isEmpty) {
      return null;
    }
    final seconds = int.tryParse(value);
    if (seconds != null) {
      return Duration(seconds: seconds);
    }
    final retryAt = HttpDate.parse(value);
    return retryAt.difference(DateTime.now().toUtc());
  }

  Map<String, Object?> _decodeJsonMap(String source) {
    try {
      final decoded = jsonDecode(source);
      return _normalizeMap(decoded);
    } on FormatException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: 'AnthropicProvider',
        cause: error,
        stackTrace: stackTrace,
        kind: AgentProviderFailureKind.protocol,
      );
    }
  }

  Map<String, Object?> _normalizeMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, Object?>{};
  }
}

class AnthropicRequestOptions {
  const AnthropicRequestOptions({
    this.maxTokens = 1024,
    this.temperature,
    this.topP,
    this.topK,
    this.stopSequences = const <String>[],
    this.metadata,
    this.thinkingBudgetTokens,
  }) : assert(maxTokens > 0, 'maxTokens must be greater than zero.');

  final int maxTokens;
  final double? temperature;
  final double? topP;
  final int? topK;
  final List<String> stopSequences;
  final Map<String, Object?>? metadata;
  final int? thinkingBudgetTokens;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (topK != null) 'top_k': topK,
      if (stopSequences.isNotEmpty) 'stop_sequences': stopSequences,
      if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
      if (thinkingBudgetTokens != null)
        'thinking': <String, Object?>{
          'type': 'enabled',
          'budget_tokens': thinkingBudgetTokens,
        },
    };
  }
}

class _OutgoingAnthropicMessage {
  _OutgoingAnthropicMessage({required this.role, required this.content});

  final String role;
  final List<Map<String, Object?>> content;

  Map<String, Object?> toJson() => <String, Object?>{
    'role': role,
    'content': content,
  };
}

class _AnthropicContentBlock {
  _AnthropicContentBlock({
    required this.type,
    this.id,
    this.name,
    this.text = '',
    this.input = const <String, Object?>{},
  });

  final String type;
  final String? id;
  final String? name;

  String text;
  Map<String, Object?> input;
  final StringBuffer inputJsonBuffer = StringBuffer();

  List<MessagePart> get initialParts => switch (type) {
    'text' when text.isNotEmpty => <MessagePart>[TextPart(text: text)],
    'thinking' when text.isNotEmpty => <MessagePart>[ReasoningPart(text: text)],
    _ => const <MessagePart>[],
  };
}

class _SseEvent {
  const _SseEvent({required this.event, required this.data});

  final String event;
  final String data;
}
