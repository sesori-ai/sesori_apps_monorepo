import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;

import "../api/bridge_process_log_storage.dart";

/// Layer-2 owner of the local directory containing app and helper diagnostics.
@lazySingleton
class BridgeProcessLogRepository._create({required final BridgeProcessLogStorage _storage}) {
  new({required BridgeProcessLogStorage storage}) : this._create(storage: storage);

  Future<Uri> get logDirectoryUri async => Uri.directory(path.dirname(await _storage.logFilePath));
}
