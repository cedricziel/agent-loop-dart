import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'agent_tool.dart';

typedef BuiltinHttpClientFactory = HttpClient Function();

class BuiltinToolOptions {
  BuiltinToolOptions({
    required this.workspaceRoot,
    String? shellWorkingDirectory,
    this.bashTimeout = const Duration(seconds: 30),
    this.webfetchTimeout = const Duration(seconds: 30),
    this.readLineLimit = 200,
    this.globMatchLimit = 200,
    this.searchMatchLimit = 200,
    this.webfetchCharacterLimit = 12000,
    BuiltinHttpClientFactory? httpClientFactory,
  }) : assert(readLineLimit > 0, 'readLineLimit must be greater than zero.'),
       assert(globMatchLimit > 0, 'globMatchLimit must be greater than zero.'),
       assert(
         searchMatchLimit > 0,
         'searchMatchLimit must be greater than zero.',
       ),
       assert(
         webfetchCharacterLimit > 0,
         'webfetchCharacterLimit must be greater than zero.',
       ),
       shellWorkingDirectory = shellWorkingDirectory ?? '.',
       httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Directory workspaceRoot;
  final String shellWorkingDirectory;
  final Duration bashTimeout;
  final Duration webfetchTimeout;
  final int readLineLimit;
  final int globMatchLimit;
  final int searchMatchLimit;
  final int webfetchCharacterLimit;
  final BuiltinHttpClientFactory httpClientFactory;
}

List<AgentTool> createBuiltinTools(BuiltinToolOptions options) {
  final runtime = _BuiltinRuntime(options);
  return <AgentTool>[
    _ReadTool(runtime),
    _GlobTool(runtime),
    _SearchTool(runtime),
    _EditTool(runtime),
    _ApplyPatchTool(runtime),
    _BashTool(runtime),
    _WebfetchTool(runtime),
  ];
}

class _BuiltinRuntime {
  _BuiltinRuntime(this.options)
    : workspaceRoot = Directory(options.workspaceRoot.path).absolute,
      _rootUri = Uri.directory(
        Directory(options.workspaceRoot.path).absolute.path,
        windows: Platform.isWindows,
      ),
      _lexicalWorkspaceRoot = Directory(
        options.workspaceRoot.path,
      ).absolute.path.replaceAll('\\', '/');

  final BuiltinToolOptions options;
  final Directory workspaceRoot;
  final Uri _rootUri;
  final String _lexicalWorkspaceRoot;

  String get _canonicalWorkspaceRoot =>
      workspaceRoot.resolveSymbolicLinksSync().replaceAll('\\', '/');

  _ResolvedPath resolvePath(String requestedPath) {
    final trimmed = requestedPath.trim();
    if (trimmed.isEmpty) {
      throw const _BuiltinToolException(
        code: 'invalid_path',
        message: 'Path must not be empty.',
      );
    }

    final lexicalPath = File(
      _rootUri.resolve(trimmed).toFilePath(),
    ).absolute.path;
    final normalizedLexical = lexicalPath.replaceAll('\\', '/');
    if (!_isWithinWorkspace(normalizedLexical, root: _lexicalWorkspaceRoot)) {
      throw _workspaceBoundaryError(trimmed);
    }

    final entity = FileSystemEntity.typeSync(lexicalPath, followLinks: false);
    if (entity != FileSystemEntityType.notFound) {
      final canonical = switch (entity) {
        FileSystemEntityType.directory => Directory(
          lexicalPath,
        ).resolveSymbolicLinksSync(),
        _ => File(lexicalPath).resolveSymbolicLinksSync(),
      }.replaceAll('\\', '/');
      if (!_isWithinWorkspace(canonical, root: _canonicalWorkspaceRoot)) {
        throw _workspaceBoundaryError(trimmed);
      }
    }

    return _ResolvedPath(
      requestedPath: trimmed,
      absolutePath: lexicalPath,
      relativePath: _relativePath(normalizedLexical),
    );
  }

