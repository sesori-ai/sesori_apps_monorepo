import "dart:async";

import "package:sesori_bridge/src/api/bridge_settings_api.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";

class InMemoryBridgeSettingsApi({
  required var String? config,
  @override final String configFilePath = "/tmp/config.json",
}) implements BridgeSettingsApi {
  int writeCount = 0;
  Completer<void>? writeStarted;
  Completer<void>? releaseWrite;

  String? get lastWrittenConfig => writeCount == 0 ? null : config;

  @override
  Future<String?> readConfig() async => config;

  @override
  Future<void> writeConfig({required String jsonContent}) async {
    writeStarted?.complete();
    final release = releaseWrite;
    if (release != null) await release.future;
    config = jsonContent;
    writeCount++;
  }
}

/// A loaded settings repository over [config], the defaults when null.
Future<BridgeSettingsRepository> loadTestBridgeSettings({required String? config}) async {
  final repository = BridgeSettingsRepository(api: InMemoryBridgeSettingsApi(config: config), defaultEditorApi: null);
  await repository.loadSettings();
  return repository;
}
