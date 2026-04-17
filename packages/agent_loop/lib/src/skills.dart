import 'dart:io';

import 'package:agent_loop_core/agent_loop_core.dart';

Future<List<AgentSkill>> discoverAgentSkills({
  Directory? workingDirectory,
  Directory? homeDirectory,
}) async {
  final cwd = workingDirectory ?? Directory.current;
  final home = homeDirectory ?? _defaultHomeDirectory();
  final discovered = <String, AgentSkill>{};

  for (final directory in _projectSearchDirectories(cwd)) {
    await _collectSkillsFromDirectory(
      directory,
      discovered,
      locations: const <String>[
        '.agents/skills',
        '.claude/skills',
        '.opencode/skills',
      ],
    );
  }

  await _collectSkillsFromDirectory(
    home,
    discovered,
    locations: const <String>[
      '.agents/skills',
      '.claude/skills',
      '.config/opencode/skills',
    ],
  );

  return discovered.values.toList(growable: false);
}

Future<LoadedAgentSkill> loadAgentSkill(AgentSkill skill) async {
  final parsed = await _parseSkillFile(File.fromUri(skill.sourceUri));
  if (parsed == null) {
    throw StateError(
      'Skill at `${skill.sourceUri}` no longer has valid metadata.',
    );
  }

  return LoadedAgentSkill(
    name: parsed.name,
    description: parsed.description,
    sourceUri: skill.sourceUri,
    rootUri: Uri.directory(File.fromUri(skill.sourceUri).parent.path),
    instructions: parsed.instructions,
    license: parsed.license,
    compatibility: parsed.compatibility,
    metadata: parsed.metadata,
  );
}

Future<void> _collectSkillsFromDirectory(
  Directory root,
  Map<String, AgentSkill> discovered, {
  required List<String> locations,
}) async {
  for (final relativeLocation in locations) {
    final skillsRoot = Directory('${root.path}/$relativeLocation');
    if (!await skillsRoot.exists()) {
      continue;
    }

    await for (final entity in skillsRoot.list()) {
      if (entity is! Directory) {
        continue;
      }

      final skillFile = File('${entity.path}/SKILL.md');
      if (!await skillFile.exists()) {
        continue;
      }

      final parsed = await _parseSkillFile(skillFile);
      if (parsed == null) {
        continue;
      }

      discovered.putIfAbsent(
        parsed.name,
        () => AgentSkill(
          name: parsed.name,
          description: parsed.description,
          sourceUri: Uri.file(skillFile.path),
          license: parsed.license,
          compatibility: parsed.compatibility,
          metadata: parsed.metadata,
        ),
      );
    }
  }
}

List<Directory> _projectSearchDirectories(Directory start) {
  final directories = <Directory>[];
  Directory? gitRoot;
  var current = start.absolute;

  while (true) {
    directories.add(current);
    final gitDirectory = Directory('${current.path}/.git');
    final gitFile = File('${current.path}/.git');
    if (gitDirectory.existsSync() || gitFile.existsSync()) {
      gitRoot = current;
      break;
    }

    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }

  if (gitRoot != null) {
    return directories;
  }

  return <Directory>[start.absolute];
}

Directory _defaultHomeDirectory() {
  final environment = Platform.environment;
  final homePath = environment['HOME'] ?? environment['USERPROFILE'];
  if (homePath == null || homePath.isEmpty) {
    throw StateError('Could not determine the user home directory.');
  }
  return Directory(homePath);
}

Future<_ParsedSkillFile?> _parseSkillFile(File file) async {
  final contents = await file.readAsString();
  final normalized = contents.replaceAll('\r\n', '\n');
  if (!normalized.startsWith('---\n')) {
    return null;
  }

  final closingIndex = normalized.indexOf('\n---\n', 4);
  if (closingIndex == -1) {
    return null;
  }

  final frontmatter = normalized.substring(4, closingIndex).split('\n');
  final body = normalized.substring(closingIndex + 5).trim();
  final values = <String, String>{};
  final metadata = <String, String>{};
  String? nestedKey;

  for (final rawLine in frontmatter) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) {
      continue;
    }

    final isIndented = rawLine.startsWith('  ') || rawLine.startsWith('\t');
    if (isIndented && nestedKey == 'metadata') {
      final separator = line.indexOf(':');
      if (separator <= 0) {
        continue;
      }
      final key = line.substring(0, separator).trim();
      final value = _stripQuotes(line.substring(separator + 1).trim());
      if (key.isNotEmpty && value.isNotEmpty) {
        metadata[key] = value;
      }
      continue;
    }

    nestedKey = null;
    final separator = line.indexOf(':');
    if (separator <= 0) {
      continue;
    }
    final key = line.substring(0, separator).trim();
    final value = line.substring(separator + 1).trim();
    if (value.isEmpty) {
      nestedKey = key;
      continue;
    }
    values[key] = _stripQuotes(value);
  }

  final name = values['name'];
  final description = values['description'];
  if (name == null ||
      name.isEmpty ||
      description == null ||
      description.isEmpty) {
    return null;
  }

  return _ParsedSkillFile(
    name: name,
    description: description,
    instructions: body,
    license: values['license'],
    compatibility: values['compatibility'],
    metadata: metadata,
  );
}

String _stripQuotes(String value) {
  if (value.length >= 2) {
    final first = value[0];
    final last = value[value.length - 1];
    if ((first == '"' && last == '"') || (first == '\'' && last == '\'')) {
      return value.substring(1, value.length - 1);
    }
  }
  return value;
}

class _ParsedSkillFile {
  const _ParsedSkillFile({
    required this.name,
    required this.description,
    required this.instructions,
    required this.metadata,
    this.license,
    this.compatibility,
  });

  final String name;
  final String description;
  final String instructions;
  final String? license;
  final String? compatibility;
  final Map<String, String> metadata;
}
