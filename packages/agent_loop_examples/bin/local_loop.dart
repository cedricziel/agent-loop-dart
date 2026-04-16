import 'dart:io';

import 'package:agent_loop/agent_loop.dart';
import 'package:agent_loop_provider_ollama/agent_loop_provider_ollama.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run packages/agent_loop_examples/bin/local_loop.dart <prompt>',
    );
    exitCode = 64;
    return;
  }

  final model = Platform.environment['OLLAMA_MODEL'] ?? 'gemma4:e4b';
  final baseUrl = Platform.environment['OLLAMA_BASE_URL'];
  final systemPrompt =
      Platform.environment['AGENT_LOOP_SYSTEM_PROMPT'] ??
      'You are a concise, helpful local coding assistant. Use the available tools when they help answer questions about time, files, or the current working directory.';

  final provider = OllamaProvider(
    model: model,
    baseUri: baseUrl == null ? null : Uri.parse(baseUrl),
  );
  final sdk = AgentLoopSdk(
    provider: provider,
    systemPrompt: systemPrompt,
    builtinToolOptions: BuiltinToolOptions(workspaceRoot: Directory.current),
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
      case AgentApprovalResolvedEvent():
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