  _ResolvedPath resolveWorkingDirectory(String? requestedPath) {
    return resolvePath(
      requestedPath?.trim().isNotEmpty == true
          ? requestedPath!
          : options.shellWorkingDirectory,
    );
  }

  bool _isWithinWorkspace(String candidatePath, {required String root}) {
    final candidate = candidatePath.replaceAll('\\', '/');
    return candidate == root || candidate.startsWith('$root/');
  }

  String _relativePath(String absolutePath) {
    final candidate = absolutePath.replaceAll('\\', '/');
    for (final root in <String>[
      _lexicalWorkspaceRoot,
      _canonicalWorkspaceRoot,
    ]) {
      if (candidate == root) {
        return '.';
      }
      if (candidate.startsWith('$root/')) {
        return candidate.substring(root.length + 1);
      }
    }
    return candidate;
  }

  _BuiltinToolException _workspaceBoundaryError(String requestedPath) {
    return _BuiltinToolException(
      code: 'workspace_boundary',
      message:
          'Path `$requestedPath` resolves outside the configured workspace root.',
    );
  }
}

class _ResolvedPath {
  const _ResolvedPath({
    required this.requestedPath,
    required this.absolutePath,
    required this.relativePath,
  });

  final String requestedPath;
  final String absolutePath;
  final String relativePath;
}

class _BuiltinToolException implements Exception {
  const _BuiltinToolException({required this.code, required this.message});

  final String code;
  final String message;
}

class _BuiltinToolResult {
  const _BuiltinToolResult({
    required this.status,
    required this.metadata,
    this.sections = const <String, String>{},
  });

  final String status;
  final Map<String, Object?> metadata;
  final Map<String, String> sections;

  ToolOutput toToolOutput() {
    return ToolOutput(
      text: _renderText(),
      metadata: <String, Object?>{'status': status, ...metadata},
    );
  }

  String _renderText() {
    final lines = <String>['status: $status'];
    final keys = metadata.keys.toList()..sort();
    for (final key in keys) {
      final value = metadata[key];
      if (value != null) {
        lines.add('$key: $value');
      }
    }
    final sectionKeys = sections.keys.toList()..sort();
    for (final key in sectionKeys) {
      final section = sections[key]!;
      lines.add('');
      lines.add('$key:');
      lines.add(section);
    }
    return lines.join('\n');
  }
}

abstract class _BuiltinToolBase implements AgentTool {
  _BuiltinToolBase(this.runtime);

  final _BuiltinRuntime runtime;

  String get toolName;

  @override
  Future<ToolOutput> execute(Map<String, Object?> input) async {
    try {
      return (await executeBuiltin(input)).toToolOutput();
    } on _BuiltinToolException catch (error) {
      return _BuiltinToolResult(
        status: 'error',
        metadata: <String, Object?>{
          'tool': toolName,
          'code': error.code,
          'message': error.message,
        },
      ).toToolOutput();
    } on FileSystemException catch (error) {
      return _BuiltinToolResult(
        status: 'error',
        metadata: <String, Object?>{
          'tool': toolName,
          'code': 'file_system',
          'message': error.message,
        },
      ).toToolOutput();
    }
  }

  Future<_BuiltinToolResult> executeBuiltin(Map<String, Object?> input);

  String requireString(Map<String, Object?> input, String key) {
    final value = input[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw _BuiltinToolException(
      code: 'missing_input',
      message: 'Missing required string input `$key`.',
    );
  }

  bool optionalBool(
    Map<String, Object?> input,
    String key, {
    bool fallback = false,
  }) {
    final value = input[key];
    return value is bool ? value : fallback;
  }

  int optionalInt(
    Map<String, Object?> input,
    String key, {
    required int fallback,
  }) {
    final value = input[key];
    return value is int ? value : fallback;
  }
}

class _ReadTool extends _BuiltinToolBase {
  _ReadTool(super.runtime);

