import 'dart:async';

import 'package:agent_loop/agent_loop.dart';
import 'package:test/test.dart';

void main() {
  group('AgentLoopSdk managed sessions', () {
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
  });
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
