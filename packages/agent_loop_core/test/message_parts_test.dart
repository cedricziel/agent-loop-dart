import 'package:agent_loop_core/agent_loop_core.dart';
import 'package:test/test.dart';

void main() {
  group('AgentMessage parts', () {
    test(
      'stores ordered typed parts and derives text compatibility content',
      () {
        final message = AgentMessage(
          role: AgentRole.assistant,
          parts: <MessagePart>[
            const TextPart(text: 'Hello'),
            const ReasoningPart(text: 'Need to inspect generated output.'),
            const FilePart(path: 'build/report.txt', mimeType: 'text/plain'),
            const TextPart(text: ' world'),
          ],
        );

        expect(message.parts, hasLength(4));
        expect(
          message.parts.whereType<TextPart>().map((part) => part.text),
          <String>['Hello', ' world'],
        );
        expect(message.content, 'Hello world');
      },
    );

    test('preserves text-only callers as text parts', () {
      final message = AgentMessage(role: AgentRole.user, content: 'plain text');

      expect(message.parts, <Matcher>[isA<TextPart>()]);
      expect(message.content, 'plain text');
    });
  });
}
