import 'dart:async';

import 'package:agent_loop_core/agent_loop_core.dart';
import 'package:test/test.dart';

void main() {
  group('AgentRuntime profiles', () {
    test('registers visible and hidden agent profiles', () async {
      final runtime = AgentRuntime(
        provider: const LoopbackModel(),
        profiles: <AgentProfile>[
          const AgentProfile(id: 'primary', systemPrompt: 'Primary prompt'),
          const AgentProfile(
            id: 'researcher',
            systemPrompt: 'Research prompt',
            visibility: AgentProfileVisibility.hidden,
            mode: AgentProfileMode.subagent,
          ),
        ],
      );

      expect(runtime.profile('primary')?.systemPrompt, 'Primary prompt');
      expect(runtime.visibleProfiles.map((profile) => profile.id), <String>[
        'primary',
      ]);
    });

    test('runs a managed session with the selected profile metadata', () async {
      final provider = _CapturingProvider();
      final runtime = AgentRuntime(
        provider: provider,
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'primary',
            systemPrompt: 'Primary prompt',
            maxSteps: 3,
          ),
        ],
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession(profileId: 'primary');
      await session.run('hello');

      expect(session.profileId, 'primary');
      expect(provider.lastSystemPrompt, 'Primary prompt');
      expect(provider.callCount, 1);
    });
  });

  group('AgentRuntime permissions', () {
    test('denies tool calls before execution', () async {
      final runtime = AgentRuntime(
        provider: _ToolCallingProvider(),
        tools: <AgentTool>[const _ClockTool()],
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'locked-down',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              toolPermissions: <String, AgentPermissionOutcome>{
                'clock': AgentPermissionOutcome.deny,
              },
            ),
          ),
        ],
      );

      final session = await runtime.createSession(profileId: 'locked-down');

      await expectLater(
        session.run('what time is it?'),
        throwsA(isA<AgentPermissionDeniedException>()),
      );
    });

    test('surfaces approval-required tool calls', () async {
      final runtime = AgentRuntime(
        provider: _ToolCallingProvider(),
        tools: <AgentTool>[const _ClockTool()],
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'approval',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              toolPermissions: <String, AgentPermissionOutcome>{
                'clock': AgentPermissionOutcome.ask,
              },
            ),
          ),
        ],
      );

      final session = await runtime.createSession(profileId: 'approval');

      await expectLater(
        session.run('what time is it?'),
        throwsA(isA<AgentApprovalRequiredException>()),
      );
    });

    test('pauses tool approval requests on managed sessions', () async {
      final store = InMemoryAgentSessionStore();
      final runtime = AgentRuntime(
        provider: _ToolCallingProvider(),
        tools: <AgentTool>[const _ClockTool()],
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'approval',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              toolPermissions: <String, AgentPermissionOutcome>{
                'clock': AgentPermissionOutcome.ask,
              },
            ),
          ),
        ],
        store: store,
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession(profileId: 'approval');
      final events = await session.stream('what time is it?').toList();
      final reloaded = await runtime.loadSession('session-1');

      expect(events.whereType<AgentPermissionEvent>(), hasLength(1));
      expect(events.whereType<AgentToolCallEvent>(), isEmpty);
      expect(events.whereType<AgentToolResultEvent>(), isEmpty);
      expect(session.pendingApproval, isNotNull);
      expect(session.pendingApproval!.runId, 'run-1');
      expect(
        session.pendingApproval!.decision.outcome,
        AgentPermissionOutcome.ask,
      );
      expect(session.pendingApproval, isA<AgentToolApprovalRequest>());
      expect(
        (session.pendingApproval as AgentToolApprovalRequest).toolCall.name,
        'clock',
      );
      expect(reloaded.pendingApproval, isA<AgentToolApprovalRequest>());
    });

    test('pauses ask_user requests on managed sessions', () async {
      final store = InMemoryAgentSessionStore();
      final runtime = AgentRuntime(
        provider: _AskUserProvider(),
        tools: <AgentTool>[const _ClockTool()],
        store: store,
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession();
      final events = await session.stream('what should I do?').toList();
      final reloaded = await runtime.loadSession('session-1');

      expect(events.whereType<AgentQuestionRequiredEvent>(), hasLength(1));
      expect(events.whereType<AgentToolCallEvent>(), isEmpty);
      expect(events.whereType<AgentToolResultEvent>(), isEmpty);
      expect(session.pendingQuestion, isNotNull);
      expect(session.pendingQuestion!.runId, 'run-1');
      expect(session.pendingQuestion!.question.header, 'Need direction');
      expect(
        session.pendingQuestion!.question.options.single.description,
        'Proceed with staging only',
      );
      expect(reloaded.pendingQuestion, isNotNull);
    });

    test(
      'emits permission events without fabricating tool transcript activity',
      () async {
        final runtime = AgentRuntime(
          provider: _ToolCallingProvider(),
          tools: <AgentTool>[const _ClockTool()],
          profiles: const <AgentProfile>[
            AgentProfile(
              id: 'locked-down',
              permissionPolicy: DeclarativeAgentPermissionPolicy(
                toolPermissions: <String, AgentPermissionOutcome>{
                  'clock': AgentPermissionOutcome.deny,
                },
              ),
            ),
          ],
        );

        final session = await runtime.createSession(profileId: 'locked-down');
        final events = await session.stream('what time is it?').toList();

        expect(events.whereType<AgentPermissionEvent>(), hasLength(1));
        expect(events.whereType<AgentToolCallEvent>(), isEmpty);
        expect(events.whereType<AgentToolResultEvent>(), isEmpty);
        expect(events.last, isA<AgentPermissionEvent>());
        expect(
          session.transcript.map((message) => message.role),
          <AgentRole>[],
        );
      },
    );
  });

  group('AgentRuntime subagent hierarchy', () {
    test('delegates work into a child session and can list children', () async {
      final runtime = AgentRuntime(
        provider: const LoopbackModel(),
        profiles: const <AgentProfile>[
          AgentProfile(id: 'primary'),
          AgentProfile(id: 'researcher', mode: AgentProfileMode.subagent),
        ],
        sessionIdGenerator: _IdSequence(<String>[
          'session-1',
          'session-2',
        ]).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final parent = await runtime.createSession(profileId: 'primary');
      final child = await parent.delegate('researcher', 'hello');
      final children = await parent.children();

      expect(child.id, 'session-2');
      expect(child.parentId, 'session-1');
      expect(child.profileId, 'researcher');
      expect(child.delegatingAgentId, 'primary');
      expect(children.map((session) => session.id), <String>['session-2']);
      expect(child.transcript.map((message) => message.content), <String>[
        'hello',
        'hello',
      ]);
    });

    test('denies subagent delegation by policy', () async {
      final runtime = AgentRuntime(
        provider: const LoopbackModel(),
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'primary',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              subagentPermissions: <String, AgentPermissionOutcome>{
                'researcher': AgentPermissionOutcome.deny,
              },
            ),
          ),
          AgentProfile(id: 'researcher', mode: AgentProfileMode.subagent),
        ],
      );

      final parent = await runtime.createSession(profileId: 'primary');

      await expectLater(
        parent.delegate('researcher', 'hello'),
        throwsA(isA<AgentPermissionDeniedException>()),
      );
    });

    test('surfaces approval-required subagent delegation', () async {
      final runtime = AgentRuntime(
        provider: const LoopbackModel(),
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'primary',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              subagentPermissions: <String, AgentPermissionOutcome>{
                'researcher': AgentPermissionOutcome.ask,
              },
            ),
          ),
          AgentProfile(id: 'researcher', mode: AgentProfileMode.subagent),
        ],
      );

      final parent = await runtime.createSession(profileId: 'primary');

      await expectLater(
        parent.delegate('researcher', 'hello'),
        throwsA(isA<AgentApprovalRequiredException>()),
      );
    });

    test('pauses subagent approval requests on managed sessions', () async {
      final store = InMemoryAgentSessionStore();
      final runtime = AgentRuntime(
        provider: const LoopbackModel(),
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'primary',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              subagentPermissions: <String, AgentPermissionOutcome>{
                'researcher': AgentPermissionOutcome.ask,
              },
            ),
          ),
          AgentProfile(id: 'researcher', mode: AgentProfileMode.subagent),
        ],
        store: store,
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final parent = await runtime.createSession(profileId: 'primary');
      final events = await parent
          .delegateStream('researcher', 'hello')
          .toList();
      final reloaded = await runtime.loadSession('session-1');

      expect(events.whereType<AgentPermissionEvent>(), hasLength(1));
      expect(events.whereType<AgentDelegationEvent>(), isEmpty);
      expect(parent.pendingApproval, isNotNull);
      expect(parent.pendingApproval!.runId, 'run-1');
      expect(parent.pendingApproval, isA<AgentSubagentApprovalRequest>());
      expect(
        (parent.pendingApproval as AgentSubagentApprovalRequest)
            .delegatedAgentId,
        'researcher',
      );
      expect(reloaded.pendingApproval, isA<AgentSubagentApprovalRequest>());
    });
  });

  group('Managed session approval flow', () {
    test('approves a paused tool request after reload', () async {
      final store = InMemoryAgentSessionStore();
      final runtime = AgentRuntime(
        provider: _ToolThenAnswerProvider(),
        tools: <AgentTool>[const _ClockTool()],
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'approval',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              toolPermissions: <String, AgentPermissionOutcome>{
                'clock': AgentPermissionOutcome.ask,
              },
            ),
          ),
        ],
        store: store,
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession(profileId: 'approval');
      await session.stream('what time is it?').drain<void>();

      final reloaded = await runtime.loadSession('session-1');
      final result = await reloaded.approvePending();

      expect(result.output, 'The time is 12:00.');
      expect(reloaded.pendingApproval, isNull);
      expect(reloaded.transcript.map((message) => message.role), <AgentRole>[
        AgentRole.user,
        AgentRole.assistant,
        AgentRole.tool,
        AgentRole.assistant,
      ]);
    });

    test('denies a paused subagent request without creating a child', () async {
      final store = InMemoryAgentSessionStore();
      final runtime = AgentRuntime(
        provider: const LoopbackModel(),
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'primary',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              subagentPermissions: <String, AgentPermissionOutcome>{
                'researcher': AgentPermissionOutcome.ask,
              },
            ),
          ),
          AgentProfile(id: 'researcher', mode: AgentProfileMode.subagent),
        ],
        store: store,
        sessionIdGenerator: _IdSequence(<String>[
          'session-1',
          'session-2',
        ]).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final session = await runtime.createSession(profileId: 'primary');
      await session.delegateStream('researcher', 'hello').drain<void>();

      await session.denyPending();
      final children = await session.children();

      expect(session.pendingApproval, isNull);
      expect(children, isEmpty);
      expect(session.transcript, isEmpty);
    });

    test('rejects new work while approval is pending', () async {
      final runtime = AgentRuntime(
        provider: _ToolCallingProvider(),
        tools: <AgentTool>[const _ClockTool()],
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'approval',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              toolPermissions: <String, AgentPermissionOutcome>{
                'clock': AgentPermissionOutcome.ask,
              },
            ),
          ),
        ],
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession(profileId: 'approval');
      await session.stream('what time is it?').drain<void>();

      await expectLater(
        session.run('another prompt'),
        throwsA(isA<AgentSessionRunActiveException>()),
      );
    });

    test('does not auto compact while approval is pending', () async {
      final runtime = AgentRuntime(
        provider: _ToolCallingProvider(),
        tools: <AgentTool>[const _ClockTool()],
        automaticCompactionSummarizers: <String, AgentSessionSummarizer>{
          'default': _RecordingSummarizer('auto summary'),
        },
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'approval',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              toolPermissions: <String, AgentPermissionOutcome>{
                'clock': AgentPermissionOutcome.ask,
              },
            ),
          ),
        ],
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession(
        profileId: 'approval',
        automaticCompactionPolicy: const AgentAutoCompactionPolicy(
          maxTranscriptMessages: 1,
          retainLastMessages: 0,
          summarizerId: 'default',
        ),
      );
      final events = await session.stream('what time is it?').toList();

      expect(events.whereType<AgentAutoCompactionEvent>(), isEmpty);
      expect(events.last, isA<AgentApprovalRequiredEvent>());
      expect(session.pendingApproval, isNotNull);
      expect(session.compaction, isNull);
    });

    test('rejects new work while question is pending', () async {
      final runtime = AgentRuntime(
        provider: _AskUserProvider(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession();
      await session.stream('what should I do?').drain<void>();

      await expectLater(
        session.run('another prompt'),
        throwsA(isA<AgentSessionRunActiveException>()),
      );
    });
  });

  group('Approval lifecycle events', () {
    test('orders tool approval pause and resume events', () async {
      final runtime = AgentRuntime(
        provider: _ToolThenAnswerProvider(),
        tools: <AgentTool>[const _ClockTool()],
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'approval',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              toolPermissions: <String, AgentPermissionOutcome>{
                'clock': AgentPermissionOutcome.ask,
              },
            ),
          ),
        ],
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession(profileId: 'approval');
      final pausedEvents = await session.stream('what time is it?').toList();
      final resumedEvents = await session.approvePendingStream().toList();

      expect(pausedEvents.first, isA<AgentRunStartEvent>());
      expect(pausedEvents[1], isA<AgentPermissionEvent>());
      expect(pausedEvents[2], isA<AgentApprovalRequiredEvent>());
      expect(pausedEvents.whereType<AgentToolCallEvent>(), isEmpty);

      expect(resumedEvents.first, isA<AgentApprovalResolvedEvent>());
      expect(resumedEvents[1], isA<AgentAssistantEvent>());
      expect(resumedEvents[2], isA<AgentMessagePartEvent>());
      expect(resumedEvents[3], isA<AgentToolCallEvent>());
      expect(resumedEvents[4], isA<AgentMessagePartEvent>());
      expect(resumedEvents[5], isA<AgentToolResultEvent>());
      expect(resumedEvents.last, isA<AgentRunCompleteEvent>());
      expect(resumedEvents.map((event) => event.runId).toSet(), <String>{
        'run-1',
      });
    });

    test('orders denial before terminating paused work', () async {
      final runtime = AgentRuntime(
        provider: _ToolCallingProvider(),
        tools: <AgentTool>[const _ClockTool()],
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'approval',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              toolPermissions: <String, AgentPermissionOutcome>{
                'clock': AgentPermissionOutcome.ask,
              },
            ),
          ),
        ],
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession(profileId: 'approval');
      final pausedEvents = await session.stream('what time is it?').toList();
      final deniedEvents = await session.denyPendingStream().toList();

      expect(pausedEvents.last, isA<AgentApprovalRequiredEvent>());
      expect(deniedEvents, hasLength(1));
      expect(deniedEvents.single, isA<AgentApprovalResolvedEvent>());
      expect(
        (deniedEvents.single as AgentApprovalResolvedEvent).resolution,
        AgentApprovalResolution.denied,
      );
    });
  });

  group('Question lifecycle events', () {
    test('answers a paused ask_user request after reload', () async {
      final store = InMemoryAgentSessionStore();
      final runtime = AgentRuntime(
        provider: _AskUserProvider(),
        store: store,
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession();
      await session.stream('what should I do?').drain<void>();

      final reloaded = await runtime.loadSession('session-1');
      final result = await reloaded.answerPendingQuestion(
        const AskUserAnswer(
          selectedOptionIds: <String>['staging'],
          freeformText: 'Do staging first',
        ),
      );

      expect(reloaded.pendingQuestion, isNull);
      expect(result.output, contains('Using kind: ask_user_answer'));
      expect(result.transcript.map((message) => message.role), <AgentRole>[
        AgentRole.user,
        AgentRole.assistant,
        AgentRole.tool,
        AgentRole.assistant,
      ]);
      expect(
        result
            .transcript[2]
            .toolResult
            ?.toolOutput
            .metadata['selected_option_ids'],
        <String>['staging'],
      );
      expect(
        result.transcript[2].toolResult?.toolOutput.metadata['freeform_text'],
        'Do staging first',
      );
    });

    test('cancels a paused ask_user request cleanly', () async {
      final runtime = AgentRuntime(
        provider: _AskUserProvider(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession();
      await session.stream('what should I do?').drain<void>();

      final cancelledEvents = await session
          .cancelPendingQuestionStream()
          .toList();

      expect(session.pendingQuestion, isNull);
      expect(cancelledEvents, hasLength(2));
      expect(cancelledEvents.first, isA<AgentQuestionResolvedEvent>());
      expect(
        (cancelledEvents.first as AgentQuestionResolvedEvent).resolution,
        AgentQuestionResolution.cancelled,
      );
      expect(cancelledEvents.last, isA<AgentRunCancelledEvent>());
      expect(session.transcript, isEmpty);
    });

    test('orders ask_user pause and answer resume events', () async {
      final runtime = AgentRuntime(
        provider: _AskUserProvider(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await runtime.createSession();
      final pausedEvents = await session.stream('what should I do?').toList();
      final resumedEvents = await session
          .answerPendingQuestionStream(
            const AskUserAnswer(selectedOptionIds: <String>['staging']),
          )
          .toList();

      expect(pausedEvents.first, isA<AgentRunStartEvent>());
      expect(pausedEvents[1], isA<AgentQuestionRequiredEvent>());
      expect(pausedEvents.whereType<AgentToolCallEvent>(), isEmpty);

      expect(resumedEvents.first, isA<AgentQuestionResolvedEvent>());
      expect(resumedEvents[1], isA<AgentAssistantEvent>());
      expect(resumedEvents[2], isA<AgentMessagePartEvent>());
      expect(resumedEvents[3], isA<AgentToolCallEvent>());
      expect(resumedEvents[4], isA<AgentMessagePartEvent>());
      expect(resumedEvents[5], isA<AgentToolResultEvent>());
      expect(resumedEvents.last, isA<AgentRunCompleteEvent>());
      expect(resumedEvents.map((event) => event.runId).toSet(), <String>{
        'run-1',
      });
    });
  });

  group('AgentRuntime hooks', () {
    test('observes permission evaluation outcomes', () async {
      final hook = _RecordingRuntimeHook();
      final runtime = AgentRuntime(
        provider: _ToolCallingProvider(),
        tools: <AgentTool>[const _ClockTool()],
        hooks: <AgentRuntimeHook>[hook],
        profiles: const <AgentProfile>[
          AgentProfile(
            id: 'locked-down',
            permissionPolicy: DeclarativeAgentPermissionPolicy(
              toolPermissions: <String, AgentPermissionOutcome>{
                'clock': AgentPermissionOutcome.deny,
              },
            ),
          ),
        ],
      );

      final session = await runtime.createSession(profileId: 'locked-down');

      await expectLater(
        session.run('what time is it?'),
        throwsA(isA<AgentPermissionDeniedException>()),
      );

      expect(hook.permissionSubjects, <String>['clock']);
    });

    test('observes delegation lifecycle without bypassing policy', () async {
      final hook = _RecordingRuntimeHook();
      final runtime = AgentRuntime(
        provider: const LoopbackModel(),
        hooks: <AgentRuntimeHook>[hook],
        profiles: const <AgentProfile>[
          AgentProfile(id: 'primary'),
          AgentProfile(id: 'researcher', mode: AgentProfileMode.subagent),
        ],
        sessionIdGenerator: _IdSequence(<String>[
          'session-1',
          'session-2',
        ]).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final parent = await runtime.createSession(profileId: 'primary');
      await parent.delegate('researcher', 'hello');

      expect(hook.delegationPhases, <String>['start', 'complete']);
    });
  });

  group('AgentRuntime run control and events', () {
    test(
      'treats parent and child sessions as separate concurrency scopes',
      () async {
        final provider = _BlockingProvider();
        final runtime = AgentRuntime(
          provider: provider,
          profiles: const <AgentProfile>[
            AgentProfile(id: 'primary'),
            AgentProfile(id: 'researcher', mode: AgentProfileMode.subagent),
          ],
          sessionIdGenerator: _IdSequence(<String>[
            'session-1',
            'session-2',
          ]).next,
          runIdGenerator: _IdSequence(<String>[
            'run-1',
            'run-2',
            'run-3',
            'run-4',
          ]).next,
        );

        final parent = await runtime.createSession(profileId: 'primary');
        final childFuture = parent.delegate('researcher', 'seed');

        await Future<void>.delayed(Duration.zero);
        provider.completeNext(AgentResponse(text: 'seed done'));

        final child = await childFuture;

        final parentRun = parent.run('parent work');
        final childRun = child.run('child work');
        final childCancellation = expectLater(
          childRun,
          throwsA(isA<AgentRunCancelledException>()),
        );

        await Future<void>.delayed(Duration.zero);

        await expectLater(
          () => parent.run('another parent run'),
          throwsA(isA<AgentSessionRunActiveException>()),
        );

        expect(await child.abort(), isTrue);
        await childCancellation;

        provider.completeNext(AgentResponse(text: 'parent done'));
        await parentRun;
      },
    );

    test('emits agent selection and delegation boundary events', () async {
      final runtime = AgentRuntime(
        provider: const LoopbackModel(),
        profiles: const <AgentProfile>[
          AgentProfile(id: 'primary'),
          AgentProfile(id: 'researcher', mode: AgentProfileMode.subagent),
        ],
        sessionIdGenerator: _IdSequence(<String>[
          'session-1',
          'session-2',
        ]).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final parent = await runtime.createSession(profileId: 'primary');
      final events = await parent
          .delegateStream('researcher', 'hello')
          .toList();

      expect(events.first, isA<AgentDelegationEvent>());
      expect(
        (events.first as AgentDelegationEvent).phase,
        AgentDelegationPhase.start,
      );
      expect(
        events.whereType<AgentRunStartEvent>().single.agentId,
        'researcher',
      );
      expect(events.last, isA<AgentDelegationEvent>());
      expect(
        (events.last as AgentDelegationEvent).phase,
        AgentDelegationPhase.complete,
      );
    });
  });
}

class _ToolCallingProvider implements AgentProvider {
  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    return AgentResponse(
      toolCalls: const <ToolCall>[ToolCall(id: 'clock-1', name: 'clock')],
    );
  }
}

class _ToolThenAnswerProvider implements AgentProvider {
  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    final last = turn.messages.last;
    if (last.role == AgentRole.tool) {
      return AgentResponse(text: 'The time is ${last.content}.');
    }

    return AgentResponse(
      toolCalls: const <ToolCall>[ToolCall(id: 'clock-1', name: 'clock')],
    );
  }
}

class _AskUserProvider implements AgentProvider {
  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    final last = turn.messages.last;
    if (last.role == AgentRole.tool) {
      return AgentResponse(text: 'Using ${last.content}.');
    }

    return AgentResponse(
      toolCalls: const <ToolCall>[
        ToolCall(
          id: 'ask-1',
          name: 'ask_user',
          input: <String, Object?>{
            'header': 'Need direction',
            'question': 'Which environment should I use?',
            'options': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'staging',
                'label': 'Staging',
                'description': 'Proceed with staging only',
              },
            ],
          },
        ),
      ],
    );
  }
}

class _ClockTool implements AgentTool {
  const _ClockTool();

  @override
  ToolDefinition get definition =>
      const ToolDefinition(name: 'clock', description: 'Returns the time.');

  @override
  Future<ToolOutput> execute(Map<String, Object?> input) async =>
      const ToolOutput.text('12:00');
}

class _CapturingProvider implements AgentProvider {
  String? lastSystemPrompt;
  int callCount = 0;

  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    callCount++;
    final systemMessages = turn.messages.where(
      (message) => message.role == AgentRole.system,
    );
    final system = systemMessages.isEmpty ? null : systemMessages.first;
    lastSystemPrompt = system?.content;
    return AgentResponse(text: turn.messages.last.content);
  }
}

