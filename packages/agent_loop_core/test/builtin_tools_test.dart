import 'dart:io';

import 'package:agent_loop_core/agent_loop_core.dart';
import 'package:test/test.dart';

void main() {
  group('createBuiltinTools', () {
    test('registers the expected builtin tool names', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));

      final tools = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace),
      );

      expect(tools.map((tool) => tool.definition.name), <String>[
        'read',
        'glob',
        'search',
        'edit',
        'apply_patch',
        'bash',
        'webfetch',
      ]);
    });

    test('rejects filesystem access outside the workspace', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));

      final readTool = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace),
      ).singleWhere((tool) => tool.definition.name == 'read');

      final result = await readTool.execute(<String, Object?>{
        'path': '../outside.txt',
      });

      expect(result, contains('status: error'));
      expect(result, contains('code: workspace_boundary'));
    });
  });

  group('builtin read/search tools', () {
    test('reads files with numbered lines and truncation metadata', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));
      final file = File('${workspace.path}/notes.txt');
      await file.writeAsString('alpha\nbeta\ngamma\n');

      final readTool = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace, readLineLimit: 2),
      ).singleWhere((tool) => tool.definition.name == 'read');

      final result = await readTool.execute(<String, Object?>{
        'path': 'notes.txt',
      });

      expect(result, contains('status: success'));
      expect(result, contains('truncated: true'));
      expect(result, contains('1: alpha'));
      expect(result, contains('2: beta'));
      expect(result, isNot(contains('3: gamma')));
    });

    test('finds matches and reports truncation metadata', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));
      await File(
        '${workspace.path}/a.txt',
      ).writeAsString('alpha\nbeta\nalpha\n');
      await File('${workspace.path}/b.txt').writeAsString('alpha\n');

      final searchTool = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace, searchMatchLimit: 2),
      ).singleWhere((tool) => tool.definition.name == 'search');

      final result = await searchTool.execute(<String, Object?>{
        'pattern': 'alpha',
      });

      expect(result, contains('status: success'));
      expect(result, contains('truncated: true'));
      expect(result, contains('a.txt:1: alpha'));
    });
  });

  group('builtin edit/apply_patch tools', () {
    test('edits matching content and reports changed success', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));
      final file = File('${workspace.path}/edit.txt');
      await file.writeAsString('hello world');

      final editTool = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace),
      ).singleWhere((tool) => tool.definition.name == 'edit');

      final result = await editTool.execute(<String, Object?>{
        'path': 'edit.txt',
        'old_text': 'world',
        'new_text': 'dart',
      });

      expect(result, contains('status: success'));
      expect(result, contains('changed: true'));
      expect(await file.readAsString(), 'hello dart');
    });

    test('fails edit without mutating when old text does not match', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));
      final file = File('${workspace.path}/edit.txt');
      await file.writeAsString('hello world');

      final editTool = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace),
      ).singleWhere((tool) => tool.definition.name == 'edit');

      final result = await editTool.execute(<String, Object?>{
        'path': 'edit.txt',
        'old_text': 'missing',
        'new_text': 'dart',
      });

      expect(result, contains('status: error'));
      expect(result, contains('code: no_match'));
      expect(await file.readAsString(), 'hello world');
    });

    test('applies a simple patch and reports success', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));
      final file = File('${workspace.path}/patch.txt');
      await file.writeAsString('alpha\nbeta\n');

      final patchTool = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace),
      ).singleWhere((tool) => tool.definition.name == 'apply_patch');

      final result = await patchTool.execute(<String, Object?>{
        'patch': '''*** Begin Patch
*** Update File: patch.txt
@@
 alpha
-beta
+gamma
*** End Patch''',
      });

      expect(result, contains('status: success'));
      expect(result, contains('changed: true'));
      expect(await file.readAsString(), 'alpha\ngamma\n');
    });

    test('fails patch application without mutating the file', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));
      final file = File('${workspace.path}/patch.txt');
      await file.writeAsString('alpha\nbeta\n');

      final patchTool = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace),
      ).singleWhere((tool) => tool.definition.name == 'apply_patch');

      final result = await patchTool.execute(<String, Object?>{
        'patch': '''*** Begin Patch
*** Update File: patch.txt
@@
 alpha
-missing
+gamma
*** End Patch''',
      });

      expect(result, contains('status: error'));
      expect(result, contains('code: patch_failed'));
      expect(await file.readAsString(), 'alpha\nbeta\n');
    });
  });

  group('builtin bash/webfetch tools', () {
    test('runs a bash command successfully', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));

      final bashTool = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace),
      ).singleWhere((tool) => tool.definition.name == 'bash');

      final result = await bashTool.execute(<String, Object?>{
        'command': 'printf hello',
      });

      expect(result, contains('status: success'));
      expect(result, contains('exit_code: 0'));
      expect(result, contains('stdout:\nhello'));
    });

    test('times out a long-running bash command', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));

      final bashTool = createBuiltinTools(
        BuiltinToolOptions(
          workspaceRoot: workspace,
          bashTimeout: const Duration(milliseconds: 100),
        ),
      ).singleWhere((tool) => tool.definition.name == 'bash');

      final result = await bashTool.execute(<String, Object?>{
        'command': 'sleep 1',
      });

      expect(result, contains('status: error'));
      expect(result, contains('code: timeout'));
    });

    test('fetches text content and reports truncation', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.text;
        request.response.write('abcdefghij');
        await request.response.close();
      });

      final webfetchTool = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace, webfetchCharacterLimit: 5),
      ).singleWhere((tool) => tool.definition.name == 'webfetch');

      final result = await webfetchTool.execute(<String, Object?>{
        'url': 'http://${server.address.host}:${server.port}/',
      });

      expect(result, contains('status: success'));
      expect(result, contains('truncated: true'));
      expect(result, contains('content:\nabcde'));
    });

    test('rejects unsupported content types', () async {
      final workspace = await Directory.systemTemp.createTemp('builtin-tools');
      addTearDown(() => workspace.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.binary;
        request.response.add(<int>[0, 1, 2, 3]);
        await request.response.close();
      });

      final webfetchTool = createBuiltinTools(
        BuiltinToolOptions(workspaceRoot: workspace),
      ).singleWhere((tool) => tool.definition.name == 'webfetch');

      final result = await webfetchTool.execute(<String, Object?>{
        'url': 'http://${server.address.host}:${server.port}/',
      });

      expect(result, contains('status: error'));
      expect(result, contains('code: unsupported_content'));
    });
  });
}