  @override
  String get toolName => 'read';

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'read',
    description:
        'Reads a UTF-8 text file or lists a directory inside the workspace.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'path': <String, Object?>{'type': 'string'},
        'offset': <String, Object?>{'type': 'integer'},
        'limit': <String, Object?>{'type': 'integer'},
      },
      'required': <String>['path'],
    },
  );

  @override
  Future<_BuiltinToolResult> executeBuiltin(Map<String, Object?> input) async {
    final resolved = runtime.resolvePath(requireString(input, 'path'));
    final offset = optionalInt(input, 'offset', fallback: 1);
    final limit = optionalInt(
      input,
      'limit',
      fallback: runtime.options.readLineLimit,
    );
    if (offset < 1 || limit < 1) {
      throw const _BuiltinToolException(
        code: 'invalid_range',
        message: 'Offset and limit must be greater than zero.',
      );
    }

    final entityType = FileSystemEntity.typeSync(
      resolved.absolutePath,
      followLinks: false,
    );
    return switch (entityType) {
      FileSystemEntityType.directory => _readDirectory(resolved, offset, limit),
      FileSystemEntityType.file => _readFile(resolved, offset, limit),
      _ => throw _BuiltinToolException(
        code: 'not_found',
        message: 'Path `${resolved.requestedPath}` was not found.',
      ),
    };
  }

  Future<_BuiltinToolResult> _readDirectory(
    _ResolvedPath resolved,
    int offset,
    int limit,
  ) async {
    final entries = await Directory(resolved.absolutePath).list().toList();
    entries.sort((a, b) => a.path.compareTo(b.path));
    final names = entries
        .map((entry) {
          final name = runtime._relativePath(entry.absolute.path);
          return entry is Directory ? '$name/' : name;
        })
        .toList(growable: false);
    final slice = _sliceLines(names, offset: offset, limit: limit);
    return _BuiltinToolResult(
      status: 'success',
      metadata: <String, Object?>{
        'entry_type': 'directory',
        'path': resolved.relativePath,
        'returned_entries': slice.returnedCount,
        'tool': toolName,
        'truncated': slice.truncated,
      },
      sections: <String, String>{
        'content': slice.lines.isEmpty ? '(empty)' : slice.lines.join('\n'),
      },
    );
  }

  Future<_BuiltinToolResult> _readFile(
    _ResolvedPath resolved,
    int offset,
    int limit,
  ) async {
    final content = await File(resolved.absolutePath).readAsString();
    final lines = const LineSplitter().convert(content);
    final slice = _sliceLines(lines, offset: offset, limit: limit);
    final numbered = <String>[];
    for (var index = 0; index < slice.lines.length; index++) {
      numbered.add('${offset + index}: ${slice.lines[index]}');
    }
    return _BuiltinToolResult(
      status: 'success',
      metadata: <String, Object?>{
        'entry_type': 'file',
        'path': resolved.relativePath,
        'returned_lines': slice.returnedCount,
        'tool': toolName,
        'truncated': slice.truncated,
      },
      sections: <String, String>{'content': numbered.join('\n')},
    );
  }
}

class _GlobTool extends _BuiltinToolBase {
  _GlobTool(super.runtime);

