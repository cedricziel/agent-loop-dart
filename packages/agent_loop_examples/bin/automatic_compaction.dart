import 'dart:io';

import 'package:agent_loop/agent_loop.dart';

Future<void> main() async {
  final sdk = AgentLoopSdk(
    model: const LoopbackModel(),
    store: InMemoryAgentSessionStore(),
    automaticCompactionSummarizers: <String, AgentSessionSummarizer>{
      'prefix': const _PrefixSummarizer(),
    },
  );

  final session = await sdk.createSession(
    automaticCompactionPolicy: const AgentAutoCompactionPolicy(
      maxTranscriptMessages: 3,
      retainLastMessages: 2,
      summarizerId: 'prefix',
    ),
  );

  await session.run('alpha');

  await for (final event in session.stream('beta')) {
    switch (event) {
      case AgentAutoCompactionEvent(
        compaction: final compaction,
        policy: final policy,
      ):
        stdout.writeln(
          'Auto-compacted with `${policy.summarizerId}`: ${compaction.summary.text}',
        );
      case AgentRunCompleteEvent(result: final result):
        stdout.writeln('Latest output: ${result.output}');
      case AgentRunStartEvent():
      case AgentAssistantEvent():
      case AgentMessagePartEvent():
      case AgentToolCallEvent():
      case AgentToolResultEvent():
      case AgentRunCancelledEvent():
      case AgentProviderRetryEvent():
      case AgentProviderRetryExhaustedEvent():
      case AgentPermissionEvent():
      case AgentApprovalRequiredEvent():
      case AgentApprovalResolvedEvent():
      case AgentDelegationEvent():
        break;
    }
  }

  stdout.writeln('Stored transcript after compaction:');
  for (final message in session.transcript) {
    stdout.writeln('- ${message.role.name}: ${message.content}');
  }
}

class _PrefixSummarizer implements AgentSessionSummarizer {
  const _PrefixSummarizer();

  @override
  Future<AgentSessionSummary> summarize(List<AgentMessage> messages) async {
    return AgentSessionSummary(
      text: messages.map((message) => message.content).join(' | '),
    );
  }
}
