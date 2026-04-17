import 'package:agent_loop_core/agent_loop_core.dart';
import 'package:test/test.dart';

void main() {
  group('AgentSkill', () {
    test('exposes discovered skill metadata as public fields', () {
      final skill = AgentSkill(
        name: 'code-review',
        description: 'Reviews code changes and calls out risks.',
        sourceUri: Uri.file('/tmp/.agents/skills/code-review/SKILL.md'),
      );

      expect(skill.name, 'code-review');
      expect(skill.description, 'Reviews code changes and calls out risks.');
      expect(skill.sourceUri.path, '/tmp/.agents/skills/code-review/SKILL.md');
    });
  });

  group('LoadedAgentSkill', () {
    test(
      'extends discovered metadata with instructions and root directory',
      () {
        final skill = LoadedAgentSkill(
          name: 'code-review',
          description: 'Reviews code changes and calls out risks.',
          sourceUri: Uri.file('/tmp/.agents/skills/code-review/SKILL.md'),
          rootUri: Uri.file('/tmp/.agents/skills/code-review/'),
          instructions: 'Read the diff and report bugs first.',
        );

        expect(skill.name, 'code-review');
        expect(skill.rootUri.path, '/tmp/.agents/skills/code-review/');
        expect(skill.instructions, 'Read the diff and report bugs first.');
      },
    );
  });
}
