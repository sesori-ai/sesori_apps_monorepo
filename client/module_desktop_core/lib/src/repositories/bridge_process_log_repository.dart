import "package:injectable/injectable.dart";

import "../api/bridge_process_log_storage.dart";

/// Layer-2 owner of the user-facing helper-log resource location.
@lazySingleton
class BridgeProcessLogRepository._create({required final BridgeProcessLogStorage _storage}) {
  new({required BridgeProcessLogStorage storage}) : this._create(storage: storage);

  Future<Uri> get logFileUri async => Uri.file(await _storage.logFilePath);
}
