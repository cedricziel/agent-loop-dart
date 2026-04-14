import 'agent_loop.dart';
import 'agent_permissions.dart';
import 'agent_run_control.dart';
import 'agent_types.dart';

abstract interface class AgentSessionStore {
  Future<void> save(AgentSession session);

  Future<AgentSession?> load(String id);

  Future<List<AgentSession>> listByParent(String parentId);
}

class InMemoryAgentSessionStore implements AgentSessionStore {
  InMemoryAgentSessionStore();

  final Map<String, AgentSession> _sessions = <String, AgentSession>{};

  @override
  Future<AgentSession?> load(String id) async => _sessions[id];

  @override
  Future<List<AgentSession>> listByParent(String parentId) async {
    return _sessions.values
        .where((session) => session.parentId == parentId)
        .toList(growable: false);
  }

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
    AgentLoop? loop,
    AgentLoop Function(AgentSession session)? loopFactory,
    Future<ManagedAgentSession> Function(
      ManagedAgentSession session,
      String profileId,
      String prompt,
      bool skipPermissionCheck,
    )?
    delegateHandler,
    Stream<AgentRunEvent> Function(
      ManagedAgentSession session,
      String profileId,
      String prompt,
      bool skipPermissionCheck,
    )?
    delegateStreamHandler,
    AgentSessionStore? store,
    String Function()? sessionIdGenerator,
    String Function()? runIdGenerator,
  }) : assert(loop != null || loopFactory != null),
       _loop = loop,
       _loopFactory =
           loopFactory ??
           ((AgentSession session) =>
               loop ?? (throw StateError('Missing loop instance.'))),
       _delegateHandler = delegateHandler,
       _delegateStreamHandler = delegateStreamHandler,
       _store = store ?? InMemoryAgentSessionStore(),
       _sessionIdGenerator = sessionIdGenerator ?? _defaultSessionId,
       _runIdGenerator = runIdGenerator ?? _defaultRunId;

  final AgentLoop? _loop;
  final AgentLoop Function(AgentSession session) _loopFactory;
  final Future<ManagedAgentSession> Function(
    ManagedAgentSession session,
    String profileId,
    String prompt,
    bool skipPermissionCheck,
  )?
  _delegateHandler;
  final Stream<AgentRunEvent> Function(
    ManagedAgentSession session,
    String profileId,
    String prompt,
    bool skipPermissionCheck,
  )?
  _delegateStreamHandler;
  final AgentSessionStore _store;
  final String Function() _sessionIdGenerator;
  final String Function() _runIdGenerator;

  Future<ManagedAgentSession> createSession({
    String? profileId,
    String? parentId,
    String? delegatingAgentId,
  }) async {
    final session = AgentSession(
      id: _sessionIdGenerator(),
      parentId: parentId,
      profileId: profileId,
      delegatingAgentId: delegatingAgentId,
      transcript: const <AgentMessage>[],
    );
    await _store.save(session);
    return ManagedAgentSession._(
      loop: _loop,
      loopFactory: _loopFactory,
      delegateHandler: _delegateHandler,
      delegateStreamHandler: _delegateStreamHandler,
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
      loopFactory: _loopFactory,
      delegateHandler: _delegateHandler,
      delegateStreamHandler: _delegateStreamHandler,
      store: _store,
      session: session,
      sessionIdGenerator: _sessionIdGenerator,
      runIdGenerator: _runIdGenerator,
    );
  }
}

class ManagedAgentSession {
  ManagedAgentSession._({
    required AgentLoop? loop,
    required AgentLoop Function(AgentSession session) loopFactory,
    required Future<ManagedAgentSession> Function(
      ManagedAgentSession session,
      String profileId,
      String prompt,
      bool skipPermissionCheck,
    )?
    delegateHandler,
    required Stream<AgentRunEvent> Function(
      ManagedAgentSession session,
      String profileId,
      String prompt,
      bool skipPermissionCheck,
    )?
    delegateStreamHandler,
    required AgentSessionStore store,
    required AgentSession session,
    required String Function() sessionIdGenerator,
    required String Function() runIdGenerator,
  }) : _loop = loop,
       _loopFactory = loopFactory,
       _delegateHandler = delegateHandler,
       _delegateStreamHandler = delegateStreamHandler,
       _store = store,
       _session = session,
       _sessionIdGenerator = sessionIdGenerator,
       _runIdGenerator = runIdGenerator;