  @override
  String get toolName => 'glob';

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'glob',
    description: 'Finds workspace paths that match a glob pattern.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'pattern': <String, Object?>{'type': 'string'},
        'limit': <String, Object?>{'type': 'integer'},
      },
      'required': <String>['pattern'],
    },
  );

  @override
  Future<_BuiltinToolResult> executeBuiltin(Map<String, Object?> input) async {
    final pattern = requireString(input, 'pattern').replaceAll('\\', '/');
    final limit = optionalInt(
      input,
      'limit',
      fallback: runtime.options.globMatchLimit,
    );
    final matcher = _GlobMatcher(pattern);
    final matches = <String>[];

    await for (final entity in runtime.workspaceRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = runtime
          ._relativePath(entity.absolute.path)
          .replaceAll('\\', '/');
      final candidate = entity is Directory ? '$relative/' : relative;
      if (matcher.matches(candidate) || matcher.matches(relative)) {
        matches.add(candidate);
        if (matches.length >= limit) {
          break;
        }
      }
    }

    return _BuiltinToolResult(
      status: 'success',
      metadata: <String, Object?>{
        'match_count': matches.length,
        'pattern': pattern,
        'tool': toolName,
        'truncated': matches.length >= limit,
      },
      sections: <String, String>{
        'content': matches.isEmpty ? '(no matches)' : matches.join('\n'),
      },
    );
  }
}

class _SearchTool extends _BuiltinToolBase {
  _SearchTool(super.runtime);

  @override
  String get toolName => 'search';

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'search',
    description: 'Searches UTF-8 text files inside the workspace.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'pattern': <String, Object?>{'type': 'string'},
        'path': <String, Object?>{'type': 'string'},
        'regex': <String, Object?>{'type': 'boolean'},
        'case_sensitive': <String, Object?>{'type': 'boolean'},
        'limit': <String, Object?>{'type': 'integer'},
      },
      'required': <String>['pattern'],
    },
  );

  @override
  Future<_BuiltinToolResult> executeBuiltin(Map<String, Object?> input) async {
    final pattern = requireString(input, 'pattern');
    final startPath = (input['path'] as String?)?.trim() ?? '.';
    final resolved = runtime.resolvePath(startPath);
    final regex = optionalBool(input, 'regex');
    final caseSensitive = optionalBool(input, 'case_sensitive');
    final limit = optionalInt(
      input,
      'limit',
      fallback: runtime.options.searchMatchLimit,
    );
    final expression = regex
        ? RegExp(pattern, caseSensitive: caseSensitive)
        : RegExp(RegExp.escape(pattern), caseSensitive: caseSensitive);
    final matches = <String>[];

    final entityType = FileSystemEntity.typeSync(
      resolved.absolutePath,
      followLinks: false,
    );
    if (entityType == FileSystemEntityType.notFound) {
      throw _BuiltinToolException(
        code: 'not_found',
        message: 'Path `${resolved.requestedPath}` was not found.',
      );
    }

    Future<void> searchFile(String path) async {
      if (matches.length >= limit) {
        return;
      }
      try {
        final content = await File(path).readAsString();
        final lines = const LineSplitter().convert(content);
        for (var index = 0; index < lines.length; index++) {
          if (expression.hasMatch(lines[index])) {
            matches.add(
              '${runtime._relativePath(path)}:${index + 1}: ${lines[index]}',
            );
            if (matches.length >= limit) {
              return;
            }
          }
        }
      } on FileSystemException {
        return;
      } on FormatException {
        return;
      }
    }

    if (entityType == FileSystemEntityType.file) {
      await searchFile(resolved.absolutePath);
    } else {
      await for (final entity in Directory(
        resolved.absolutePath,
      ).list(recursive: true, followLinks: false)) {
        if (entity is File) {
          await searchFile(entity.absolute.path);
          if (matches.length >= limit) {
            break;
          }
        }
      }
    }

    return _BuiltinToolResult(
      status: 'success',
      metadata: <String, Object?>{
        'match_count': matches.length,
        'path': resolved.relativePath,
        'tool': toolName,
        'truncated': matches.length >= limit,
      },
      sections: <String, String>{
        'content': matches.isEmpty ? '(no matches)' : matches.join('\n'),
      },
    );
  }
}

class _EditTool extends _BuiltinToolBase {
  _EditTool(super.runtime);

