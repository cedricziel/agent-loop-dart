import 'dart:io';

import 'package:agent_loop/agent_loop.dart';

Future<void> main() async {
  final sdk = AgentLoopSdk(
    model: const LoopbackModel(),
    store: InMemoryAgentSessionStore(),
  );

  final session = await sdk.createSession();
  await session.run('alpha');
  await session.run('beta');

  final compaction = await session.compact(
    retainLastMessages: 2,
    summarizer: const _PrefixSummarizer(),
  );

  final resumed = await session.run('gamma');

  stdout.writeln('Compaction summary: ${compaction.summary.text}');
  stdout.writeln('Stored transcript:');
  for (final message in session.transcript) {
    stdout.writeln('- ${message.role.name}: ${message.content}');
  }
  stdout.writeln('Follow-up output: ${resumed.output}');
}

class _PrefixSummarizer implements AgentSessionSummarizer {
  const _PrefixSummarizer();

  @override
  Future<AgentSessionSummary> summarize(List<AgentMessage> messages) async {
    final text = messages.map((message) => message.content).join(' | ');
    return AgentSessionSummary(text: text);
  }
}
