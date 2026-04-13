import 'agent_loop.dart';
import 'agent_run_control.dart';
import 'agent_types.dart';

abstract interface class AgentSessionStore {
  Future<void> save(AgentSession session);

  Future<AgentSession?> load(String id);
}

class InMemoryAgentSessionStore implements AgentSessionStore {
  InMemoryAgentSessionStore();

  final Map<String, AgentSession> _sessions = <String, AgentSession>{};

  @override
  Future<AgentSession?> load(String id) async => _sessions[id];

  @override
  Future<void> save(AgentSession session) async {
    final id = session.id;
    if (id == null || id.isEmpty) {
      throw ArgumentError.value(session.id, 'session.id', 'must not be empty');
    }

    _sessions[id] = session;
  }
}

class AgentSessionManager {
  AgentSessionManager({
    required AgentLoop loop,
    AgentSessionStore? store,
    String Function()? sessionIdGenerator,
    String Function()? runIdGenerator,
  }) : _loop = loop,
       _store = store ?? InMemoryAgentSessionStore(),
       _sessionIdGenerator = sessionIdGenerator ?? _defaultSessionId,
       _runIdGenerator = runIdGenerator ?? _defaultRunId;

  final AgentLoop _loop;
  final AgentSessionStore _store;
  final String Function() _sessionIdGenerator;
  final String Function() _runIdGenerator;

  Future<ManagedAgentSession> createSession() async {
    final session = AgentSession(
      id: _sessionIdGenerator(),
      transcript: const <AgentMessage>[],
    );
    await _store.save(session);
    return ManagedAgentSession._(
      loop: _loop,
      store: _store,
      session: session,
      sessionIdGenerator: _sessionIdGenerator,
      runIdGenerator: _runIdGenerator,
    );
  }

  Future<ManagedAgentSession> loadSession(String id) async {
    final session = await _store.load(id);
    if (session == null) {
      throw StateError('Managed session `$id` was not found.');
    }

    return ManagedAgentSession._(
      loop: _loop,
      store: _store,
      session: session,
      sessionIdGenerator: _sessionIdGenerator,
      runIdGenerator: _runIdGenerator,
    );
  }
}

class ManagedAgentSession {
  ManagedAgentSession._({
    required AgentLoop loop,
    required AgentSessionStore store,
    required AgentSession session,
    required String Function() sessionIdGenerator,
    required String Function() runIdGenerator,
  }) : _loop = loop,
       _store = store,
       _session = session,
       _sessionIdGenerator = sessionIdGenerator,
       _runIdGenerator = runIdGenerator;

  final AgentLoop _loop;
  final AgentSessionStore _store;
  final String Function() _sessionIdGenerator;
  final String Function() _runIdGenerator;
  AgentSession _session;
  _ActiveManagedRun? _activeRun;

  String get id => _session.id ?? (throw StateError('Session id is missing.'));

  String? get parentId => _session.parentId;

  List<AgentMessage> get transcript => _session.transcript;

  Future<ManagedAgentSession> branch() async {
    final branchSession = AgentSession(
      id: _sessionIdGenerator(),
      parentId: id,
      transcript: _session.transcript,
    );
    await _store.save(branchSession);

    return ManagedAgentSession._(
      loop: _loop,
      store: _store,
      session: branchSession,
      sessionIdGenerator: _sessionIdGenerator,
      runIdGenerator: _runIdGenerator,
    );
  }

  Future<AgentRunResult> run(String prompt) async {
    final activeRun = _beginRun();

    try {
      final result = await _loop.run(
        prompt,
        session: _session,
        runController: activeRun.controller,
      );
      final managedSession = _session.copyWith(transcript: result.transcript);
      _session = managedSession;
      await _store.save(_session);

      return AgentRunResult(
        output: result.output,
        transcript: result.transcript,
        session: managedSession,
        steps: result.steps,
      );
    } finally {
      _finishRun(activeRun);
    }
  }

  Stream<AgentRunEvent> stream(String prompt) async* {
    final activeRun = _beginRun();

    AgentRunResult? completedResult;

    try {
      yield AgentRunStartEvent(sessionId: id, runId: activeRun.runId);

      await for (final event in _loop.stream(
        prompt,
        session: _session,
        runController: activeRun.controller,
      )) {
        if (event is AgentRunCompleteEvent) {
          completedResult = event.result;
          final managedSession = _session.copyWith(
            transcript: event.result.transcript,
          );
          _session = managedSession;
          await _store.save(_session);
          yield AgentRunCompleteEvent(
            result: AgentRunResult(
              output: event.result.output,
              transcript: event.result.transcript,
              session: managedSession,
              steps: event.result.steps,
            ),
            sessionId: id,
            runId: activeRun.runId,
          );
          continue;
        }

        yield _annotateEvent(event, sessionId: id, runId: activeRun.runId);
      }

      if (completedResult == null) {
        await _store.save(_session);
      }
    } on AgentRunCancelledException {
      yield AgentRunCancelledEvent(sessionId: id, runId: activeRun.runId);
    } finally {
      _finishRun(activeRun);
    }
  }

  Future<bool> abort() async {
    final activeRun = _activeRun;
    if (activeRun == null) {
      return false;
    }

    return activeRun.controller.cancel();
  }

  _ActiveManagedRun _beginRun() {
    if (_activeRun != null) {
      throw AgentSessionRunActiveException(id);
    }

    final activeRun = _ActiveManagedRun(
      runId: _runIdGenerator(),
      controller: AgentRunController(),
    );
    _activeRun = activeRun;
    return activeRun;
  }

  void _finishRun(_ActiveManagedRun activeRun) {
    if (identical(_activeRun, activeRun)) {
      _activeRun = null;
    }
  }

  AgentRunEvent _annotateEvent(
    AgentRunEvent event, {
    required String sessionId,
    required String runId,
  }) {
    return switch (event) {
      AgentAssistantEvent(message: final message) => AgentAssistantEvent(
        message: message,
        sessionId: sessionId,
        runId: runId,
      ),
      AgentMessagePartEvent(message: final message, part: final part) =>
        AgentMessagePartEvent(
          message: message,
          part: part,
          sessionId: sessionId,
          runId: runId,
        ),
      AgentToolCallEvent(call: final call) => AgentToolCallEvent(
        call: call,
        sessionId: sessionId,
        runId: runId,
      ),
      AgentToolResultEvent(result: final result) => AgentToolResultEvent(
        result: result,
        sessionId: sessionId,
        runId: runId,
      ),
      AgentRunCompleteEvent(result: final result) => AgentRunCompleteEvent(
        result: result,
        sessionId: sessionId,
        runId: runId,
      ),
      AgentRunStartEvent() => AgentRunStartEvent(
        sessionId: sessionId,
        runId: runId,
      ),
      AgentRunCancelledEvent() => AgentRunCancelledEvent(
        sessionId: sessionId,
        runId: runId,
      ),
    };
  }
}

class _ActiveManagedRun {
  const _ActiveManagedRun({required this.runId, required this.controller});

  final String runId;
  final AgentRunController controller;
}

var _defaultSessionCounter = 0;
var _defaultRunCounter = 0;

String _defaultSessionId() => 'session-${++_defaultSessionCounter}';

String _defaultRunId() => 'run-${++_defaultRunCounter}';