  @override
  String get toolName => 'edit';

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'edit',
    description: 'Applies a direct string replacement to a workspace file.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'path': <String, Object?>{'type': 'string'},
        'old_text': <String, Object?>{'type': 'string'},
        'new_text': <String, Object?>{'type': 'string'},
        'replace_all': <String, Object?>{'type': 'boolean'},
      },
      'required': <String>['path', 'old_text', 'new_text'],
    },
  );

  @override
  Future<_BuiltinToolResult> executeBuiltin(Map<String, Object?> input) async {
    final resolved = runtime.resolvePath(requireString(input, 'path'));
    final oldText = requireString(input, 'old_text');
    final newText = input['new_text'] is String
        ? input['new_text'] as String
        : '';
    final replaceAll = optionalBool(input, 'replace_all');
    final file = File(resolved.absolutePath);
    if (!file.existsSync()) {
      throw _BuiltinToolException(
        code: 'not_found',
        message: 'File `${resolved.requestedPath}` was not found.',
      );
    }

    final original = await file.readAsString();
    if (!original.contains(oldText)) {
      throw _BuiltinToolException(
        code: 'no_match',
        message:
            'The requested old_text was not found in `${resolved.relativePath}`.',
      );
    }

    final updated = replaceAll
        ? original.replaceAll(oldText, newText)
        : original.replaceFirst(oldText, newText);
    final changed = updated != original;
    if (changed) {
      await file.writeAsString(updated);
    }

    return _BuiltinToolResult(
      status: 'success',
      metadata: <String, Object?>{
        'changed': changed,
        'path': resolved.relativePath,
        'tool': toolName,
      },
    );
  }
}

class _ApplyPatchTool extends _BuiltinToolBase {
  _ApplyPatchTool(super.runtime);

  @override
  String get toolName => 'apply_patch';

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'apply_patch',
    description:
        'Applies a stripped-down apply_patch envelope to workspace files.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'patch': <String, Object?>{'type': 'string'},
      },
      'required': <String>['patch'],
    },
  );

  @override
  Future<_BuiltinToolResult> executeBuiltin(Map<String, Object?> input) async {
    final operations = _PatchParser(
      runtime,
    ).parse(requireString(input, 'patch'));
    var changed = false;
    for (final operation in operations) {
      switch (operation) {
        case _AddFilePatch():
          final resolved = runtime.resolvePath(operation.path);
          final file = File(resolved.absolutePath);
          if (file.existsSync()) {
            throw _BuiltinToolException(
              code: 'patch_failed',
              message:
                  'Cannot add `${resolved.relativePath}` because it already exists.',
            );
          }
          file.parent.createSync(recursive: true);
          await file.writeAsString(
            _joinLines(operation.lines, trailingNewline: true),
          );
          changed = true;
        case _DeleteFilePatch():
          final resolved = runtime.resolvePath(operation.path);
          final file = File(resolved.absolutePath);
          if (!file.existsSync()) {
            throw _BuiltinToolException(
              code: 'patch_failed',
              message:
                  'Cannot delete `${resolved.relativePath}` because it does not exist.',
            );
          }
          await file.delete();
          changed = true;
        case _UpdateFilePatch():
          final source = runtime.resolvePath(operation.path);
          final file = File(source.absolutePath);
          if (!file.existsSync()) {
            throw _BuiltinToolException(
              code: 'patch_failed',
              message:
                  'Cannot update `${source.relativePath}` because it does not exist.',
            );
          }
          final original = await file.readAsString();
          final updated = _PatchApplier().apply(original, operation.hunks);
          final targetPath = operation.moveTo == null
              ? source
              : runtime.resolvePath(operation.moveTo!);
          if (source.absolutePath != targetPath.absolutePath) {
            File(targetPath.absolutePath).parent.createSync(recursive: true);
          }
          await File(targetPath.absolutePath).writeAsString(updated);
          if (source.absolutePath != targetPath.absolutePath) {
            await file.delete();
          }
          changed = true;
      }
    }

    return _BuiltinToolResult(
      status: 'success',
      metadata: <String, Object?>{
        'changed': changed,
        'operation_count': operations.length,
        'tool': toolName,
      },
    );
  }
}

