import "dart:io" as io;

import "package:sesori_bridge/src/server/foundation/process_match.dart";
import "package:sesori_bridge/src/server/repositories/process_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class StrictFakeProcessRepository() implements ProcessRepository {
  @override
  io.Process startBoundToBridgeLifetime({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) {
    throw UnimplementedError();
  }

  @override
  void bindToBridgeLifetime({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<ProcessMatch?> inspectProcessMatch({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<SignalResult> sendGracefulSignal({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<SignalResult> sendForceSignal({required int pid}) {
    throw UnimplementedError();
  }
}