class _RecordingSummarizer implements AgentSessionSummarizer {
  _RecordingSummarizer(this.summaryText);

  final String summaryText;

  @override
  Future<AgentSessionSummary> summarize(List<AgentMessage> messages) async {
    return AgentSessionSummary(text: summaryText);
  }
}

class _IdSequence {
  _IdSequence(this._ids);

  final List<String> _ids;
  var _index = 0;

  String next() => _ids[_index++];
}

class _RecordingRuntimeHook implements AgentRuntimeHook {
  final List<String> permissionSubjects = <String>[];
  final List<String> delegationPhases = <String>[];

  @override
  Future<void> onDelegation(AgentDelegationHookEvent event) async {
    delegationPhases.add(event.phase.name);
  }

  @override
  Future<void> onPermissionEvaluated(
    AgentPermissionDecision decision,
    ManagedAgentSession session,
  ) async {
    permissionSubjects.add(decision.subject);
  }
}

class _BlockingProvider implements AgentProvider {
  final List<Completer<AgentResponse>> _responses =
      <Completer<AgentResponse>>[];

  void completeNext(AgentResponse response) {
    if (_responses.isEmpty) {
      throw StateError('No pending response to complete.');
    }

    _responses.removeAt(0).complete(response);
  }

  @override
  Future<AgentResponse> respond(AgentTurn turn) {
    final completer = Completer<AgentResponse>();
    _responses.add(completer);
    return completer.future;
  }
}
