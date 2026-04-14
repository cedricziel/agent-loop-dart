import 'dart:async';

import 'agent_model.dart';
import 'agent_permissions.dart';
import 'agent_run_control.dart';
import 'agent_tool.dart';
import 'agent_types.dart';

typedef ToolPermissionCheck =
    Future<AgentPermissionDecision> Function(ToolCall toolCall);

class AgentLoop {
  AgentLoop({
    AgentProvider? provider,
    AgentModel? model,
    Iterable<AgentTool> tools = const <AgentTool>[],
    this.systemPrompt,
    this.maxSteps = 8,
    this.toolPermissionCheck,
    AgentReliabilityPolicy? reliabilityPolicy,
  }) : assert(
         provider != null || model != null,
         'Provide either an AgentProvider or an AgentModel.',
       ),
       _provider = provider ?? model!,
       _tools = ToolRegistry(tools),
       reliabilityPolicy = reliabilityPolicy ?? AgentReliabilityPolicy.none();

  final AgentProvider _provider;
  final ToolRegistry _tools;
  final String? systemPrompt;
  final int maxSteps;
  final ToolPermissionCheck? toolPermissionCheck;
  final AgentReliabilityPolicy reliabilityPolicy;

  Future<AgentRunResult> run(
    String prompt, {
    AgentSession? session,
    List<AgentMessage> transcript = const <AgentMessage>[],
    AgentRunController? runController,
  }) async {
    AgentRunResult? result;

    await for (final event in stream(
      prompt,
      session: session,
      transcript: transcript,
      runController: runController,
    )) {
      if (event is AgentRunCompleteEvent) {
        result = event.result;
      }
    }

    if (result != null) {
      return result;
    }

    if (runController?.isCancelled ?? false) {
      throw const AgentRunCancelledException();
    }

    throw StateError('Agent loop completed without a final result.');
  }

