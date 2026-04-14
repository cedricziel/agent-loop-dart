import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_loop_core/agent_loop_core.dart';

class OllamaProvider implements AgentStreamingProvider {
  OllamaProvider({
    required this.model,
    Uri? baseUri,
    this.options = const OllamaRequestOptions(),
    HttpClient? httpClient,
  }) : baseUri = baseUri ?? Uri.parse('http://127.0.0.1:11434/'),
       _httpClient = httpClient;

  final String model;
  final Uri baseUri;
  final OllamaRequestOptions options;
  final HttpClient? _httpClient;

  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    final payload = await _send(turn, stream: false);
    return _normalizeResponse(payload);
  }

  @override
  Stream<AgentProviderEvent> streamRespond(AgentTurn turn) async* {
    final accumulatedTextParts = <MessagePart>[];
    final accumulatedToolCalls = <ToolCall>[];
    Map<String, Object?>? terminalPayload;

    final client = _httpClient ?? HttpClient();
    try {
      final request = await client.postUrl(_chatUri());
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(_requestBody(turn, stream: true)));

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response
            .cast<List<int>>()
            .transform(utf8.decoder)
            .join();
        final payload = body.isEmpty
            ? <String, Object?>{}
            : jsonDecode(body) as Map<String, Object?>;
        throw _httpError(
          _errorMessage(payload, response.statusCode),
          response.statusCode,
        );
      }

      await for (final line
          in response
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .where((value) => value.trim().isNotEmpty)) {
        final payload = _decodeStreamPayload(line);
        terminalPayload = payload;
        final message = _messageFromPayload(payload);
        final partialParts = _partsFromMessage(message);
        final partialToolCalls = _toolCallsFromMessage(message);
        final done = payload['done'] == true;

        if (!done) {
          for (final part in partialParts) {
            accumulatedTextParts.add(part);
            yield AgentProviderPartialOutputEvent(part: part);
          }
          _mergeToolCalls(accumulatedToolCalls, partialToolCalls);
        }
      }

      if (terminalPayload == null) {
        throw _providerError('stream completed without a terminal response');
      }

      final normalizedResponse = _normalizeResponse(
        terminalPayload,
        streamedParts: accumulatedTextParts,
        streamedToolCalls: accumulatedToolCalls,
      );
      yield AgentProviderResponseEvent(response: normalizedResponse);
    } on AgentProviderException {
      rethrow;
    } on SocketException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: 'OllamaProvider',
        cause: error,
        stackTrace: stackTrace,
        kind: AgentProviderFailureKind.network,
        isRetryable: true,
      );
    } on HttpException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: 'OllamaProvider',
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
      final request = await client.postUrl(_chatUri());
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(_requestBody(turn, stream: stream)));

      final response = await request.close();
      final body = await response
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join();
      final payload = body.isEmpty
          ? <String, Object?>{}
          : jsonDecode(body) as Map<String, Object?>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpError(
          _errorMessage(payload, response.statusCode),
          response.statusCode,
        );
      }

      return payload;
    } on AgentProviderException {
      rethrow;
    } on SocketException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: 'OllamaProvider',
        cause: error,
        stackTrace: stackTrace,
        kind: AgentProviderFailureKind.network,
        isRetryable: true,
      );
    } on HttpException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: 'OllamaProvider',
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

  Uri _chatUri() => baseUri.resolve('/api/chat');

  Map<String, Object?> _requestBody(AgentTurn turn, {required bool stream}) {
    final body = <String, Object?>{
      'model': model,
      'stream': stream,
      'messages': turn.messages.map(_messageToJson).toList(growable: false),
    };

    if (turn.tools.isNotEmpty) {
      body['tools'] = turn.tools.map(_toolToJson).toList(growable: false);
    }

    final requestOptions = options.toJson();
    if (requestOptions.isNotEmpty) {
      body['options'] = requestOptions;
    }

    return body;
  }

  Map<String, Object?> _messageToJson(AgentMessage message) {
    final json = <String, Object?>{
      'role': message.role.name,
      'content': message.content,
    };

    if (message.toolCall case final toolCall?) {
      json['tool_calls'] = <Object?>[_toolCallToJson(toolCall)];
    }

    return json;
  }

  Map<String, Object?> _toolToJson(ToolDefinition tool) => <String, Object?>{
    'type': 'function',
    'function': <String, Object?>{
      'name': tool.name,
      'description': tool.description,
      'parameters': tool.inputSchema,
    },
  };

  Map<String, Object?> _toolCallToJson(ToolCall toolCall) => <String, Object?>{
    'function': <String, Object?>{
      'name': toolCall.name,
      'arguments': toolCall.input,
    },
  };

  AgentResponse _normalizeResponse(
    Map<String, Object?> payload, {
    List<MessagePart> streamedParts = const <MessagePart>[],
    List<ToolCall> streamedToolCalls = const <ToolCall>[],
  }) {
    final message = _messageFromPayload(payload);
    final responseParts = _partsFromMessage(message);
    final parts = streamedParts.isNotEmpty && responseParts.isEmpty
        ? List<MessagePart>.unmodifiable(streamedParts)
        : responseParts;
    final responseToolCalls = _toolCallsFromMessage(message);
    final toolCalls = responseToolCalls.isEmpty && streamedToolCalls.isNotEmpty
        ? List<ToolCall>.unmodifiable(streamedToolCalls)
        : responseToolCalls;

    return AgentResponse(parts: parts, toolCalls: toolCalls);
  }

  void _mergeToolCalls(List<ToolCall> accumulated, List<ToolCall> incoming) {
    for (final toolCall in incoming) {
      final existingIndex = accumulated.indexWhere(
        (candidate) => candidate.id == toolCall.id,
      );
      if (existingIndex == -1) {
        accumulated.add(toolCall);
      } else {
        accumulated[existingIndex] = toolCall;
      }
    }
  }

  Map<String, Object?> _messageFromPayload(Map<String, Object?> payload) {
    final message = payload['message'];
    if (message is Map<String, Object?>) {
      return message;
    }

    if (message is Map) {
      return Map<String, Object?>.from(message);
    }

    return <String, Object?>{};
  }

  List<MessagePart> _partsFromMessage(Map<String, Object?> message) {
    final parts = <MessagePart>[];
    final thinking = message['thinking'];
    if (thinking is String && thinking.isNotEmpty) {
      parts.add(ReasoningPart(text: thinking));
    }

    final content = message['content'];
    if (content is String && content.isNotEmpty) {
      parts.add(TextPart(text: content));
    }

    return List<MessagePart>.unmodifiable(parts);
  }

  List<ToolCall> _toolCallsFromMessage(Map<String, Object?> message) {
    final rawCalls = message['tool_calls'];
    if (rawCalls is! List) {
      return const <ToolCall>[];
    }

    final toolCalls = <ToolCall>[];
    for (var index = 0; index < rawCalls.length; index++) {
      final rawCall = rawCalls[index];
      if (rawCall is! Map) {
        continue;
      }
      final call = Map<String, Object?>.from(rawCall);
      final function = call['function'];
      if (function is! Map) {
        continue;
      }

      final functionMap = Map<String, Object?>.from(function);
      final name = functionMap['name'];
      if (name is! String || name.isEmpty) {
        continue;
      }

      final id = switch (call['id']) {
        final String value when value.isNotEmpty => value,
        _ => 'ollama-tool-${index + 1}',
      };
      toolCalls.add(
        ToolCall(
          id: id,
          name: name,
          input: _normalizeArguments(functionMap['arguments']),
        ),
      );
    }

    return List<ToolCall>.unmodifiable(toolCalls);
  }

  Map<String, Object?> _normalizeArguments(Object? arguments) {
    if (arguments is Map<String, Object?>) {
      return arguments;
    }
    if (arguments is Map) {
      return arguments.map((key, value) => MapEntry(key.toString(), value));
    }
    if (arguments is String && arguments.isNotEmpty) {
      final decoded = jsonDecode(arguments);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return const <String, Object?>{};
  }

  String _errorMessage(Map<String, Object?> payload, int statusCode) {
    final error = payload['error'];
    if (error is String && error.isNotEmpty) {
      return 'Ollama request failed ($statusCode): $error';
    }
    return 'Ollama request failed with status $statusCode.';
  }

  AgentProviderException _providerError(String message) =>
      AgentProviderException(
        provider: 'OllamaProvider',
        cause: StateError(message),
        stackTrace: StackTrace.current,
        kind: AgentProviderFailureKind.protocol,
      );

  AgentProviderException _httpError(String message, int statusCode) {
    final isRetryable =
        statusCode == 408 || statusCode == 429 || statusCode >= 500;
    final kind = switch (statusCode) {
      408 => AgentProviderFailureKind.timeout,
      429 => AgentProviderFailureKind.rateLimited,
      final code when code >= 500 => AgentProviderFailureKind.unavailable,
      400 || 404 => AgentProviderFailureKind.invalidRequest,
      _ => AgentProviderFailureKind.protocol,
    };

    return AgentProviderException(
      provider: 'OllamaProvider',
      cause: StateError(message),
      stackTrace: StackTrace.current,
      kind: kind,
      isRetryable: isRetryable,
    );
  }

  Map<String, Object?> _decodeStreamPayload(String line) {
    try {
      return jsonDecode(line) as Map<String, Object?>;
    } on FormatException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: 'OllamaProvider',
        cause: error,
        stackTrace: stackTrace,
        kind: AgentProviderFailureKind.protocol,
      );
    }
  }
}

class OllamaRequestOptions {
  const OllamaRequestOptions({
    this.temperature,
    this.topP,
    this.numPredict,
    this.seed,
  });

  final double? temperature;
  final double? topP;
  final int? numPredict;
  final int? seed;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (numPredict != null) 'num_predict': numPredict,
      if (seed != null) 'seed': seed,
    };
  }
}
