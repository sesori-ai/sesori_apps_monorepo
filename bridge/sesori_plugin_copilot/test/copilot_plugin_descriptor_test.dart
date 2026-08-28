import "dart:convert";
import "dart:io";

import "package:copilot_plugin/copilot_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const defaultConfig = PluginConfig(values: {CopilotPluginDescriptor.binOption: "copilot"});

  test("offers managed install only for automatic runtime selection", () {
    final descriptor = CopilotPluginDescriptor.production();
    expect(descriptor.managementCapabilities(config: defaultConfig), contains(PluginControlCapability.install));
    expect(
      descriptor.managementCapabilities(
        config: const PluginConfig(values: {CopilotPluginDescriptor.binOption: "/custom/copilot"}),
      ),
      isNot(contains(PluginControlCapability.install)),
    );
  });

  test("reports a supported PATH runtime ready without starting ACP", () async {
    final result = await CopilotPluginDescriptor.production().inspectSetup(
      config: defaultConfig,
      processes: _Processes(
        outputs: const [_Output(stdout: "GitHub Copilot CLI 1.0.80.\nRun 'copilot update' to check.\n", exitCode: 0)],
      ),
      environment: const {"COPILOT_HOME": "/profile"},
      stateDirectory: "/state",
    );

    expect(result, const PluginSetupReady.versioned(runtimeVersion: "1.0.80"));
  });

  test("classifies an unrelated explicit runtime as unrecognized", () async {
    final unknown = await CopilotPluginDescriptor.production().inspectSetup(
      config: const PluginConfig(values: {CopilotPluginDescriptor.binOption: "/custom/copilot"}),
      processes: _Processes(outputs: const [_Output(stdout: "git version 2.43.0\n", exitCode: 0)]),
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

  test("an aborted managed install stops before process or network work", () async {
    final controller = StartAbortController()..abort();
    await expectLater(
      CopilotPluginDescriptor.production()
          .installRuntime(
            config: defaultConfig,
            processes: _Processes(),
            environment: const {},
            stateDirectory: "/state",
            startAborted: controller.signal,
          )
          .toList(),
      throwsA(isA<PluginStartAbortedException>()),
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
    if (_index >= outputs.length) throw ProcessException(executable, arguments, "missing", 2);
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