class _BashTool extends _BuiltinToolBase {
  _BashTool(super.runtime);

  @override
  String get toolName => 'bash';

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'bash',
    description: 'Runs a shell command inside the workspace with a timeout.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'command': <String, Object?>{'type': 'string'},
        'working_directory': <String, Object?>{'type': 'string'},
      },
      'required': <String>['command'],
    },
  );

  @override
  Future<_BuiltinToolResult> executeBuiltin(Map<String, Object?> input) async {
    final command = requireString(input, 'command');
    final workingDirectory = runtime.resolveWorkingDirectory(
      input['working_directory'] as String?,
    );
    final shell = Platform.isWindows ? 'cmd.exe' : '/bin/sh';
    final shellArgs = Platform.isWindows
        ? <String>['/c', command]
        : <String>['-lc', command];
    final process = await Process.start(
      shell,
      shellArgs,
      workingDirectory: workingDirectory.absolutePath,
      runInShell: false,
    );
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCodeFuture = process.exitCode;

    int? exitCode;
    var timedOut = false;
    try {
      exitCode = await exitCodeFuture.timeout(runtime.options.bashTimeout);
    } on TimeoutException {
      timedOut = true;
      process.kill(ProcessSignal.sigkill);
      await exitCodeFuture;
    }
    final stdoutText = await stdoutFuture;
    final stderrText = await stderrFuture;

    if (timedOut) {
      throw _BuiltinToolException(
        code: 'timeout',
        message:
            'Command exceeded the configured timeout of ${runtime.options.bashTimeout.inSeconds} seconds.',
      );
    }

    return _BuiltinToolResult(
      status: exitCode == 0 ? 'success' : 'error',
      metadata: <String, Object?>{
        'exit_code': exitCode,
        'timed_out': false,
        'tool': toolName,
        'working_directory': workingDirectory.relativePath,
      },
      sections: <String, String>{'stderr': stderrText, 'stdout': stdoutText},
    );
  }
}

class _WebfetchTool extends _BuiltinToolBase {
  _WebfetchTool(super.runtime);

  @override
  String get toolName => 'webfetch';

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'webfetch',
    description: 'Fetches HTTP or HTTPS content and normalizes it into text.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'url': <String, Object?>{'type': 'string'},
      },
      'required': <String>['url'],
    },
  );

  @override
  Future<_BuiltinToolResult> executeBuiltin(Map<String, Object?> input) async {
    final rawUrl = requireString(input, 'url').trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw _BuiltinToolException(
        code: 'invalid_url',
        message: 'URL must use http or https.',
      );
    }

    final client = runtime.options.httpClientFactory();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(runtime.options.webfetchTimeout);
      final response = await request.close().timeout(
        runtime.options.webfetchTimeout,
      );
      final contentType = response.headers.contentType;
      final mediaType =
          contentType?.mimeType.toLowerCase() ?? 'application/octet-stream';
      if (!_isSupportedContentType(mediaType)) {
        throw _BuiltinToolException(
          code: 'unsupported_content',
          message: 'Content type `$mediaType` is not supported.',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final truncated = body.length > runtime.options.webfetchCharacterLimit;
      final content = truncated
          ? body.substring(0, runtime.options.webfetchCharacterLimit)
          : body;

      return _BuiltinToolResult(
        status: response.statusCode >= 200 && response.statusCode < 400
            ? 'success'
            : 'error',
        metadata: <String, Object?>{
          'content_type': mediaType,
          'status_code': response.statusCode,
          'tool': toolName,
          'truncated': truncated,
          'url': uri.toString(),
        },
        sections: <String, String>{'content': content},
      );
    } on TimeoutException {
      throw _BuiltinToolException(
        code: 'timeout',
        message:
            'Fetch exceeded the configured timeout of ${runtime.options.webfetchTimeout.inSeconds} seconds.',
      );
    } finally {
      client.close(force: true);
    }
  }

  bool _isSupportedContentType(String mediaType) {
    return mediaType.startsWith('text/') ||
        mediaType == 'application/json' ||
        mediaType == 'application/xml' ||
        mediaType.endsWith('+json') ||
        mediaType.endsWith('+xml');
  }
}

