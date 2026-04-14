import 'agent_permissions.dart';
import 'agent_tool.dart';

enum AgentRole { system, user, assistant, tool }

sealed class MessagePart {
  const MessagePart();
}

class TextPart extends MessagePart {
  const TextPart({required this.text});

  final String text;
}

class ReasoningPart extends MessagePart {
  const ReasoningPart({required this.text});

  final String text;
}

class FilePart extends MessagePart {
  const FilePart({required this.path, required this.mimeType, this.label});

  final String path;
  final String mimeType;
  final String? label;
}

enum ToolPartState { pending, completed }

class ToolPart extends MessagePart {
  const ToolPart({
    required this.callId,
    required this.name,
    required this.state,
    this.input = const <String, Object?>{},
    this.output,
  });

  final String callId;
  final String name;
  final ToolPartState state;
  final Map<String, Object?> input;
  final String? output;
}

class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    this.input = const <String, Object?>{},
  });

  final String id;
  final String name;
  final Map<String, Object?> input;
}

class ToolResult {
  const ToolResult({
    required this.callId,
    required this.name,
    required this.output,
  });

  final String callId;
  final String name;
  final String output;
}

class AgentMessage {
  const AgentMessage({
    required this.role,
    String content = '',
    List<MessagePart> parts = const <MessagePart>[],
    this.toolCall,
    this.toolResult,
  }) : _content = content,
       _parts = parts;

  final AgentRole role;
  final String _content;
  final List<MessagePart> _parts;
  final ToolCall? toolCall;
  final ToolResult? toolResult;

  String get content => _content.isNotEmpty ? _content : _derivedTextContent;

  List<MessagePart> get parts => _parts.isNotEmpty
      ? _parts
      : (_content.isEmpty
            ? const <MessagePart>[]
            : <MessagePart>[TextPart(text: _content)]);

  String get textContent => _derivedTextContent;

  String get _derivedTextContent =>
      _parts.whereType<TextPart>().map((part) => part.text).join();
}

class AgentResponse {
  AgentResponse({
    String? text,
    List<MessagePart> parts = const <MessagePart>[],
    this.toolCalls = const <ToolCall>[],
  }) : _text = text,
       _parts = parts,
       assert(
         text != null || parts.isNotEmpty || toolCalls.isNotEmpty,
         'A response must include text, parts, or at least one tool call.',
       );

  final String? _text;
  final List<MessagePart> _parts;
  final List<ToolCall> toolCalls;

  List<MessagePart> get parts => _parts.isNotEmpty
      ? _parts
      : (_text == null || _text.isEmpty
            ? const <MessagePart>[]
            : <MessagePart>[TextPart(text: _text)]);

  String? get text {
    if (_text != null) {
      return _text;
    }

    final combined = parts
        .whereType<TextPart>()
        .map((part) => part.text)
        .join();
    return combined.isEmpty ? null : combined;
  }
}

class AgentRunResult {
  const AgentRunResult({
    required this.output,
    required this.transcript,
    required this.session,
    required this.steps,
  });

  final String output;
  final List<AgentMessage> transcript;
  final AgentSession session;
  final int steps;
}

class AgentTurn {
  const AgentTurn({required this.messages, required this.tools});

  final List<AgentMessage> messages;
  final List<ToolDefinition> tools;
}

class AgentSession {
  AgentSession({
    this.id,
    this.parentId,
    this.profileId,
    this.delegatingAgentId,
    this.pendingApproval,
    required List<AgentMessage> transcript,
  }) : transcript = List.unmodifiable(transcript);

  final String? id;
  final String? parentId;
  final String? profileId;
  final String? delegatingAgentId;
  final AgentPendingApprovalRequest? pendingApproval;
  final List<AgentMessage> transcript;

  AgentSession copyWith({
    String? id,
    Object? parentId = _agentSessionNoValue,
    Object? profileId = _agentSessionNoValue,
    Object? delegatingAgentId = _agentSessionNoValue,
    Object? pendingApproval = _agentSessionNoValue,
    List<AgentMessage>? transcript,
  }) {
    return AgentSession(
      id: id ?? this.id,
      parentId: identical(parentId, _agentSessionNoValue)
          ? this.parentId
          : parentId as String?,
      profileId: identical(profileId, _agentSessionNoValue)
          ? this.profileId
          : profileId as String?,
      delegatingAgentId: identical(delegatingAgentId, _agentSessionNoValue)
          ? this.delegatingAgentId
          : delegatingAgentId as String?,
      pendingApproval: identical(pendingApproval, _agentSessionNoValue)
          ? this.pendingApproval
          : pendingApproval as AgentPendingApprovalRequest?,
      transcript: transcript ?? this.transcript,
    );
  }
}

const Object _agentSessionNoValue = Object();

enum AgentProviderFailureKind {
  unknown,
  network,
  timeout,
  rateLimited,
  unavailable,
  invalidRequest,
  protocol,
}

