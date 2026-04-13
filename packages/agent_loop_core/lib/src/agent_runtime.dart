import 'agent_loop.dart';
import 'agent_model.dart';
import 'agent_permissions.dart';
import 'agent_session_manager.dart';
import 'agent_tool.dart';
import 'agent_types.dart';

enum AgentProfileVisibility { visible, hidden }

enum AgentProfileMode { primary, subagent }

class AgentProfile {
  const AgentProfile({
    required this.id,
    this.systemPrompt,
    this.maxSteps,
    this.visibility = AgentProfileVisibility.visible,
    this.mode = AgentProfileMode.primary,
    this.provider,
    this.permissionPolicy,
  });

  final String id;
  final String? systemPrompt;
  final int? maxSteps;
  final AgentProfileVisibility visibility;
  final AgentProfileMode mode;
  final AgentProvider? provider;
  final AgentPermissionPolicy? permissionPolicy;
}

class AgentDelegationHookEvent {
  const AgentDelegationHookEvent({
    required this.phase,
    required this.parentSessionId,
    required this.agentId,
    this.childSessionId,
  });

  final AgentDelegationPhase phase;
  final String parentSessionId;
  final String agentId;
  final String? childSessionId;
}

abstract interface class AgentRuntimeHook {
  Future<void> onPermissionEvaluated(
    AgentPermissionDecision decision,
    ManagedAgentSession session,
  );

  Future<void> onDelegation(AgentDelegationHookEvent event);
}

class AgentRuntime {
  AgentRuntime({
    AgentProvider? provider,
    AgentModel? model,
    Iterable<AgentTool> tools = const <AgentTool>[],
    Iterable<AgentProfile> profiles = const <AgentProfile>[],
    Iterable<AgentRuntimeHook> hooks = const <AgentRuntimeHook>[],
    AgentSessionStore? store,
    String? systemPrompt,
    int maxSteps = 8,
    String Function()? sessionIdGenerator,
    String Function()? runIdGenerator,
  }) : assert(
         provider != null || model != null,
         'Provide either an AgentProvider or an AgentModel.',
       ),
       _defaultProvider = provider ?? model!,
       _tools = List<AgentTool>.unmodifiable(tools),
       _defaultSystemPrompt = systemPrompt,
       _defaultMaxSteps = maxSteps,
       _profiles = <String, AgentProfile>{
         for (final profile in profiles) profile.id: profile,
       },
       _hooks = List<AgentRuntimeHook>.unmodifiable(hooks),
       _store = store ?? InMemoryAgentSessionStore(),
       _sessionIdGenerator = sessionIdGenerator,
       _runIdGenerator = runIdGenerator {
    _sessionManager = AgentSessionManager(
      loopFactory: _loopForSession,
      delegateHandler: _delegate,
      delegateStreamHandler: _delegateStream,
      store: _store,
      sessionIdGenerator: _sessionIdGenerator,
      runIdGenerator: _runIdGenerator,
    );
  }

  final AgentProvider _defaultProvider;
  final List<AgentTool> _tools;
  final String? _defaultSystemPrompt;
  final int _defaultMaxSteps;
  final Map<String, AgentProfile> _profiles;
  final List<AgentRuntimeHook> _hooks;
  final AgentSessionStore _store;
  final String Function()? _sessionIdGenerator;
  final String Function()? _runIdGenerator;
  late final AgentSessionManager _sessionManager;

  Iterable<AgentProfile> get visibleProfiles => _profiles.values.where(
    (profile) => profile.visibility == AgentProfileVisibility.visible,
  );

  AgentProfile? profile(String id) => _profiles[id];

  Future<ManagedAgentSession> createSession({String? profileId}) {
    return _sessionManager.createSession(profileId: profileId);
  }

  Future<ManagedAgentSession> loadSession(String id) {
    return _sessionManager.loadSession(id);
  }

  AgentLoop _loopForSession(AgentSession session) {
    final profile = _profiles[session.profileId];

    return AgentLoop(
      provider: profile?.provider ?? _defaultProvider,
      tools: _tools,
      systemPrompt: profile?.systemPrompt ?? _defaultSystemPrompt,
      maxSteps: profile?.maxSteps ?? _defaultMaxSteps,
      toolPermissionCheck: profile?.permissionPolicy == null
          ? null
          : (toolCall) async {
              final decision = await profile!.permissionPolicy!.evaluateTool(
                toolCall,
              );
              final managedSession = await _sessionManager.loadSession(
                session.id ?? '',
              );
              for (final hook in _hooks) {
                await hook.onPermissionEvaluated(decision, managedSession);
              }
              return decision;
            },
    );
  }

  Future<ManagedAgentSession> _delegate(
    ManagedAgentSession session,
    String profileId,
    String prompt,
  ) async {
    final child = await _createDelegatedChild(session, profileId);
    await child.run(prompt);
    return child;
  }

  Stream<AgentRunEvent> _delegateStream(
    ManagedAgentSession session,
    String profileId,
    String prompt,
  ) async* {
    final child = await _createDelegatedChild(session, profileId);

    yield AgentDelegationEvent(
      phase: AgentDelegationPhase.start,
      parentSessionId: session.id,
      childSessionId: child.id,
      delegatedAgentId: profileId,
      sessionId: session.id,
      agentId: session.profileId,
    );

    await for (final event in child.stream(prompt)) {
      yield event;
    }

    yield AgentDelegationEvent(
      phase: AgentDelegationPhase.complete,
      parentSessionId: session.id,
      childSessionId: child.id,
      delegatedAgentId: profileId,
      sessionId: session.id,
      agentId: session.profileId,
    );
  }

  Future<ManagedAgentSession> _createDelegatedChild(
    ManagedAgentSession session,
    String profileId,
  ) async {
    for (final hook in _hooks) {
      await hook.onDelegation(
        AgentDelegationHookEvent(
          phase: AgentDelegationPhase.start,
          parentSessionId: session.id,
          agentId: profileId,
        ),
      );
    }

    final parentProfile = _profiles[session.profileId];
    final decision = await parentProfile?.permissionPolicy?.evaluateSubagent(
      profileId,
    );
    if (decision != null) {
      for (final hook in _hooks) {
        await hook.onPermissionEvaluated(decision, session);
      }
      switch (decision.outcome) {
        case AgentPermissionOutcome.allow:
          break;
        case AgentPermissionOutcome.ask:
          throw AgentApprovalRequiredException(decision);
        case AgentPermissionOutcome.deny:
          throw AgentPermissionDeniedException(decision);
      }
    }

    final child = await _sessionManager.createSession(
      profileId: profileId,
      parentId: session.id,
      delegatingAgentId: session.profileId,
    );
    for (final hook in _hooks) {
      await hook.onDelegation(
        AgentDelegationHookEvent(
          phase: AgentDelegationPhase.complete,
          parentSessionId: session.id,
          childSessionId: child.id,
          agentId: profileId,
        ),
      );
    }
    return child;
  }
}
