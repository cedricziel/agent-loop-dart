import 'package:agent_loop_core/agent_loop_core.dart';

class AgentLoopSdk {
  AgentLoopSdk({
    AgentProvider? provider,
    AgentModel? model,
    Iterable<AgentTool> tools = const <AgentTool>[],
    String? systemPrompt,
    int maxSteps = 8,
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
       );

  final AgentLoop _loop;

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
}
