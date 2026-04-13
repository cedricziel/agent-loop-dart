import 'package:agent_loop_core/agent_loop_core.dart';

class AgentLoopSdk {
  AgentLoopSdk({
    AgentProvider? provider,
    AgentModel? model,
    Iterable<AgentTool> tools = const <AgentTool>[],
    AgentSessionStore? store,
    String? systemPrompt,
    int maxSteps = 8,
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
       ),
       _sessionManager = AgentSessionManager(
         loop: AgentLoop(
           provider: provider,
           model: model,
           tools: tools,
           systemPrompt: systemPrompt,
           maxSteps: maxSteps,
         ),
         store: store,
         sessionIdGenerator: sessionIdGenerator,
         runIdGenerator: runIdGenerator,
       );

  final AgentLoop _loop;
  final AgentSessionManager _sessionManager;

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

  Future<ManagedAgentSession> createSession() =>
      _sessionManager.createSession();

  Future<ManagedAgentSession> loadSession(String id) =>
      _sessionManager.loadSession(id);
}
