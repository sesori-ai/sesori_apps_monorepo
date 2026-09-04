import "package:rxdart/rxdart.dart";

import "../repositories/bridge_settings_repository.dart";

class PluginWarmupSettingsService({
  required final BridgeSettingsRepository _bridgeSettingsRepository,
}) {
  bool get isEnabled => _bridgeSettingsRepository.currentSettings.warmUpPluginsOnSessionOpen;

  /// Emits the current value on listen, then each distinct committed value.
  Stream<bool> get states => _bridgeSettingsRepository.settingsChanges
      .map((change) => change.current.warmUpPluginsOnSessionOpen)
      .startWith(isEnabled)
      .distinct();

  Future<bool> update({required bool enabled}) async {
    final committed = await _bridgeSettingsRepository.updateWarmUpPluginsOnSessionOpen(enabled: enabled);
    return committed.warmUpPluginsOnSessionOpen;
  }
}