  Stream<AgentRunEvent> stream(
    String prompt, {
    AgentSession? session,
    List<AgentMessage> transcript = const <AgentMessage>[],
    AgentRunController? runController,
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

    yield* _executeLoop(
      workingTranscript,
      startStep: 1,
      runController: runController,
    );
  }

  Stream<AgentRunEvent> resumeToolApproval(
    AgentToolApprovalRequest request, {
    AgentRunController? runController,
  }) async* {
    final workingTranscript = <AgentMessage>[...request.transcript];
    yield* _executeToolCall(
      workingTranscript,
      request.toolCall,
      runController: runController,
    );
    yield* _executeLoop(
      workingTranscript,
      startStep: request.step + 1,
      runController: runController,
    );
  }

  Stream<AgentRunEvent> _executeLoop(
    List<AgentMessage> workingTranscript, {
    required int startStep,
    required AgentRunController? runController,
  }) async* {
    for (var step = startStep; step <= maxSteps; step++) {
      _throwIfCancelled(runController);
      final streamedParts = <MessagePart>[];
      AgentResponse? response;

      await for (final providerEvent in _respondEvents(
        workingTranscript,
        runController: runController,
      )) {
        switch (providerEvent) {
          case _ProviderPartialResponseEvent(part: final part):
            streamedParts.add(part);
            yield AgentMessagePartEvent(
              message: AgentMessage(
                role: AgentRole.assistant,
                parts: List<MessagePart>.unmodifiable(streamedParts),
              ),
              part: part,
            );
          case _ProviderFinalResponseEvent(response: final finalResponse):
            response = finalResponse;
          case _ProviderRetryLoopEvent(
            attempt: final attempt,
            maxAttempts: final maxAttempts,
            delay: final delay,
            failure: final failure,
          ):
            yield AgentProviderRetryEvent(
              attempt: attempt,
              maxAttempts: maxAttempts,
              delay: delay,
              failure: failure,
            );
          case _ProviderRetryExhaustedLoopEvent(
            attempt: final attempt,
            maxAttempts: final maxAttempts,
            failure: final failure,
          ):
            yield AgentProviderRetryExhaustedEvent(
              attempt: attempt,
              maxAttempts: maxAttempts,
              failure: failure,
            );
        }
      }

      final completedResponse = response;
      if (completedResponse == null) {
        throw StateError('Provider completed without a final response.');
      }

      final responseParts = _resolveResponseParts(
        completedResponse,
        streamedParts,
      );

      if (completedResponse.toolCalls.isEmpty) {
        final message = AgentMessage(
          role: AgentRole.assistant,
          content: responseParts.isEmpty ? (completedResponse.text ?? '') : '',
          parts: responseParts,
        );
        workingTranscript.add(message);
        yield AgentAssistantEvent(message: message);
        if (streamedParts.isEmpty) {
          for (final part in message.parts) {
            yield AgentMessagePartEvent(message: message, part: part);
          }
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

      if (responseParts.isNotEmpty) {
        final assistantMessage = AgentMessage(
          role: AgentRole.assistant,
          parts: responseParts,
        );
        workingTranscript.add(assistantMessage);
        yield AgentAssistantEvent(message: assistantMessage);
        if (streamedParts.isEmpty) {
          for (final part in assistantMessage.parts) {
            yield AgentMessagePartEvent(message: assistantMessage, part: part);
          }
        }
      }

      for (final toolCall in completedResponse.toolCalls) {
        _throwIfCancelled(runController);

        final decision = await toolPermissionCheck?.call(toolCall);
        if (decision != null) {
          yield AgentPermissionEvent(decision: decision);
          switch (decision.outcome) {
            case AgentPermissionOutcome.allow:
              break;
            case AgentPermissionOutcome.ask:
              throw AgentApprovalRequiredException(
                decision,
                request: AgentToolApprovalRequest(
                  runId: '',
                  decision: decision,
                  toolCall: toolCall,
                  transcript: List<AgentMessage>.unmodifiable(
                    workingTranscript,
                  ),
                  step: step,
                ),
              );
            case AgentPermissionOutcome.deny:
              throw AgentPermissionDeniedException(decision);
          }
        }

        yield* _executeToolCall(
          workingTranscript,
          toolCall,
          runController: runController,
        );
      }
    }

    throw StateError(
      'Agent loop exceeded maxSteps=$maxSteps without a final response.',
    );
  }

  Stream<AgentRunEvent> _executeToolCall(
    List<AgentMessage> workingTranscript,
    ToolCall toolCall, {
    required AgentRunController? runController,
  }) async* {
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
        : await _withCancellation(tool.execute(toolCall.input), runController);

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

  Stream<_ProviderLoopEvent> _respondEvents(
    List<AgentMessage> transcript, {
    required AgentRunController? runController,
  }) async* {
    final turn = AgentTurn(
      messages: List.unmodifiable(transcript),
      tools: _tools.definitions,
    );

    for (var attempt = 1; attempt <= reliabilityPolicy.maxAttempts; attempt++) {
      _throwIfCancelled(runController);

      try {
        final attemptResult = await _executeProviderAttempt(
          turn,
          runController: runController,
        );
        for (final part in attemptResult.streamedParts) {
          yield _ProviderPartialResponseEvent(part);
        }
        yield _ProviderFinalResponseEvent(attemptResult.response);
        return;
      } on AgentProviderException catch (error) {
        final canRetry = _canRetry(error, attempt);
        if (!canRetry) {
          if (error.isRetryable && reliabilityPolicy.retriesEnabled) {
            yield _ProviderRetryExhaustedLoopEvent(
              attempt: attempt,
              maxAttempts: reliabilityPolicy.maxAttempts,
              failure: error,
            );
          }
          rethrow;
        }

        final delay =
            error.retryAfter ?? reliabilityPolicy.delayForRetry(attempt);
        yield _ProviderRetryLoopEvent(
          attempt: attempt,
          maxAttempts: reliabilityPolicy.maxAttempts,
          delay: delay,
          failure: error,
        );
        await _delayWithCancellation(delay, runController);
      } on AgentRunCancelledException {
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

  bool _canRetry(AgentProviderException error, int attempt) {
    return error.isRetryable && attempt < reliabilityPolicy.maxAttempts;
  }

  Future<_ProviderAttemptResult> _executeProviderAttempt(
    AgentTurn turn, {
    required AgentRunController? runController,
  }) async {
    final provider = _provider;
    final providerName = provider.runtimeType.toString();

    if (provider is AgentStreamingProvider) {
      final streamedParts = <MessagePart>[];
      AgentResponse? response;
      final deadline = _attemptDeadline();
      final iterator = StreamIterator<AgentProviderEvent>(
        provider.streamRespond(turn),
      );
      try {
        while (await _withAttemptDeadline(
          iterator.moveNext(),
          runController,
          deadline,
          providerName: providerName,
        )) {
          final event = iterator.current;
          switch (event) {
            case AgentProviderPartialOutputEvent(part: final part):
              streamedParts.add(part);
            case AgentProviderResponseEvent(response: final finalResponse):
              response = finalResponse;
          }
        }
      } finally {
        await iterator.cancel();
      }

      final finalResponse = response;
      if (finalResponse == null) {
        throw AgentProviderException(
          provider: providerName,
          cause: StateError('Provider completed without a final response.'),
          stackTrace: StackTrace.current,
          kind: AgentProviderFailureKind.protocol,
        );
      }

      return _ProviderAttemptResult(
        streamedParts: List<MessagePart>.unmodifiable(streamedParts),
        response: finalResponse,
      );
    }

    final response = await _withAttemptDeadline(
      provider.respond(turn),
      runController,
      _attemptDeadline(),
      providerName: providerName,
    );
    return _ProviderAttemptResult(
      streamedParts: const <MessagePart>[],
      response: response,
    );
  }

  DateTime? _attemptDeadline() {
    final timeout = reliabilityPolicy.attemptTimeout;
    if (timeout == null) {
      return null;
    }
    return DateTime.now().add(timeout);
  }

  Future<T> _withAttemptDeadline<T>(
    Future<T> future,
    AgentRunController? runController,
    DateTime? deadline, {
    required String providerName,
  }) async {
    final controlled = _withCancellation(future, runController);
    if (deadline == null) {
      return controlled;
    }

    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw AgentProviderException(
        provider: providerName,
        cause: TimeoutException('Provider attempt timed out.'),
        stackTrace: StackTrace.current,
        kind: AgentProviderFailureKind.timeout,
        isRetryable: true,
      );
    }

    try {
      return await controlled.timeout(remaining);
    } on TimeoutException catch (error, stackTrace) {
      throw AgentProviderException(
        provider: providerName,
        cause: error,
        stackTrace: stackTrace,
        kind: AgentProviderFailureKind.timeout,
        isRetryable: true,
      );
    }
  }

  List<MessagePart> _resolveResponseParts(
    AgentResponse response,
    List<MessagePart> streamedParts,
  ) {
    if (streamedParts.isEmpty) {
      return response.parts;
    }

    final responseParts = response.parts;
    if (responseParts.isEmpty) {
      return List<MessagePart>.unmodifiable(streamedParts);
    }

    final streamedText = streamedParts
        .whereType<TextPart>()
        .map((part) => part.text)
        .join();
    final responseText = responseParts
        .whereType<TextPart>()
        .map((part) => part.text)
        .join();
    final hasOnlyTextParts =
        streamedParts.every((part) => part is TextPart) &&
        responseParts.every((part) => part is TextPart);
    if (hasOnlyTextParts && streamedText == responseText) {
      return List<MessagePart>.unmodifiable(streamedParts);
    }

    return responseParts;
  }

  Future<T> _withCancellation<T>(
    Future<T> future,
    AgentRunController? runController,
  ) async {
    if (runController == null) {
      return future;
    }

    return Future.any(<Future<T>>[
      future,
      runController.onCancel.then<T>(
        (_) => throw const AgentRunCancelledException(),
      ),
    ]);
  }

  void _throwIfCancelled(AgentRunController? runController) {
    if (runController?.isCancelled ?? false) {
      throw const AgentRunCancelledException();
    }
  }

  Future<void> _delayWithCancellation(
    Duration delay,
    AgentRunController? runController,
  ) async {
    if (delay <= Duration.zero) {
      return;
    }
    await _withCancellation(Future<void>.delayed(delay), runController);
  }
}

sealed class _ProviderLoopEvent {
  const _ProviderLoopEvent();
}

class _ProviderPartialResponseEvent extends _ProviderLoopEvent {
  const _ProviderPartialResponseEvent(this.part);

  final MessagePart part;
}

class _ProviderFinalResponseEvent extends _ProviderLoopEvent {
  const _ProviderFinalResponseEvent(this.response);

  final AgentResponse response;
}

class _ProviderRetryLoopEvent extends _ProviderLoopEvent {
  const _ProviderRetryLoopEvent({
    required this.attempt,
    required this.maxAttempts,
    required this.delay,
    required this.failure,
  });

  final int attempt;
  final int maxAttempts;
  final Duration delay;
  final AgentProviderException failure;
}

class _ProviderRetryExhaustedLoopEvent extends _ProviderLoopEvent {
  const _ProviderRetryExhaustedLoopEvent({
    required this.attempt,
    required this.maxAttempts,
    required this.failure,
  });

  final int attempt;
  final int maxAttempts;
  final AgentProviderException failure;
}

class _ProviderAttemptResult {
  const _ProviderAttemptResult({
    required this.streamedParts,
    required this.response,
  });

  final List<MessagePart> streamedParts;
  final AgentResponse response;
}