class AgentReliabilityPolicy {
  const AgentReliabilityPolicy({
    required this.maxAttempts,
    this.attemptTimeout,
    this.initialRetryDelay = Duration.zero,
    this.backoffMultiplier = 1,
    Duration? maxRetryDelay,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1.'),
       assert(backoffMultiplier >= 1, 'backoffMultiplier must be at least 1.'),
       maxRetryDelay = maxRetryDelay ?? initialRetryDelay;

  factory AgentReliabilityPolicy.none() =>
      const AgentReliabilityPolicy(maxAttempts: 1);

  factory AgentReliabilityPolicy.standard() => const AgentReliabilityPolicy(
    maxAttempts: 3,
    attemptTimeout: Duration(seconds: 30),
    initialRetryDelay: Duration(milliseconds: 200),
    backoffMultiplier: 2,
    maxRetryDelay: Duration(seconds: 2),
  );

  final int maxAttempts;
  final Duration? attemptTimeout;
  final Duration initialRetryDelay;
  final double backoffMultiplier;
  final Duration maxRetryDelay;

  bool get retriesEnabled => maxAttempts > 1;

  Duration delayForRetry(int failedAttempt) {
    if (!retriesEnabled || initialRetryDelay == Duration.zero) {
      return Duration.zero;
    }

    var delayMicros = initialRetryDelay.inMicroseconds.toDouble();
    for (var attempt = 1; attempt < failedAttempt; attempt++) {
      delayMicros *= backoffMultiplier;
    }

    final boundedMicros = delayMicros.clamp(
      0,
      maxRetryDelay.inMicroseconds.toDouble(),
    );
    return Duration(microseconds: boundedMicros.round());
  }
}

class AgentProviderException implements Exception {
  const AgentProviderException({
    required this.provider,
    required this.cause,
    required this.stackTrace,
    this.kind = AgentProviderFailureKind.unknown,
    this.isRetryable = false,
    this.retryAfter,
  });

  final String provider;
  final Object cause;
  final StackTrace stackTrace;
  final AgentProviderFailureKind kind;
  final bool isRetryable;
  final Duration? retryAfter;

  @override
  String toString() =>
      'AgentProviderException(provider: $provider, cause: $cause, '
      'kind: $kind, retryable: $isRetryable)';
}

sealed class AgentRunEvent {
  const AgentRunEvent({this.sessionId, this.runId, this.agentId});

  final String? sessionId;
  final String? runId;
  final String? agentId;
}

class AgentAssistantEvent extends AgentRunEvent {
  const AgentAssistantEvent({
    required this.message,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final AgentMessage message;
}

class AgentMessagePartEvent extends AgentRunEvent {
  const AgentMessagePartEvent({
    required this.message,
    required this.part,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final AgentMessage message;
  final MessagePart part;
}

class AgentToolCallEvent extends AgentRunEvent {
  const AgentToolCallEvent({
    required this.call,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final ToolCall call;
}

class AgentToolResultEvent extends AgentRunEvent {
  const AgentToolResultEvent({
    required this.result,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final ToolResult result;
}

class AgentRunCompleteEvent extends AgentRunEvent {
  const AgentRunCompleteEvent({
    required this.result,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final AgentRunResult result;
}

class AgentRunStartEvent extends AgentRunEvent {
  const AgentRunStartEvent({
    required super.sessionId,
    required super.runId,
    super.agentId,
  });
}

class AgentRunCancelledEvent extends AgentRunEvent {
  const AgentRunCancelledEvent({
    required super.sessionId,
    required super.runId,
    super.agentId,
  });
}

class AgentProviderRetryEvent extends AgentRunEvent {
  const AgentProviderRetryEvent({
    required this.attempt,
    required this.maxAttempts,
    required this.delay,
    required this.failure,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final int attempt;
  final int maxAttempts;
  final Duration delay;
  final AgentProviderException failure;
}

class AgentProviderRetryExhaustedEvent extends AgentRunEvent {
  const AgentProviderRetryExhaustedEvent({
    required this.attempt,
    required this.maxAttempts,
    required this.failure,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final int attempt;
  final int maxAttempts;
  final AgentProviderException failure;
}

class AgentPermissionEvent extends AgentRunEvent {
  const AgentPermissionEvent({
    required this.decision,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final AgentPermissionDecision decision;
}

class AgentApprovalRequiredEvent extends AgentRunEvent {
  const AgentApprovalRequiredEvent({
    required this.request,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final AgentPendingApprovalRequest request;
}

enum AgentApprovalResolution { approved, denied }

class AgentApprovalResolvedEvent extends AgentRunEvent {
  const AgentApprovalResolvedEvent({
    required this.request,
    required this.resolution,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final AgentPendingApprovalRequest request;
  final AgentApprovalResolution resolution;
}

enum AgentDelegationPhase { start, complete }

class AgentDelegationEvent extends AgentRunEvent {
  const AgentDelegationEvent({
    required this.phase,
    required this.parentSessionId,
    required this.childSessionId,
    required this.delegatedAgentId,
    super.sessionId,
    super.runId,
    super.agentId,
  });

  final AgentDelegationPhase phase;
  final String parentSessionId;
  final String childSessionId;
  final String delegatedAgentId;
}
