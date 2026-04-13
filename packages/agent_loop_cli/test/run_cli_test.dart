import 'package:agent_loop/agent_loop.dart';
import 'package:agent_loop_cli/src/run_cli.dart';
import 'package:test/test.dart';

void main() {
  group('formatPartForLog', () {
    test('renders reasoning, file, and tool parts for stderr logs', () {
      expect(
        formatPartForLog(
          const ReasoningPart(text: 'Need the clock tool first.'),
        ),
        'assistant:reasoning Need the clock tool first.',
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
            callId: 'clock-1',
            name: 'clock',
            state: ToolPartState.pending,
          ),
        ),
        'tool:pending clock',
      );
      expect(
        formatPartForLog(
          const ToolPart(
            callId: 'clock-1',
            name: 'clock',
            state: ToolPartState.completed,
            output: '2026-04-13T12:00:00Z',
          ),
        ),
        'tool:completed clock => 2026-04-13T12:00:00Z',
      );
    });

    test('keeps text parts on stdout and ignores unsupported parts', () {
      expect(formatPartForLog(const TextPart(text: 'hello')), isNull);
    });
  });
}
