import 'dart:async';

class AgentRunController {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get onCancel => _cancelled.future;

  bool cancel() {
    if (_cancelled.isCompleted) {
      return false;
    }

    _cancelled.complete();
    return true;
  }
}

class AgentRunCancelledException implements Exception {
  const AgentRunCancelledException();

  @override
  String toString() => 'AgentRunCancelledException()';
}

class AgentSessionRunActiveException implements Exception {
  const AgentSessionRunActiveException(this.sessionId);

  final String sessionId;

  @override
  String toString() => 'AgentSessionRunActiveException(sessionId: $sessionId)';
}
