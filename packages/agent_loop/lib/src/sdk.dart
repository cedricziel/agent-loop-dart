import 'package:agent_loop_core/agent_loop_core.dart';

class AgentLoopSdk {
  AgentLoopSdk({
    required AgentModel model,
    Iterable<AgentTool> tools = const <AgentTool>[],
    String? systemPrompt,
    int maxSteps = 8,
  }) : _loop = AgentLoop(
         model: model,
         tools: tools,
         systemPrompt: systemPrompt,
         maxSteps: maxSteps,
       );

  final AgentLoop _loop;

  Future<AgentRunResult> run({required String prompt}) => _loop.run(prompt);
}
