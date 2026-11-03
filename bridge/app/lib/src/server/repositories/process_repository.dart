import "dart:io" as io;

import "package:path/path.dart" as path;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/system_process_api.dart";
import "../api/windows_job_object_api.dart";
import "../foundation/process_match.dart";

class ProcessRepository({
  required final SystemProcessApi _api,
  required final WindowsJobObjectApi _windowsJobObjectApi,
  required final ProcessUser? _currentUser,
}) {
  /// Windows only: starts a process that, with everything it starts, ends
  /// when the bridge exits. Throws when it cannot, leaving nothing running.
  io.Process startBoundToBridgeLifetime({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) {
    return _windowsJobObjectApi.startBoundToBridgeLifetime(
      executable: executable,
      arguments: arguments,
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
      includeParentEnvironment: includeParentEnvironment,
    );
  }

  /// Windows only: [pid] and its later descendants end when the bridge exits.
  void bindToBridgeLifetime({required int pid}) => _windowsJobObjectApi.bindToBridgeLifetime(pid: pid);

  Future<ProcessIdentity?> inspectProcess({required int pid}) => _api.inspectProcess(pid: pid);

  Future<ProcessMatch?> inspectProcessMatch({required int pid}) async {
    final identity = await inspectProcess(pid: pid);
    if (identity == null) {
      return null;
    }
    return _toMatch(identity: identity);
  }

  Future<SignalResult> sendGracefulSignal({required int pid}) {
    return _api.sendGracefulSignal(pid: pid);
  }

  Future<SignalResult> sendForceSignal({required int pid}) {
    return _api.sendForceSignal(pid: pid);
  }

  ProcessMatch _toMatch({required ProcessIdentity identity}) {
    return ProcessMatch(
      identity: identity,
      kind: _resolveKind(identity: identity),
      isCurrentUserProcess: identity.ownerUser != null && identity.ownerUser == _currentUser,
    );
  }

  ProcessMatchKind _resolveKind({required ProcessIdentity identity}) {
    final executablePath = identity.executablePath;
    final executableBasename = executablePath == null ? null : path.basename(executablePath).toLowerCase();
    final commandLine = identity.commandLine.toLowerCase();

    if (executableBasename == "sesori-bridge" ||
        executableBasename == "sesori-bridge.exe" ||
        commandLine.contains("bridge/app/bin/bridge.dart")) {
      return ProcessMatchKind.sesoriBridge;
    }

    return ProcessMatchKind.unknown;
  }
}
