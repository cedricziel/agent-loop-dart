import 'package:agent_loop/agent_loop.dart';
import 'package:agent_loop_cli/src/run_cli.dart';
import 'package:test/test.dart';

void main() {
  group('createDemoSdk', () {
    test('configures named demo agents', () {
      final sdk = createDemoSdk();

      expect(sdk.visibleProfiles.map((profile) => profile.id), <String>[
        'primary',
        'researcher',
      ]);
    });
  });

  group('createManagedDemoSession', () {
    test(
      'creates and reloads a managed session through the SDK surface',
      () async {
        final sdk = AgentLoopSdk(
          model: const LoopbackModel(),
          store: InMemoryAgentSessionStore(),
          sessionIdGenerator: () => 'session-1',
          runIdGenerator: () => 'run-1',
        );

        final session = await createManagedDemoSession(sdk);

        expect(session.id, 'session-1');
        expect(session.transcript, isEmpty);
      },
    );
  });

  group('formatPartForLog', () {
    test('renders reasoning, file, and tool parts for stderr logs', () {
      expect(
        formatPartForLog(
          const ReasoningPart(text: 'Need the bash tool first.'),
        ),
        'assistant:reasoning Need the bash tool first.',
      );
      expect(
        formatPartForLog(
          const FilePart(path: 'build/report.txt', mimeType: 'text/plain'),
        ),
        'assistant:file build/report.txt (text/plain)',
      );
      expect(
        formatPartForLog(
          const ToolPart(
            callId: 'bash-1',
            name: 'bash',
            state: ToolPartState.pending,
          ),
        ),
        'tool:pending bash',
      );
      expect(
        formatPartForLog(
          const ToolPart(
            callId: 'bash-1',
            name: 'bash',
            state: ToolPartState.completed,
            output: 'status: success',
          ),
        ),
        'tool:completed bash => status: success',
      );
    });

    test('keeps text parts on stdout and ignores unsupported parts', () {
      expect(formatPartForLog(const TextPart(text: 'hello')), isNull);
    });
  });
}
