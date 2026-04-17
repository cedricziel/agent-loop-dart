import 'dart:async';
import 'dart:io';

import 'package:agent_loop/agent_loop.dart';
import 'package:test/test.dart';

void main() {
  group('AgentLoopSdk skills', () {
    test(
      'discovers skills from SKILL.md metadata and loads full instructions',
      () async {
        final workspace = await Directory.systemTemp.createTemp('sdk-skills');
        addTearDown(() => workspace.delete(recursive: true));
        final skillDir = Directory(
          '${workspace.path}/.agents/skills/code-review',
        );
        await skillDir.create(recursive: true);
        await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: code-review
description: Reviews code changes and calls out risks.
license: MIT
compatibility: local-only
metadata:
  author: test-suite
  version: "1.0"
---

Read the diff and report bugs first.
''');

        final discovered = await discoverAgentSkills(
          workingDirectory: workspace,
          homeDirectory: workspace,
        );
        final loaded = await loadAgentSkill(discovered.single);

        expect(discovered, hasLength(1));
        expect(discovered.single.name, 'code-review');
        expect(
          discovered.single.description,
          'Reviews code changes and calls out risks.',
        );
        expect(discovered.single.license, 'MIT');
        expect(discovered.single.compatibility, 'local-only');
        expect(discovered.single.metadata, <String, String>{
          'author': 'test-suite',
          'version': '1.0',
        });
        expect(loaded.instructions, 'Read the diff and report bugs first.');
        expect(loaded.rootUri, Uri.directory(skillDir.path));
      },
    );

    test('skips skill entries missing required metadata', () async {
      final workspace = await Directory.systemTemp.createTemp('sdk-skills');
      addTearDown(() => workspace.delete(recursive: true));
      final invalidDir = Directory('${workspace.path}/.agents/skills/invalid');
      await invalidDir.create(recursive: true);
      await File('${invalidDir.path}/SKILL.md').writeAsString('''
---
name: invalid
---

Missing description.
''');

      final skills = await discoverAgentSkills(
        workingDirectory: workspace,
        homeDirectory: workspace,
      );

      expect(skills, isEmpty);
    });

    test('discovers skills from known project and user locations', () async {
      final home = await Directory.systemTemp.createTemp('sdk-skill-home');
      final repo = await Directory.systemTemp.createTemp('sdk-skill-repo');
      addTearDown(() => home.delete(recursive: true));
      addTearDown(() => repo.delete(recursive: true));
      await Directory('${repo.path}/.git').create();
      final nested = Directory('${repo.path}/packages/app');
      await nested.create(recursive: true);

      await _writeSkill(
        Directory('${repo.path}/.agents/skills/project-standard'),
        name: 'project-standard',
      );
      await _writeSkill(
        Directory('${repo.path}/.claude/skills/project-claude'),
        name: 'project-claude',
      );
      await _writeSkill(
        Directory('${repo.path}/.opencode/skills/project-opencode'),
        name: 'project-opencode',
      );
      await _writeSkill(
        Directory('${home.path}/.agents/skills/user-standard'),
        name: 'user-standard',
      );
      await _writeSkill(
        Directory('${home.path}/.claude/skills/user-claude'),
        name: 'user-claude',
      );
      await _writeSkill(
        Directory('${home.path}/.config/opencode/skills/user-opencode'),
        name: 'user-opencode',
      );

      final skills = await discoverAgentSkills(
        workingDirectory: nested,
        homeDirectory: home,
      );

      expect(
        skills.map((skill) => skill.name),
        containsAll(<String>[
          'project-standard',
          'project-claude',
          'project-opencode',
          'user-standard',
          'user-claude',
          'user-opencode',
        ]),
      );
    });

    test('applies deterministic precedence for duplicate names', () async {
      final home = await Directory.systemTemp.createTemp('sdk-skill-home');
      final repo = await Directory.systemTemp.createTemp('sdk-skill-repo');
      addTearDown(() => home.delete(recursive: true));
      addTearDown(() => repo.delete(recursive: true));
      await Directory('${repo.path}/.git').create();
      final nested = Directory('${repo.path}/packages/app');
      await nested.create(recursive: true);

      await _writeSkill(
        Directory('${home.path}/.agents/skills/dup-skill'),
        name: 'dup-skill',
        description: 'User-level standard skill.',
      );
      await _writeSkill(
        Directory('${repo.path}/.claude/skills/dup-skill'),
        name: 'dup-skill',
        description: 'Project-level Claude skill.',
      );
      await _writeSkill(
        Directory('${repo.path}/.opencode/skills/dup-skill'),
        name: 'dup-skill',
        description: 'Project-level OpenCode skill.',
      );

      final skills = await discoverAgentSkills(
        workingDirectory: nested,
        homeDirectory: home,
      );
      final duplicate = skills.singleWhere(
        (skill) => skill.name == 'dup-skill',
      );

      expect(duplicate.description, 'Project-level Claude skill.');
      expect(
        duplicate.sourceUri.path,
        contains('/.claude/skills/dup-skill/SKILL.md'),
      );
    });
  });

  group('AgentLoopSdk managed sessions', () {
    test('applies reliability policy to managed session runs', () async {
      final sdk = AgentLoopSdk(
        provider: _RetrySequenceProvider(<Object>[
          AgentProviderException(
            provider: 'sdk-retry',
            cause: const SocketException('temporary outage'),
            stackTrace: StackTrace.empty,
            kind: AgentProviderFailureKind.network,
            isRetryable: true,
          ),
          AgentResponse(text: 'recovered'),
        ]),
        reliabilityPolicy: const AgentReliabilityPolicy(
          maxAttempts: 2,
          initialRetryDelay: Duration.zero,
        ),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await sdk.createSession();
      final events = await session.stream('hello').toList();

      expect(events.whereType<AgentProviderRetryEvent>(), hasLength(1));
      expect((events.last as AgentRunCompleteEvent).result.output, 'recovered');
    });

    test('creates, reloads, and branches managed sessions', () async {
      final sdk = AgentLoopSdk(
        model: const LoopbackModel(),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>[
          'session-1',
          'session-2',
        ]).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final session = await sdk.createSession();
      await session.run('hello');
      final reloaded = await sdk.loadSession('session-1');
      final branch = await reloaded.branch();

      expect(reloaded.id, 'session-1');
      expect(branch.id, 'session-2');
      expect(branch.parentId, 'session-1');
    });

    test('streams managed session events with session metadata', () async {
      final sdk = AgentLoopSdk(
        model: const LoopbackModel(),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await sdk.createSession();
      final events = await session.stream('hello').toList();

      expect(events.first, isA<AgentRunStartEvent>());
      expect(events.last, isA<AgentRunCompleteEvent>());
      expect(events.last.sessionId, 'session-1');
      expect(events.last.runId, 'run-1');
    });

    test(
      'aborts an active managed session run through the SDK surface',
      () async {
        final sdk = AgentLoopSdk(
          provider: _BlockingProvider(),
          store: InMemoryAgentSessionStore(),
          sessionIdGenerator: _IdSequence(<String>['session-1']).next,
          runIdGenerator: _IdSequence(<String>['run-1']).next,
        );

        final session = await sdk.createSession();
        final inFlight = session.run('hello');
        final cancellation = expectLater(
          inFlight,
          throwsA(isA<AgentRunCancelledException>()),
        );

        await Future<void>.delayed(Duration.zero);

        expect(await session.abort(), isTrue);
        await cancellation;
      },
    );

    test('compacts a managed session through the SDK surface', () async {
      final sdk = AgentLoopSdk(
        provider: _SummaryAwareProvider(),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2', 'run-3']).next,
      );

      final session = await sdk.createSession();
      await session.run('alpha');
      await session.run('beta');

      final compacted = await session.compact(
        retainLastMessages: 2,
        summarizer: _RecordingSummarizer('summary of alpha'),
      );

      expect(compacted.summary.text, 'summary of alpha');
      expect(session.compaction, isNotNull);
      expect(session.transcript.map((message) => message.content), <String>[
        'beta',
        'beta',
      ]);
    });

    test('creates a session with automatic compaction policy', () async {
      final sdk = AgentLoopSdk(
        model: const LoopbackModel(),
        store: InMemoryAgentSessionStore(),
      );

      final session = await sdk.createSession(
        automaticCompactionPolicy: const AgentAutoCompactionPolicy(
          maxTranscriptMessages: 3,
          retainLastMessages: 2,
          summarizerId: 'default',
        ),
      );

      expect(session.autoCompactionPolicy, isNotNull);
      expect(session.autoCompactionPolicy!.summarizerId, 'default');
    });

    test('emits automatic compaction lifecycle reporting', () async {
      final sdk = AgentLoopSdk(
        model: const LoopbackModel(),
        store: InMemoryAgentSessionStore(),
        automaticCompactionSummarizers: <String, AgentSessionSummarizer>{
          'default': _RecordingSummarizer('auto summary'),
        },
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final session = await sdk.createSession(
        automaticCompactionPolicy: const AgentAutoCompactionPolicy(
          maxTranscriptMessages: 3,
          retainLastMessages: 2,
          summarizerId: 'default',
        ),
      );

      await session.stream('hello').drain<void>();
      final events = await session.stream('follow up').toList();

      expect(events.whereType<AgentAutoCompactionEvent>(), hasLength(1));
      expect(session.compaction, isNotNull);
      expect(session.compaction!.summary.text, 'auto summary');
    });
  });

  group('AgentLoopSdk agent runtime', () {
    test('enables the builtin tool pack through the SDK constructor', () async {
      final workspace = await Directory.systemTemp.createTemp(
        'sdk-builtin-tools',
      );
      addTearDown(() => workspace.delete(recursive: true));
      final file = File('${workspace.path}/notes.txt');
      await file.writeAsString('hello\nworld\n');

      final sdk = AgentLoopSdk(
        provider: _ReadFileProvider(),
        builtinToolOptions: BuiltinToolOptions(workspaceRoot: workspace),
      );

      final result = await sdk.run(prompt: 'read the file');

      expect(result.output, contains('status: success'));
      expect(result.output, contains('path: notes.txt'));
      expect(result.output, contains('1: hello'));
    });

    test('exposes configured agent profiles and subagent delegation', () async {
      final sdk = AgentLoopSdk(
        model: const LoopbackModel(),
        profiles: const <AgentProfile>[
          AgentProfile(id: 'primary'),
          AgentProfile(id: 'researcher', mode: AgentProfileMode.subagent),
        ],
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>[
          'session-1',
          'session-2',
        ]).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final session = await sdk.createSession(profileId: 'primary');
      final child = await session.delegate('researcher', 'hello');

      expect(sdk.visibleProfiles.map((profile) => profile.id), <String>[
        'primary',
        'researcher',
      ]);
      expect(child.parentId, 'session-1');
      expect(child.delegatingAgentId, 'primary');
    });

    test(
      'surfaces permission-aware subagent invocation through the SDK',
      () async {
        final sdk = AgentLoopSdk(
          model: const LoopbackModel(),
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
          store: InMemoryAgentSessionStore(),
        );

        final session = await sdk.createSession(profileId: 'primary');

        await expectLater(
          session.delegate('researcher', 'hello'),
          throwsA(isA<AgentPermissionDeniedException>()),
        );
      },
    );

    test(
      'exposes pending approval inspection and approval resolution',
      () async {
        final sdk = AgentLoopSdk(
          provider: _ToolThenAnswerProvider(),
          tools: <AgentTool>[const _ClockTool()],
          profiles: const <AgentProfile>[
            AgentProfile(
              id: 'primary',
              permissionPolicy: DeclarativeAgentPermissionPolicy(
                toolPermissions: <String, AgentPermissionOutcome>{
                  'clock': AgentPermissionOutcome.ask,
                },
              ),
            ),
          ],
          store: InMemoryAgentSessionStore(),
          sessionIdGenerator: _IdSequence(<String>['session-1']).next,
          runIdGenerator: _IdSequence(<String>['run-1']).next,
        );

        final session = await sdk.createSession(profileId: 'primary');
        final pausedEvents = await session.stream('what time is it?').toList();
        final result = await session.approvePending();

        expect(pausedEvents.last, isA<AgentApprovalRequiredEvent>());
        expect(session.pendingApproval, isNull);
        expect(result.output, 'The time is 12:00.');
      },
    );
  });
}

Future<void> _writeSkill(
  Directory directory, {
  required String name,
  String? description,
}) async {
  await directory.create(recursive: true);
  await File('${directory.path}/SKILL.md').writeAsString('''
---
name: $name
description: ${description ?? 'Description for $name.'}
---

Instructions for $name.
''');
}

class _IdSequence {
  _IdSequence(this._ids);

  final List<String> _ids;
  var _index = 0;

  String next() => _ids[_index++];
}

class _BlockingProvider implements AgentProvider {
  final Completer<AgentResponse> _response = Completer<AgentResponse>();

  @override
  Future<AgentResponse> respond(AgentTurn turn) => _response.future;
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

class _ReadFileProvider implements AgentProvider {
  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    final last = turn.messages.last;
    if (last.role == AgentRole.tool) {
      return AgentResponse(text: last.content);
    }

    return AgentResponse(
      toolCalls: const <ToolCall>[
        ToolCall(
          id: 'read-1',
          name: 'read',
          input: <String, Object?>{'path': 'notes.txt'},
        ),
      ],
    );
  }
}

class _RetrySequenceProvider implements AgentProvider {
  _RetrySequenceProvider(this._results);

  final List<Object> _results;
  var _index = 0;

  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    final current = _results[_index++];
    if (current is AgentResponse) {
      return current;
    }
    throw current as AgentProviderException;
  }
}

class _RecordingSummarizer implements AgentSessionSummarizer {
  _RecordingSummarizer(this._summary);

  final String _summary;

  @override
  Future<AgentSessionSummary> summarize(List<AgentMessage> messages) async {
    return AgentSessionSummary(text: _summary);
  }
}

class _SummaryAwareProvider implements AgentProvider {
  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    final latestUserMessage = turn.messages.lastWhere(
      (message) => message.role == AgentRole.user,
    );
    final summaries = turn.messages
        .where((message) => message.role == AgentRole.system)
        .map((message) => message.content)
        .where((message) => message.startsWith('Session summary: '))
        .toList(growable: false);
    if (summaries.isEmpty) {
      return AgentResponse(text: latestUserMessage.content);
    }

    return AgentResponse(text: latestUserMessage.content);
  }
}
