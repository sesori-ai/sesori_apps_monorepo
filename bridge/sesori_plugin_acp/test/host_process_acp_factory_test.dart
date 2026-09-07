import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("defaultAcpProcessFactory applies isolation to a real child", () async {
    final directory = await Directory.systemTemp.createTemp("acp-environment-test-");
    addTearDown(() => directory.delete(recursive: true));
    final script = File("${directory.path}/environment.dart");
    await script.writeAsString('''
import 'dart:io';
void main() {
  print(Platform.environment['SESORI_TEST_MARKER']);
  print(Platform.environment.keys.any((key) => key.toUpperCase() == 'PATH'));
}
''');
    for (final inherits in [true, false]) {
      final process = await defaultAcpProcessFactory(
        AcpLaunchSpec(
          command: Platform.resolvedExecutable,
          args: [script.path],
          environment: const {"SESORI_TEST_MARKER": "synthetic"},
          includeParentEnvironment: inherits,
        ),
      );
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      await process.stdin.close();
      expect(await process.exitCode, 0, reason: await errors);
      final parentHasPath = Platform.environment.keys.any((key) => key.toUpperCase() == "PATH");
      expect((await output).trim().split(RegExp(r"\r?\n")), ["synthetic", "${inherits && parentHasPath}"]);
    }
  });

  for (final inherits in [true, false]) {
    test("hostProcessAcpFactory forwards inheritance=$inherits without reintroducing ambient values", () async {
      final processes = _Processes();
      final factory = hostProcessAcpFactory(
        processes: processes,
        environment: const {"AMBIENT": "excluded", "OVERRIDE": "host"},
      );
      await factory(
        AcpLaunchSpec(
          command: "/runtime/agent",
          args: const [],
          environment: const {"OVERRIDE": "spec"},
          includeParentEnvironment: inherits,
        ),
      );
      expect(processes.inherits, inherits);
      expect(processes.environment, {if (inherits) "AMBIENT": "excluded", "OVERRIDE": "spec"});
    });
  }
}

class _Processes() implements HostProcessService {
  bool? inherits;
  Map<String, String>? environment;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) async {
    inherits = includeParentEnvironment;
    this.environment = environment;
    return _Process();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Process() implements SpawnedProcess {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
