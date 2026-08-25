import "dart:async";

import "package:sesori_bridge/src/api/bridge_settings_api.dart";

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
  Future<void> writeConfig(String jsonContent) async {
    writeStarted?.complete();
    final release = releaseWrite;
    if (release != null) await release.future;
    config = jsonContent;
    writeCount++;
  }
}