  final AgentLoop? _loop;
  final AgentLoop Function(AgentSession session) _loopFactory;
  final Future<ManagedAgentSession> Function(
    ManagedAgentSession session,
    String profileId,
    String prompt,
    bool skipPermissionCheck,
  )?
  _delegateHandler;
  final Stream<AgentRunEvent> Function(
    ManagedAgentSession session,
    String profileId,
    String prompt,
    bool skipPermissionCheck,
  )?
  _delegateStreamHandler;
  final AgentSessionStore _store;
  final String Function() _sessionIdGenerator;
  final String Function() _runIdGenerator;
  AgentSession _session;
  _ActiveManagedRun? _activeRun;

  String get id => _session.id ?? (throw StateError('Session id is missing.'));

  String? get parentId => _session.parentId;

  String? get profileId => _session.profileId;

  String? get delegatingAgentId => _session.delegatingAgentId;

  AgentPendingApprovalRequest? get pendingApproval => _session.pendingApproval;

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
      loopFactory: _loopFactory,
      delegateHandler: _delegateHandler,
      delegateStreamHandler: _delegateStreamHandler,
      store: _store,
      session: branchSession,
      sessionIdGenerator: _sessionIdGenerator,
      runIdGenerator: _runIdGenerator,
    );
  }

  Future<AgentRunResult> run(String prompt) async {
    final activeRun = _beginRun();
    final loop = _loopFactory(_session);

    try {
      final result = await loop.run(
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
    } on AgentApprovalRequiredException catch (error) {
      await _pauseForApproval(activeRun, error);
      rethrow;
    } finally {
      _finishRun(activeRun);
    }
  }

  Stream<AgentRunEvent> stream(String prompt) async* {
    final activeRun = _beginRun();
    final loop = _loopFactory(_session);

    AgentRunResult? completedResult;

    try {
      yield AgentRunStartEvent(
        sessionId: id,
        runId: activeRun.runId,
        agentId: profileId,
      );

      await for (final event in loop.stream(
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
            agentId: profileId,
          );
          continue;
        }

        yield _annotateEvent(
          event,
          sessionId: id,
          runId: activeRun.runId,
          agentId: profileId,
        );
      }

      if (completedResult == null) {
        await _store.save(_session);
      }
    } on AgentRunCancelledException {
      yield AgentRunCancelledEvent(
        sessionId: id,
        runId: activeRun.runId,
        agentId: profileId,
      );
    } on AgentPermissionDeniedException {
      return;
    } on AgentApprovalRequiredException catch (error) {
      final request = await _pauseForApproval(activeRun, error);
      yield AgentApprovalRequiredEvent(
        request: request,
        sessionId: id,
        runId: activeRun.runId,
        agentId: profileId,
      );
      return;
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

  Future<ManagedAgentSession> delegate(String profileId, String prompt) async {
    final delegateHandler = _delegateHandler;
    if (delegateHandler == null) {
      throw UnsupportedError('Delegation is not configured for this session.');
    }

    final activeRun = _beginRun();

    try {
      return await delegateHandler(this, profileId, prompt, false);
    } on AgentApprovalRequiredException catch (error) {
      await _pauseForApproval(activeRun, error);
      rethrow;
    } finally {
      _finishRun(activeRun);
    }
  }

  Stream<AgentRunEvent> delegateStream(String profileId, String prompt) {
    final delegateStreamHandler = _delegateStreamHandler;
    if (delegateStreamHandler == null) {
      throw UnsupportedError('Delegation streaming is not configured.');
    }

    final activeRun = _beginRun();

    return (() async* {
      try {
        await for (final event in delegateStreamHandler(
          this,
          profileId,
          prompt,
          false,
        )) {
          yield _annotateDelegationRunEvent(event, runId: activeRun.runId);
        }
      } on AgentPermissionDeniedException catch (error) {
        yield AgentPermissionEvent(
          decision: error.decision,
          sessionId: id,
          runId: activeRun.runId,
          agentId: this.profileId,
        );
      } on AgentApprovalRequiredException catch (error) {
        yield AgentPermissionEvent(
          decision: error.decision,
          sessionId: id,
          runId: activeRun.runId,
          agentId: this.profileId,
        );
        final request = await _pauseForApproval(activeRun, error);
        yield AgentApprovalRequiredEvent(
          request: request,
          sessionId: id,
          runId: activeRun.runId,
          agentId: this.profileId,
        );
      } finally {
        _finishRun(activeRun);
      }
    })();
  }

  Future<AgentRunResult> approvePending() async {
    AgentRunResult? result;
    await for (final event in approvePendingStream()) {
      if (event is AgentRunCompleteEvent) {
        result = event.result;
      }
    }

    if (result == null) {
      throw StateError('Approved pending request did not complete the run.');
    }

    return result;
  }

  Stream<AgentRunEvent> approvePendingStream() async* {
    final request = pendingApproval;
    if (request == null) {
      throw StateError('No pending approval request is available.');
    }

    final activeRun = _resumePendingRun(request.runId);
    await _clearPendingApproval();

    try {
      yield AgentApprovalResolvedEvent(
        request: request,
        resolution: AgentApprovalResolution.approved,
        sessionId: id,
        runId: activeRun.runId,
        agentId: profileId,
      );

      switch (request) {
        case AgentToolApprovalRequest():
          final loop = _loopFactory(_session);
          await for (final event in loop.resumeToolApproval(
            request,
            runController: activeRun.controller,
          )) {
            if (event is AgentRunCompleteEvent) {
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
                agentId: profileId,
              );
              continue;
            }

            yield _annotateEvent(
              event,
              sessionId: id,
              runId: activeRun.runId,
              agentId: profileId,
            );
          }
        case AgentSubagentApprovalRequest():
          final delegateStreamHandler = _delegateStreamHandler;
          if (delegateStreamHandler == null) {
            throw UnsupportedError('Delegation streaming is not configured.');
          }

          await for (final event in delegateStreamHandler(
            this,
            request.delegatedAgentId,
            request.prompt,
            true,
          )) {
            yield _annotateDelegationRunEvent(event, runId: activeRun.runId);
          }
      }
    } finally {
      _finishRun(activeRun);
    }
  }

  Future<void> denyPending() async {
    await denyPendingStream().drain<void>();
  }

  Stream<AgentRunEvent> denyPendingStream() async* {
    final request = pendingApproval;
    if (request == null) {
      throw StateError('No pending approval request is available.');
    }

    final activeRun = _resumePendingRun(request.runId);
    await _clearPendingApproval();

    try {
      yield AgentApprovalResolvedEvent(
        request: request,
        resolution: AgentApprovalResolution.denied,
        sessionId: id,
        runId: activeRun.runId,
        agentId: profileId,
      );
    } finally {
      _finishRun(activeRun);
    }
  }

  Future<List<ManagedAgentSession>> children() async {
    final sessions = await _store.listByParent(id);
    return sessions
        .map(
          (session) => ManagedAgentSession._(
            loop: _loop,
            loopFactory: _loopFactory,
            delegateHandler: _delegateHandler,
            delegateStreamHandler: _delegateStreamHandler,
            store: _store,
            session: session,
            sessionIdGenerator: _sessionIdGenerator,
            runIdGenerator: _runIdGenerator,
          ),
        )
        .toList(growable: false);
  }

  _ActiveManagedRun _beginRun() {
    if (_activeRun != null || _session.pendingApproval != null) {
      throw AgentSessionRunActiveException(id);
    }

    final activeRun = _ActiveManagedRun(
      runId: _runIdGenerator(),
      controller: AgentRunController(),
    );
    _activeRun = activeRun;
    return activeRun;
  }

  _ActiveManagedRun _resumePendingRun(String runId) {
    if (_activeRun != null) {
      throw AgentSessionRunActiveException(id);
    }

    final activeRun = _ActiveManagedRun(
      runId: runId,
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
    String? agentId,
  }) {
    return switch (event) {
      AgentAssistantEvent(message: final message) => AgentAssistantEvent(
        message: message,
        sessionId: sessionId,
        runId: runId,
        agentId: agentId,
      ),
      AgentMessagePartEvent(message: final message, part: final part) =>
        AgentMessagePartEvent(
          message: message,
          part: part,
          sessionId: sessionId,
          runId: runId,
          agentId: agentId,
        ),
      AgentToolCallEvent(call: final call) => AgentToolCallEvent(
        call: call,
        sessionId: sessionId,
        runId: runId,
        agentId: agentId,
      ),
      AgentToolResultEvent(result: final result) => AgentToolResultEvent(
        result: result,
        sessionId: sessionId,
        runId: runId,
        agentId: agentId,
      ),
      AgentRunCompleteEvent(result: final result) => AgentRunCompleteEvent(
        result: result,
        sessionId: sessionId,
        runId: runId,
        agentId: agentId,
      ),
      AgentRunStartEvent() => AgentRunStartEvent(
        sessionId: sessionId,
        runId: runId,
        agentId: agentId,
      ),
      AgentRunCancelledEvent() => AgentRunCancelledEvent(
        sessionId: sessionId,
        runId: runId,
        agentId: agentId,
      ),
      AgentProviderRetryEvent(
        attempt: final attempt,
        maxAttempts: final maxAttempts,
        delay: final delay,
        failure: final failure,
      ) =>
        AgentProviderRetryEvent(
          attempt: attempt,
          maxAttempts: maxAttempts,
          delay: delay,
          failure: failure,
          sessionId: sessionId,
          runId: runId,
          agentId: agentId,
        ),
      AgentProviderRetryExhaustedEvent(
        attempt: final attempt,
        maxAttempts: final maxAttempts,
        failure: final failure,
      ) =>
        AgentProviderRetryExhaustedEvent(
          attempt: attempt,
          maxAttempts: maxAttempts,
          failure: failure,
          sessionId: sessionId,
          runId: runId,
          agentId: agentId,
        ),
      AgentPermissionEvent(decision: final decision) => AgentPermissionEvent(
        decision: decision,
        sessionId: sessionId,
        runId: runId,
        agentId: agentId,
      ),
      AgentApprovalRequiredEvent(request: final request) =>
        AgentApprovalRequiredEvent(
          request: request,
          sessionId: sessionId,
          runId: runId,
          agentId: agentId,
        ),
      AgentApprovalResolvedEvent(
        request: final request,
        resolution: final resolution,
      ) =>
        AgentApprovalResolvedEvent(
          request: request,
          resolution: resolution,
          sessionId: sessionId,
          runId: runId,
          agentId: agentId,
        ),
      AgentDelegationEvent(
        phase: final phase,
        parentSessionId: final parentSessionId,
        childSessionId: final childSessionId,
        delegatedAgentId: final delegatedAgentId,
      ) =>
        AgentDelegationEvent(
          phase: phase,
          parentSessionId: parentSessionId,
          childSessionId: childSessionId,
          delegatedAgentId: delegatedAgentId,
          sessionId: sessionId,
          runId: runId,
          agentId: agentId,
        ),
    };
  }

  AgentRunEvent _annotateDelegationRunEvent(
    AgentRunEvent event, {
    required String runId,
  }) {
    return switch (event) {
      AgentDelegationEvent(
        phase: final phase,
        parentSessionId: final parentSessionId,
        childSessionId: final childSessionId,
        delegatedAgentId: final delegatedAgentId,
      ) =>
        AgentDelegationEvent(
          phase: phase,
          parentSessionId: parentSessionId,
          childSessionId: childSessionId,
          delegatedAgentId: delegatedAgentId,
          sessionId: id,
          runId: runId,
          agentId: profileId,
        ),
      AgentPermissionEvent(decision: final decision) => AgentPermissionEvent(
        decision: decision,
        sessionId: id,
        runId: runId,
        agentId: profileId,
      ),
      _ => event,
    };
  }

  Future<AgentPendingApprovalRequest> _pauseForApproval(
    _ActiveManagedRun activeRun,
    AgentApprovalRequiredException error,
  ) async {
    final baseRequest = error.request;
    if (baseRequest == null) {
      throw StateError('Approval pause is missing a pending request payload.');
    }

    final request = baseRequest.withRunId(activeRun.runId);
    _session = _session.copyWith(pendingApproval: request);
    await _store.save(_session);
    return request;
  }

  Future<void> _clearPendingApproval() async {
    _session = _session.copyWith(pendingApproval: null);
    await _store.save(_session);
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
