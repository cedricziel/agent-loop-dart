import 'dart:io';

import 'package:agent_loop/agent_loop.dart';

class DemoModel implements AgentModel {
  const DemoModel();

  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    final lastMessage = turn.messages.last;

    if (lastMessage.role == AgentRole.tool && lastMessage.toolResult != null) {
      return AgentResponse(
        parts: <MessagePart>[
          TextPart(
            text:
                'The tool `${lastMessage.toolResult!.name}` returned ${lastMessage.toolResult!.output}.',
          ),
        ],
      );
    }

    final latestUserMessage = turn.messages.lastWhere(
      (message) => message.role == AgentRole.user,
      orElse: () => const AgentMessage(role: AgentRole.user, content: ''),
    );
    final prompt = latestUserMessage.content.toLowerCase();

    if (prompt.contains('time') &&
        turn.tools.any((tool) => tool.name == 'bash')) {
      return AgentResponse(
        parts: <MessagePart>[
          const ReasoningPart(text: 'Need the bash tool first.'),
        ],
        toolCalls: <ToolCall>[
          const ToolCall(
            id: 'bash-1',
            name: 'bash',
            input: <String, Object?>{'command': 'date'},
          ),
        ],
      );
    }

    if (prompt.contains('report')) {
      return AgentResponse(
        parts: <MessagePart>[
          const TextPart(text: 'Generated report'),
          const FilePart(path: 'build/report.txt', mimeType: 'text/plain'),
        ],
      );
    }

    return AgentResponse(
      parts: <MessagePart>[
        TextPart(text: 'Demo model response: ${latestUserMessage.content}'),
      ],
    );
  }
}

String? formatPartForLog(MessagePart part) => switch (part) {
  ReasoningPart(text: final text) => 'assistant:reasoning $text',
  FilePart(path: final path, mimeType: final mimeType) =>
    'assistant:file $path ($mimeType)',
  ToolPart(name: final name, state: ToolPartState.pending) =>
    'tool:pending $name',
  ToolPart(
    name: final name,
    state: ToolPartState.completed,
    output: final output,
  ) =>
    'tool:completed $name => ${output ?? ''}',
  TextPart() => null,
};

String formatQuestionPrompt(AgentPendingQuestionRequest request) {
  final lines = <String>[
    'question: ${request.question.header}',
    request.question.question,
  ];
  for (final option in request.question.options) {
    lines.add('- ${option.id}: ${option.label} (${option.description})');
  }
  return lines.join('\n');
}

AgentLoopSdk createDemoSdk() {
  return AgentLoopSdk(
    model: const DemoModel(),
    builtinToolOptions: BuiltinToolOptions(workspaceRoot: Directory.current),
    systemPrompt: 'You are a compact coding agent.',
    reliabilityPolicy: AgentReliabilityPolicy.standard(),
    profiles: const <AgentProfile>[
      AgentProfile(
        id: 'primary',
        systemPrompt: 'You are a compact coding agent.',
        permissionPolicy: DeclarativeAgentPermissionPolicy(
          toolPermissions: <String, AgentPermissionOutcome>{
            'bash': AgentPermissionOutcome.ask,
          },
        ),
      ),
      AgentProfile(
        id: 'researcher',
        systemPrompt: 'You are a research specialist.',
        mode: AgentProfileMode.subagent,
      ),
    ],
  );
}

Future<ManagedAgentSession> createManagedDemoSession(AgentLoopSdk sdk) async {
  final session = await sdk.createSession(profileId: 'primary');
  return sdk.loadSession(session.id);
}

Future<int> runCli(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run packages/agent_loop_cli/bin/agent_loop.dart <prompt>',
    );
    return 64;
  }

  final sdk = createDemoSdk();
  final session = await createManagedDemoSession(sdk);

  AgentRunResult? result;

  final prompt = args.join(' ');
  final events = prompt.toLowerCase().contains('research')
      ? session.delegateStream('researcher', prompt)
      : session.stream(prompt);

  await _consumeEvents(events, session, (completedResult) {
    result = completedResult;
  });

  while (session.pendingApproval != null || session.pendingQuestion != null) {
    final resolutionEvents = switch ((
      session.pendingApproval,
      session.pendingQuestion,
    )) {
      (final approval?, _) =>
        (await _resolvePendingApproval(approval))
            ? session.approvePendingStream()
            : session.denyPendingStream(),
      (_, final question?) => switch (await _resolvePendingQuestion(question)) {
        final answer? => session.answerPendingQuestionStream(answer),
        null => session.cancelPendingQuestionStream(),
      },
      _ => const Stream<AgentRunEvent>.empty(),
    };
    await _consumeEvents(resolutionEvents, session, (completedResult) {
      result = completedResult;
    });
  }

  stdout.writeln(result?.output ?? '');
  return 0;
}

