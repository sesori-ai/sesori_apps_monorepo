import "dart:convert";
import "dart:io";

import "package:copilot_plugin/copilot_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("classifies an unrelated explicit runtime as unrecognized", () async {
    const explicit = PluginConfig(values: {CopilotPluginDescriptor.binOption: "/custom/copilot"});
    final unknown = await CopilotPluginDescriptor.production().inspectSetup(
      config: explicit,
      processes: _Processes(
        outputs: const [_Output(stdout: "git version 2.43.0\n", exitCode: 0)],
      ),
      environment: const {},
      stateDirectory: "/state",
    );

    expect(unknown, isA<PluginSetupUnknown>());
  });

  test("does not launch when runtime provisioning rejected every candidate", () async {
    await expectLater(
      CopilotPluginDescriptor.production().start(const _Host(provisionedRuntimePath: null)),
      throwsA(isA<PluginStartException>()),
    );
  });
}

class const _Host({@override required final String? provisionedRuntimePath}) implements PluginHost {
  @override
  StartAbortSignal get startAborted => StartAbortSignal.never;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _Output({required final String stdout, required final int exitCode});

class _Processes({final List<_Output> outputs = const []}) implements HostProcessService {
  int _index = 0;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    if (_index >= outputs.length) {
      throw ProcessException(executable, arguments, "missing", 2);
    }
    return _ProbeProcess(output: outputs[_index++]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProbeProcess({required _Output output}) implements SpawnedProcess {
  @override
  final Stream<List<int>> stdout = Stream.value(utf8.encode(output.stdout));

  @override
  final Future<int> exitCode = Future.value(output.exitCode);

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
