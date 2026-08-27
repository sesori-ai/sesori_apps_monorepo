import "dart:async";
import "dart:convert";
import "dart:io";

import "package:copilot_plugin/copilot_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const defaultConfig = PluginConfig(values: {CopilotPluginDescriptor.binOption: "copilot"});

  group("CopilotPluginDescriptor setup", () {
    test("declares a bridge-derived attachment-capable ACP plugin", () {
      final descriptor = CopilotPluginDescriptor.production();

      expect(descriptor.id, "copilot");
      expect(descriptor.displayName, "GitHub Copilot");
      expect(descriptor.projectOwnership, PluginProjectOwnership.bridgeDerived);
      expect(descriptor.sessionOptionsScope, PluginSessionOptionsScope.plugin);
      expect(descriptor.supportsPromptAttachments, isTrue);
      expect(descriptor.options.single.name, CopilotPluginDescriptor.binOption);
      expect(
        descriptor.managementCapabilities(config: defaultConfig),
        isNot(contains(PluginControlCapability.install)),
      );
    });

    test("reports a supported PATH runtime ready without starting ACP", () async {
      final processes = _Processes(
        outputs: const [_Output(stdout: "GitHub Copilot CLI 1.0.80.\nRun 'copilot update' to check.\n", exitCode: 0)],
      );
      final result = await CopilotPluginDescriptor.production().inspectSetup(
        config: defaultConfig,
        processes: processes,
        environment: const {"COPILOT_HOME": "/profile"},
        stateDirectory: "/state",
      );

      expect(result, const PluginSetupReady.versioned(runtimeVersion: "1.0.80"));
      expect(processes.executables, ["copilot"]);
      expect(processes.arguments, [
        const ["--version"],
      ]);
      expect(processes.environments.single, const {"COPILOT_HOME": "/profile"});
    });

    test("classifies a missing automatic runtime without probing credentials", () async {
      final result = await CopilotPluginDescriptor.production().inspectSetup(
        config: defaultConfig,
        processes: _Processes(),
        environment: const {},
        stateDirectory: "/state",
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
    });

    test("classifies outdated and unrecognized explicit runtimes", () async {
      const explicit = PluginConfig(values: {CopilotPluginDescriptor.binOption: "/custom/copilot"});
      final descriptor = CopilotPluginDescriptor.production();
      final outdated = await descriptor.inspectSetup(
        config: explicit,
        processes: _Processes(
          outputs: const [_Output(stdout: "GitHub Copilot CLI 1.0.77.\n", exitCode: 0)],
        ),
        environment: const {},
        stateDirectory: "/state",
      );
      final unknown = await descriptor.inspectSetup(
        config: explicit,
        processes: _Processes(
          outputs: const [_Output(stdout: "git version 2.43.0\n", exitCode: 0)],
        ),
        environment: const {},
        stateDirectory: "/state",
      );

      expect(outdated, isA<PluginSetupUnavailable>());
      expect(unknown, isA<PluginSetupUnknown>());
    });
  });
}

class const _Output({required final String stdout, required final int exitCode});

class _Processes({final List<_Output> outputs = const []}) implements HostProcessService {
  final List<String> executables = [];
  final List<List<String>> arguments = [];
  final List<Map<String, String>?> environments = [];
  int _index = 0;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    executables.add(executable);
    this.arguments.add(arguments);
    environments.add(environment);
    if (_index >= outputs.length) {
      throw ProcessException(executable, arguments, "missing", 2);
    }
    return _ProbeProcess(output: outputs[_index++]);
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalForce({required int pid}) async =>
      _signal(pid: pid, signal: ShutdownSignal.force, delivered: ProcessSignal.sigkill);

  @override
  Future<SignalResult> signalGraceful({required int pid}) async =>
      _signal(pid: pid, signal: ShutdownSignal.graceful, delivered: ProcessSignal.sigterm);

  SignalResult _signal({
    required int pid,
    required ShutdownSignal signal,
    required ProcessSignal delivered,
  }) => SignalResult(
    pid: pid,
    requestedSignal: signal,
    deliveredSignal: delivered,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 8, 27),
  );
}

class _ProbeProcess({required _Output output}) implements SpawnedProcess {
  @override
  final Stream<List<int>> stdout = Stream.value(utf8.encode(output.stdout));

  @override
  final Future<int> exitCode = Future.value(output.exitCode);

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  int get pid => 1;

  @override
  ProcessIdentity get identity => throw UnimplementedError();

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);
}
