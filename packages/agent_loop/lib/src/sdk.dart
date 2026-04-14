import 'package:agent_loop_core/agent_loop_core.dart';

class AgentLoopSdk {
  AgentLoopSdk({
    AgentProvider? provider,
    AgentModel? model,
    Iterable<AgentTool> tools = const <AgentTool>[],
    Iterable<AgentProfile> profiles = const <AgentProfile>[],
    Iterable<AgentRuntimeHook> hooks = const <AgentRuntimeHook>[],
    AgentSessionStore? store,
    Map<String, AgentSessionSummarizer> automaticCompactionSummarizers =
        const <String, AgentSessionSummarizer>{},
    String? systemPrompt,
    int maxSteps = 8,
    AgentReliabilityPolicy? reliabilityPolicy,
    String Function()? sessionIdGenerator,
    String Function()? runIdGenerator,
  }) : assert(
         provider != null || model != null,
         'Provide either an AgentProvider or an AgentModel.',
       ),
       _loop = AgentLoop(
         provider: provider,
         model: model,
         tools: tools,
         systemPrompt: systemPrompt,
         maxSteps: maxSteps,
         reliabilityPolicy: reliabilityPolicy,
       ),
       _runtime = AgentRuntime(
         provider: provider,
         model: model,
         tools: tools,
         profiles: profiles,
         hooks: hooks,
         store: store,
         automaticCompactionSummarizers: automaticCompactionSummarizers,
         systemPrompt: systemPrompt,
         maxSteps: maxSteps,
         reliabilityPolicy: reliabilityPolicy,
         sessionIdGenerator: sessionIdGenerator,
         runIdGenerator: runIdGenerator,
       );

  final AgentLoop _loop;
  final AgentRuntime _runtime;

  Iterable<AgentProfile> get visibleProfiles => _runtime.visibleProfiles;

  Future<AgentRunResult> run({
    required String prompt,
    AgentSession? session,
    List<AgentMessage> transcript = const <AgentMessage>[],
  }) => _loop.run(prompt, session: session, transcript: transcript);

  Stream<AgentRunEvent> stream({
    required String prompt,
    AgentSession? session,
    List<AgentMessage> transcript = const <AgentMessage>[],
  }) => _loop.stream(prompt, session: session, transcript: transcript);

  Future<ManagedAgentSession> createSession({
    String? profileId,
    AgentAutoCompactionPolicy? automaticCompactionPolicy,
  }) => _runtime.createSession(
    profileId: profileId,
    automaticCompactionPolicy: automaticCompactionPolicy,
  );

  Future<ManagedAgentSession> loadSession(String id) =>
      _runtime.loadSession(id);
}