class _LineSlice {
  const _LineSlice({
    required this.lines,
    required this.returnedCount,
    required this.truncated,
  });

  final List<String> lines;
  final int returnedCount;
  final bool truncated;
}

_LineSlice _sliceLines(
  List<String> lines, {
  required int offset,
  required int limit,
}) {
  if (lines.isEmpty || offset > lines.length) {
    return const _LineSlice(
      lines: <String>[],
      returnedCount: 0,
      truncated: false,
    );
  }
  final start = offset - 1;
  final end = (start + limit) > lines.length ? lines.length : start + limit;
  return _LineSlice(
    lines: lines.sublist(start, end),
    returnedCount: end - start,
    truncated: end < lines.length,
  );
}

String _joinLines(List<String> lines, {required bool trailingNewline}) {
  if (lines.isEmpty) {
    return '';
  }
  final joined = lines.join('\n');
  return trailingNewline ? '$joined\n' : joined;
}

class _GlobMatcher {
  _GlobMatcher(String pattern) : _expression = RegExp(_globToPattern(pattern));

  final RegExp _expression;

  bool matches(String candidate) => _expression.hasMatch(candidate);

  static String _globToPattern(String pattern) {
    final buffer = StringBuffer('^');
    for (var index = 0; index < pattern.length; index++) {
      final char = pattern[index];
      if (char == '*') {
        final nextIsStar =
            index + 1 < pattern.length && pattern[index + 1] == '*';
        if (nextIsStar) {
          buffer.write('.*');
          index++;
        } else {
          buffer.write('[^/]*');
        }
        continue;
      }
      if (char == '?') {
        buffer.write('[^/]');
        continue;
      }
      if ('\\.^\$+()[]{}|'.contains(char)) {
        buffer.write('\\');
      }
      buffer.write(char);
    }
    buffer.write(r'$');
    return buffer.toString();
  }
}

sealed class _PatchOperation {
  const _PatchOperation();
}

class _AddFilePatch extends _PatchOperation {
  const _AddFilePatch({required this.path, required this.lines});

  final String path;
  final List<String> lines;
}

class _DeleteFilePatch extends _PatchOperation {
  const _DeleteFilePatch({required this.path});

  final String path;
}

class _UpdateFilePatch extends _PatchOperation {
  const _UpdateFilePatch({
    required this.path,
    required this.hunks,
    this.moveTo,
  });

  final String path;
  final String? moveTo;
  final List<_PatchHunk> hunks;
}

class _PatchHunk {
  const _PatchHunk(this.lines);

  final List<_PatchLine> lines;
}

class _PatchLine {
  const _PatchLine(this.kind, this.text);

  final String kind;
  final String text;
}

class _PatchParser {
  const _PatchParser(this.runtime);

  final _BuiltinRuntime runtime;

