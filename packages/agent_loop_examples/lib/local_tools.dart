import 'dart:convert';
import 'dart:io';

import 'package:agent_loop/agent_loop.dart';

class ClockTool implements AgentTool {
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_time',
    description: 'Returns the current local timestamp as an ISO-8601 string.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
    },
  );

  @override
  Future<String> execute(Map<String, Object?> input) async {
    return DateTime.now().toIso8601String();
  }
}

class WorkingDirectoryTool implements AgentTool {
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_working_directory',
    description: 'Returns the current working directory for this local run.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
    },
  );

  @override
  Future<String> execute(Map<String, Object?> input) async {
    return Directory.current.path;
  }
}

class ListFilesTool implements AgentTool {
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'list_files',
    description:
        'Lists files and directories in a relative directory from the current working directory. Defaults to .',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'path': <String, Object?>{
          'type': 'string',
          'description': 'Relative directory path to inspect. Defaults to .',
        },
      },
    },
  );

  @override
  Future<String> execute(Map<String, Object?> input) async {
    final relativePath = (input['path'] as String?)?.trim();
    final directory = Directory(
      relativePath == null || relativePath.isEmpty ? '.' : relativePath,
    );

    if (!await directory.exists()) {
      return 'Directory not found: ${directory.path}';
    }

    final entries = await directory.list().toList();
    entries.sort((a, b) => a.path.compareTo(b.path));
    final formatted = entries
        .map((entry) {
          final type = switch (entry) {
            Directory() => 'dir',
            File() => 'file',
            Link() => 'link',
            _ => 'other',
          };
          return '$type ${entry.path}';
        })
        .toList(growable: false);

    return formatted.isEmpty ? '(empty)' : formatted.join('\n');
  }
}

class ReadFileTool implements AgentTool {
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'read_file',
    description:
        'Reads a UTF-8 text file relative to the current working directory and returns its contents.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'path': <String, Object?>{
          'type': 'string',
          'description': 'Relative file path to read.',
        },
      },
      'required': <String>['path'],
    },
  );

  @override
  Future<String> execute(Map<String, Object?> input) async {
    final path = (input['path'] as String?)?.trim();
    if (path == null || path.isEmpty) {
      return 'Missing required input: path';
    }

    final file = File(path);
    if (!await file.exists()) {
      return 'File not found: ${file.path}';
    }

    try {
      return await file.readAsString(encoding: utf8);
    } on FileSystemException catch (error) {
      return 'Failed to read file: $error';
    }
  }
}

List<AgentTool> createLocalTools() => <AgentTool>[
  ClockTool(),
  WorkingDirectoryTool(),
  ListFilesTool(),
  ReadFileTool(),
];