Future<void> _consumeEvents(
  Stream<AgentRunEvent> events,
  ManagedAgentSession session,
  void Function(AgentRunResult result) onComplete,
) async {
  await for (final event in events) {
    switch (event) {
      case AgentDelegationEvent(
        phase: AgentDelegationPhase.start,
        delegatedAgentId: final delegatedAgentId,
      ):
        stderr.writeln('delegation:start $delegatedAgentId');
      case AgentDelegationEvent(
        phase: AgentDelegationPhase.complete,
        delegatedAgentId: final delegatedAgentId,
      ):
        stderr.writeln('delegation:complete $delegatedAgentId');
      case AgentRunStartEvent():
        // Managed sessions add explicit run lifecycle metadata.
        break;
      case AgentPermissionEvent(decision: final decision):
        stderr.writeln(
          'permission:${decision.outcome.name} ${decision.kind.name} ${decision.subject}',
        );
      case AgentApprovalRequiredEvent(request: final request):
        stderr.writeln(
          'approval:required ${request.decision.kind.name} ${request.decision.subject}',
        );
      case AgentQuestionRequiredEvent(request: final request):
        stderr.writeln('question:required ${request.question.header}');
      case AgentApprovalResolvedEvent(resolution: final resolution):
        stderr.writeln('approval:resolved ${resolution.name}');
      case AgentQuestionResolvedEvent(resolution: final resolution):
        stderr.writeln('question:resolved ${resolution.name}');
      case AgentMessagePartEvent(part: final part):
        final line = formatPartForLog(part);
        if (line != null && line.isNotEmpty) {
          stderr.writeln(line);
        }
      case AgentAssistantEvent(message: final message)
          when message.toolCall != null:
        stderr.writeln('assistant: ${message.content}');
      case AgentToolCallEvent():
        // Tool parts already describe pending tool state.
        break;
      case AgentToolResultEvent():
        // Tool parts already describe completed tool state.
        break;
      case AgentRunCompleteEvent(result: final completedResult):
        onComplete(completedResult);
      case AgentRunCancelledEvent():
        stderr.writeln('run:cancelled');
      case AgentProviderRetryEvent(
        attempt: final attempt,
        maxAttempts: final maxAttempts,
        delay: final delay,
        failure: final failure,
      ):
        stderr.writeln(
          'provider:retry $attempt/$maxAttempts ${failure.provider} ${failure.kind.name} ${delay.inMilliseconds}ms',
        );
      case AgentProviderRetryExhaustedEvent(
        attempt: final attempt,
        maxAttempts: final maxAttempts,
        failure: final failure,
      ):
        stderr.writeln(
          'provider:exhausted $attempt/$maxAttempts ${failure.provider} ${failure.kind.name}',
        );
      case AgentAutoCompactionEvent(
        compaction: final compaction,
        policy: final policy,
      ):
        stderr.writeln(
          'session:auto-compact ${policy.summarizerId} ${compaction.compactedMessageCount}->${compaction.retainedMessageCount}',
        );
      case AgentAssistantEvent():
        // Keep normal assistant text on stdout via the final result only.
        break;
    }
  }
}

Future<bool> _resolvePendingApproval(
  AgentPendingApprovalRequest request,
) async {
  if (!stdin.hasTerminal) {
    stderr.writeln('approval:auto approved');
    return true;
  }

  stderr.write(
    'Approve ${request.decision.kind.name} `${request.decision.subject}`? [y/N] ',
  );
  final response = stdin.readLineSync()?.trim().toLowerCase();
  if (response == null) {
    stderr.writeln('approval:auto approved');
    return true;
  }
  return response == 'y' || response == 'yes';
}

Future<AskUserAnswer?> _resolvePendingQuestion(
  AgentPendingQuestionRequest request,
) async {
  stderr.writeln(formatQuestionPrompt(request));

  if (!stdin.hasTerminal) {
    stderr.writeln('question:auto cancelled');
    return null;
  }

  stderr.write('Selected option ids (comma-separated, optional): ');
  final selectedRaw = stdin.readLineSync()?.trim();
  if (selectedRaw != null && selectedRaw.toLowerCase() == 'cancel') {
    return null;
  }

  stderr.write('Freeform answer (optional, type cancel to cancel): ');
  final freeform = stdin.readLineSync()?.trim();
  if (freeform != null && freeform.toLowerCase() == 'cancel') {
    return null;
  }

  final selectedOptionIds = selectedRaw == null || selectedRaw.isEmpty
      ? const <String>[]
      : selectedRaw
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList(growable: false);

  return AskUserAnswer(
    selectedOptionIds: selectedOptionIds,
    freeformText: freeform == null || freeform.isEmpty ? null : freeform,
  );
}
