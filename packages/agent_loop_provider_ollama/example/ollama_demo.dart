import 'package:agent_loop_core/agent_loop_core.dart';
import 'package:agent_loop_provider_ollama/agent_loop_provider_ollama.dart';

Future<void> main() async {
  final loop = AgentLoop(
    provider: OllamaProvider(model: 'llama3.2'),
    systemPrompt: 'You are a compact coding agent.',
  );

  final result = await loop.run('Say hello in one sentence.');
  print(result.output);
}
