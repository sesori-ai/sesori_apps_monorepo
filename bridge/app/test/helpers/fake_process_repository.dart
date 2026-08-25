import "package:sesori_bridge/src/server/foundation/process_match.dart";
import "package:sesori_bridge/src/server/repositories/process_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class StrictFakeProcessRepository() implements ProcessRepository {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
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
