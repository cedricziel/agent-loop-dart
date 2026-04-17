import 'dart:io';

import 'package:agent_loop/agent_loop.dart';
import 'package:agent_loop_examples/agent_loop_examples.dart';
import 'package:agent_loop_provider_anthropic/agent_loop_provider_anthropic.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run packages/agent_loop_examples/bin/anthropic_loop.dart <prompt>',
    );
    exitCode = 64;
    return;
  }

  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set ANTHROPIC_API_KEY to run the Anthropic example.');
    exitCode = 64;
    return;
  }

  final model = Platform.environment['ANTHROPIC_MODEL'] ?? 'claude-haiku-4-5';
  final baseUrl = Platform.environment['ANTHROPIC_BASE_URL'];
  final anthropicVersion =
      Platform.environment['ANTHROPIC_VERSION'] ?? '2023-06-01';
  final systemPrompt =
      Platform.environment['AGENT_LOOP_SYSTEM_PROMPT'] ??
      'You are a concise, helpful coding assistant. Use the available tools when they help answer questions about time, files, or the current working directory.';

  final provider = AnthropicProvider(
    apiKey: apiKey,
    model: model,
    baseUri: baseUrl == null ? null : Uri.parse(baseUrl),
    anthropicVersion: anthropicVersion,
  );
  final sdk = AgentLoopSdk(
    provider: provider,
    systemPrompt: systemPrompt,
    tools: createLocalTools(),
    reliabilityPolicy: AgentReliabilityPolicy.standard(),
  );

  var printedText = false;
  await for (final event in sdk.stream(prompt: args.join(' '))) {
    switch (event) {
      case AgentMessagePartEvent(part: final TextPart part):
        stdout.write(part.text);
        printedText = true;
      case AgentMessagePartEvent(part: final ReasoningPart part):
        stderr.writeln('reasoning: ${part.text}');
      case AgentMessagePartEvent(part: final FilePart part):
        stderr.writeln('file: ${part.path} (${part.mimeType})');
      case AgentMessagePartEvent(part: final ToolPart part):
        stderr.writeln('tool:part ${part.name} ${part.state.name}');
      case AgentToolCallEvent(call: final call):
        stderr.writeln('tool:call ${call.name}');
      case AgentToolResultEvent(result: final result):
        stderr.writeln('tool:result ${result.name} => ${result.output}');
      case AgentRunCompleteEvent(result: final result):
        if (!printedText) {
          stdout.write(result.output);
        }
        stdout.writeln();
      case AgentAssistantEvent():
      case AgentRunStartEvent():
      case AgentRunCancelledEvent():
      case AgentPermissionEvent():
      case AgentApprovalRequiredEvent():
      case AgentQuestionRequiredEvent():
      case AgentApprovalResolvedEvent():
      case AgentQuestionResolvedEvent():
      case AgentDelegationEvent():
        break;
      case AgentProviderRetryEvent(
        attempt: final attempt,
        maxAttempts: final maxAttempts,
        delay: final delay,
        failure: final failure,
      ):
        stderr.writeln(
          'provider:retry $attempt/$maxAttempts ${failure.provider} ${failure.kind.name} ${delay.inMilliseconds}ms',
        );
        break;
      case AgentProviderRetryExhaustedEvent(
        attempt: final attempt,
        maxAttempts: final maxAttempts,
        failure: final failure,
      ):
        stderr.writeln(
          'provider:exhausted $attempt/$maxAttempts ${failure.provider} ${failure.kind.name}',
        );
        break;
      case AgentAutoCompactionEvent(
        compaction: final compaction,
        policy: final policy,
      ):
        stderr.writeln(
          'session:auto-compact ${policy.summarizerId} ${compaction.compactedMessageCount}->${compaction.retainedMessageCount}',
        );
        break;
    }
  }
}
