import 'dart:async';

import 'package:agent_loop_core/agent_loop_core.dart';
import 'package:test/test.dart';

void main() {
  group('AgentSessionManager', () {
    test('creates and reloads a managed session through the store', () async {
      final manager = AgentSessionManager(
        loop: AgentLoop(provider: const LoopbackModel()),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await manager.createSession();

      expect(session.id, 'session-1');
      expect(session.parentId, isNull);
      expect(session.transcript, isEmpty);

      final result = await session.run('hello');
      final reloaded = await manager.loadSession('session-1');

      expect(result.output, 'hello');
      expect(reloaded.id, session.id);
      expect(reloaded.transcript.map((message) => message.content), <String>[
        'hello',
        'hello',
      ]);
    });

    test(
      'branches by copying transcript without mutating the source',
      () async {
        final ids = _IdSequence(<String>['session-1', 'session-2', 'run-1']);
        final manager = AgentSessionManager(
          loop: AgentLoop(provider: const LoopbackModel()),
          store: InMemoryAgentSessionStore(),
          sessionIdGenerator: ids.next,
          runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
        );

        final source = await manager.createSession();
        await source.run('hello');

        final branch = await source.branch();
        final branchResult = await branch.run('follow up');

        expect(branch.id, 'session-2');
        expect(branch.parentId, 'session-1');
        expect(source.transcript.map((message) => message.content), <String>[
          'hello',
          'hello',
        ]);
        expect(
          branchResult.transcript.map((message) => message.content),
          <String>['hello', 'hello', 'follow up', 'follow up'],
        );
      },
    );

    test('resumes by prompting the managed session handle directly', () async {
      final manager = AgentSessionManager(
        loop: AgentLoop(provider: const LoopbackModel()),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final session = await manager.createSession();
      await session.run('hello');

      final resumed = await session.run('follow up');

      expect(resumed.output, 'follow up');
      expect(session.transcript.map((message) => message.content), <String>[
        'hello',
        'hello',
        'follow up',
        'follow up',
      ]);
    });

    test('reports whether a managed session can be compacted', () async {
      final manager = AgentSessionManager(
        loop: AgentLoop(provider: const LoopbackModel()),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final session = await manager.createSession();
      await session.run('hello');

      expect(session.canCompact(retainLastMessages: 2), isFalse);
      expect(session.canCompact(retainLastMessages: 1), isTrue);
    });

    test('rejects compaction that would consume the retained suffix', () async {
      final manager = AgentSessionManager(
        loop: AgentLoop(provider: const LoopbackModel()),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await manager.createSession();
      await session.run('hello');

      await expectLater(
        session.compact(
          retainLastMessages: 2,
          summarizer: _RecordingSummarizer('summary'),
        ),
        throwsA(isA<AgentSessionCompactionException>()),
      );
    });

    test(
      'compacts a session and resumes from the summary-backed context',
      () async {
        final provider = _SummaryAwareProvider();
        final manager = AgentSessionManager(
          loop: AgentLoop(provider: provider),
          store: InMemoryAgentSessionStore(),
          sessionIdGenerator: _IdSequence(<String>['session-1']).next,
          runIdGenerator: _IdSequence(<String>['run-1', 'run-2', 'run-3']).next,
        );

        final session = await manager.createSession();
        await session.run('alpha');
        await session.run('beta');

        final summarizer = _RecordingSummarizer('summary of alpha');
        final compacted = await session.compact(
          retainLastMessages: 2,
          summarizer: summarizer,
        );
        final resumed = await session.run('gamma');

        expect(summarizer.calls, hasLength(1));
        expect(compacted.summary.text, 'summary of alpha');
        expect(session.compaction?.summary.text, 'summary of alpha');
        expect(session.transcript.map((message) => message.content), <String>[
          'beta',
          'beta',
          'gamma',
          'resumed: summary of alpha | beta | beta | gamma',
        ]);
        expect(
          resumed.output,
          'resumed: summary of alpha | beta | beta | gamma',
        );
        expect(
          provider.lastMessages.map((message) => message.content),
          <String>[
            'Session summary: summary of alpha',
            'beta',
            'beta',
            'gamma',
          ],
        );
      },
    );

    test('persists and reloads compacted session state', () async {
      final store = InMemoryAgentSessionStore();
      final manager = AgentSessionManager(
        loop: AgentLoop(provider: const LoopbackModel()),
        store: store,
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final session = await manager.createSession();
      await session.run('hello');
      await session.run('follow up');
      await session.compact(
        retainLastMessages: 2,
        summarizer: _RecordingSummarizer('summary'),
      );

      final reloaded = await manager.loadSession('session-1');

      expect(reloaded.compaction, isNotNull);
      expect(reloaded.compaction!.summary.text, 'summary');
      expect(reloaded.transcript.map((message) => message.content), <String>[
        'follow up',
        'follow up',
      ]);
    });

    test('branches by copying compaction metadata', () async {
      final manager = AgentSessionManager(
        loop: AgentLoop(provider: const LoopbackModel()),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>[
          'session-1',
          'session-2',
        ]).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final source = await manager.createSession();
      await source.run('hello');
      await source.run('follow up');
      await source.compact(
        retainLastMessages: 2,
        summarizer: _RecordingSummarizer('summary'),
      );

      final branch = await source.branch();

      expect(branch.compaction, isNotNull);
      expect(branch.compaction!.summary.text, 'summary');
      expect(branch.transcript.map((message) => message.content), <String>[
        'follow up',
        'follow up',
      ]);
    });

    test('rejects a second active run for the same managed session', () async {
      final provider = _BlockingProvider();
      final manager = AgentSessionManager(
        loop: AgentLoop(provider: provider),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1', 'run-2']).next,
      );

      final session = await manager.createSession();
      final inFlight = session.run('hello');

      await Future<void>.delayed(Duration.zero);

      await expectLater(
        () => session.run('follow up'),
        throwsA(isA<AgentSessionRunActiveException>()),
      );

      provider.complete(AgentResponse(text: 'done'));
      await inFlight;
    });

    test('aborts an active run and reports false when idle', () async {
      final provider = _BlockingProvider();
      final manager = AgentSessionManager(
        loop: AgentLoop(provider: provider),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await manager.createSession();
      final inFlight = session.run('hello');
      final cancellation = expectLater(
        inFlight,
        throwsA(isA<AgentRunCancelledException>()),
      );

      await Future<void>.delayed(Duration.zero);

      expect(await session.abort(), isTrue);
      await cancellation;
      expect(await session.abort(), isFalse);
    });

    test('emits run metadata on managed session lifecycle events', () async {
      final manager = AgentSessionManager(
        loop: AgentLoop(provider: const LoopbackModel()),
        store: InMemoryAgentSessionStore(),
        sessionIdGenerator: _IdSequence(<String>['session-1']).next,
        runIdGenerator: _IdSequence(<String>['run-1']).next,
      );

      final session = await manager.createSession();
      final events = await session.stream('hello').toList();

      expect(events.first, isA<AgentRunStartEvent>());
      expect(events.last, isA<AgentRunCompleteEvent>());
      expect(events.map((event) => event.sessionId).toSet(), <String?>{
        'session-1',
      });
      expect(events.map((event) => event.runId).toSet(), <String?>{'run-1'});
    });

    test(
      'emits a terminal cancellation event for a managed session stream',
      () async {
        final provider = _BlockingProvider();
        final manager = AgentSessionManager(
          loop: AgentLoop(provider: provider),
          store: InMemoryAgentSessionStore(),
          sessionIdGenerator: _IdSequence(<String>['session-1']).next,
          runIdGenerator: _IdSequence(<String>['run-1']).next,
        );

        final session = await manager.createSession();
        final eventsFuture = session.stream('hello').toList();

        await Future<void>.delayed(Duration.zero);
        expect(await session.abort(), isTrue);

        final events = await eventsFuture;

        expect(events.first, isA<AgentRunStartEvent>());
        expect(events.last, isA<AgentRunCancelledEvent>());
        expect(events.last.sessionId, 'session-1');
        expect(events.last.runId, 'run-1');
      },
    );
  });
}

class _RecordingSummarizer implements AgentSessionSummarizer {
  _RecordingSummarizer(this._summary);

  final String _summary;
  final List<List<AgentMessage>> calls = <List<AgentMessage>>[];

  @override
  Future<AgentSessionSummary> summarize(List<AgentMessage> messages) async {
    calls.add(List<AgentMessage>.unmodifiable(messages));
    return AgentSessionSummary(text: _summary);
  }
}

class _SummaryAwareProvider implements AgentProvider {
  List<AgentMessage> lastMessages = const <AgentMessage>[];

  @override
  Future<AgentResponse> respond(AgentTurn turn) async {
    lastMessages = turn.messages;
    final latestUserMessage = turn.messages.lastWhere(
      (message) => message.role == AgentRole.user,
    );
    final summaries = turn.messages
        .where((message) => message.role == AgentRole.system)
        .map((message) => message.content)
        .where((message) => message.startsWith('Session summary: '))
        .map((message) => message.substring('Session summary: '.length))
        .toList(growable: false);
    if (summaries.isEmpty) {
      return AgentResponse(text: latestUserMessage.content);
    }

    final rawContext = turn.messages
        .where((message) => message.role != AgentRole.system)
        .map((message) => message.content)
        .join(' | ');
    return AgentResponse(
      text: 'resumed: ${summaries.join(', ')} | $rawContext',
    );
  }
}

class _IdSequence {
  _IdSequence(this._ids);

  final List<String> _ids;
  var _index = 0;

  String next() => _ids[_index++];
}

class _BlockingProvider implements AgentProvider {
  final Completer<AgentResponse> _response = Completer<AgentResponse>();

  void complete(AgentResponse response) {
    if (!_response.isCompleted) {
      _response.complete(response);
    }
  }

  @override
  Future<AgentResponse> respond(AgentTurn turn) => _response.future;
}
