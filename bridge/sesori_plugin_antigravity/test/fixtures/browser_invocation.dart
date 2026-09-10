import "dart:io";

import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Exercises the descriptor's actual process metadata, not injected prefixes.
/// The capture aborts before profile writes or any Google runtime/network use.
Future<void> main(List<String> arguments) async {
  if (BrowserNoop.matches(arguments: arguments)) return;
  final expectsExplicitPackages = arguments.single == "explicit";
  if ((Platform.packageConfig != null) != expectsExplicitPackages) {
    throw StateError("Fixture package discovery did not match its launch mode");
  }
  Log.level = LogLevel.error;
  final state = await Directory.systemTemp.createTemp("antigravity-browser-invocation-");
  try {
    final processes = _CaptureProcesses();
    final descriptor = AntigravityPluginDescriptor(
      callbackHttpClientFactory: HttpClient.new,
      runtimeDownloadHttpClientFactory: () => throw StateError("No runtime download is allowed"),
    );
    final operation = descriptor.authenticate(
      config: const PluginConfig(values: {AntigravityPluginDescriptor.binOption: null}),
      processes: processes,
      environment: const {},
      stateDirectory: state.path,
      store: const _Store(),
      aborted: StartAbortSignal.never,
    );
    try {
      await operation.events.drain<void>();
      throw StateError("The capture must stop before profile preparation");
    } on AntigravityProfileException catch (error) {
      if (!identical(error.cause, processes.stop)) rethrow;
    }

    final invocation = processes.invocation;
    final result = await Process.run(
      invocation.executable,
      invocation.arguments,
      environment: invocation.environment,
      includeParentEnvironment: false,
      runInShell: false,
      workingDirectory: state.path,
    ).timeout(const Duration(seconds: 45));
    if (result.exitCode != 0 || result.stdout != "" || result.stderr != "") {
      throw StateError("Helper failed: exit=${result.exitCode}, stdout=${result.stdout}, stderr=${result.stderr}");
    }
    if (state.listSync().isNotEmpty) throw StateError("Browser preflight wrote profile state");
  } finally {
    await state.delete(recursive: true);
  }
}

class _CaptureProcesses() implements HostProcessService {
  final stop = StateError("Stop before profile preparation");
  late final ({String executable, List<String> arguments, Map<String, String>? environment}) invocation;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) async {
    if (runInShell || includeParentEnvironment) throw StateError("Browser preflight must not inherit or use a shell");
    invocation = (executable: executable, arguments: arguments, environment: environment);
    throw stop;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _Store() implements HostJsonStore {
  @override
  HostJsonStore scope({required String directoryName}) => this;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
