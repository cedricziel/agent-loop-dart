import 'dart:io';

import 'package:agent_loop_cli/agent_loop_cli.dart';

Future<void> main(List<String> args) async {
  final exitCode = await runCli(args);
  if (exitCode != 0) {
    exit(exitCode);
  }
}