  List<_PatchOperation> parse(String patchText) {
    final lines = const LineSplitter().convert(patchText);
    if (lines.length < 2 ||
        lines.first != '*** Begin Patch' ||
        lines.last != '*** End Patch') {
      throw const _BuiltinToolException(
        code: 'patch_failed',
        message: 'Patch must use the *** Begin Patch / *** End Patch envelope.',
      );
    }
    final operations = <_PatchOperation>[];
    var index = 1;
    while (index < lines.length - 1) {
      final line = lines[index];
      if (line.startsWith('*** Add File: ')) {
        final path = line.substring('*** Add File: '.length);
        runtime.resolvePath(path);
        index++;
        final content = <String>[];
        while (index < lines.length - 1 && !lines[index].startsWith('*** ')) {
          final entry = lines[index];
          if (!entry.startsWith('+')) {
            throw const _BuiltinToolException(
              code: 'patch_failed',
              message: 'Added file contents must prefix each line with `+`.',
            );
          }
          content.add(entry.substring(1));
          index++;
        }
        operations.add(_AddFilePatch(path: path, lines: content));
        continue;
      }
      if (line.startsWith('*** Delete File: ')) {
        final path = line.substring('*** Delete File: '.length);
        runtime.resolvePath(path);
        operations.add(_DeleteFilePatch(path: path));
        index++;
        continue;
      }
      if (line.startsWith('*** Update File: ')) {
        final path = line.substring('*** Update File: '.length);
        runtime.resolvePath(path);
        index++;
        String? moveTo;
        if (index < lines.length - 1 &&
            lines[index].startsWith('*** Move to: ')) {
          moveTo = lines[index].substring('*** Move to: '.length);
          runtime.resolvePath(moveTo);
          index++;
        }
        final hunkLines = <_PatchLine>[];
        while (index < lines.length - 1 && !lines[index].startsWith('*** ')) {
          final entry = lines[index];
          if (entry.startsWith('@@')) {
            index++;
            continue;
          }
          if (entry.isEmpty) {
            hunkLines.add(const _PatchLine(' ', ''));
            index++;
            continue;
          }
          final kind = entry[0];
          if (kind != ' ' && kind != '+' && kind != '-') {
            throw const _BuiltinToolException(
              code: 'patch_failed',
              message: 'Updated file hunks must use space, +, or - prefixes.',
            );
          }
          hunkLines.add(_PatchLine(kind, entry.substring(1)));
          index++;
        }
        if (hunkLines.isEmpty) {
          throw const _BuiltinToolException(
            code: 'patch_failed',
            message:
                'Updated file patches must include at least one hunk line.',
          );
        }
        operations.add(
          _UpdateFilePatch(
            path: path,
            moveTo: moveTo,
            hunks: <_PatchHunk>[_PatchHunk(hunkLines)],
          ),
        );
        continue;
      }

      throw _BuiltinToolException(
        code: 'patch_failed',
        message: 'Unsupported patch operation: $line',
      );
    }
    return operations;
  }
}

class _PatchApplier {
  String apply(String original, List<_PatchHunk> hunks) {
    final originalLines = const LineSplitter().convert(original);
    final trailingNewline = original.endsWith('\n');
    final output = <String>[];
    var cursor = 0;

    for (final hunk in hunks) {
      final needle = hunk.lines
          .where((line) => line.kind != '+')
          .map((line) => line.text)
          .toList(growable: false);
      final start = _findSubsequence(originalLines, needle, cursor);
      if (start == null) {
        throw const _BuiltinToolException(
          code: 'patch_failed',
          message: 'Patch hunk did not match the current file contents.',
        );
      }
      output.addAll(originalLines.sublist(cursor, start));
      var sourceIndex = start;
      for (final line in hunk.lines) {
        switch (line.kind) {
          case ' ':
            output.add(originalLines[sourceIndex]);
            sourceIndex++;
          case '-':
            sourceIndex++;
          case '+':
            output.add(line.text);
        }
      }
      cursor = sourceIndex;
    }

    output.addAll(originalLines.sublist(cursor));
    return _joinLines(output, trailingNewline: trailingNewline);
  }

  int? _findSubsequence(List<String> haystack, List<String> needle, int start) {
    if (needle.isEmpty) {
      return start;
    }
    for (var index = start; index <= haystack.length - needle.length; index++) {
      var match = true;
      for (var offset = 0; offset < needle.length; offset++) {
        if (haystack[index + offset] != needle[offset]) {
          match = false;
          break;
        }
      }
      if (match) {
        return index;
      }
    }
    return null;
  }
}
