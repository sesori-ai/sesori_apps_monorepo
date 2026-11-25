import "dart:async";

import "package:collection/collection.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGroup, SesoriToolGuide;

import "../api/sesori_skill_bundle_storage.dart";
import "../repositories/bridge_settings.dart";
import "../repositories/bridge_settings_repository.dart";

/// Keeps the skill bundle in step with the tool groups that are on: writes
/// it at start, and again whenever a settings change turns a group with a
/// guide on or off.
class SesoriSkillBundleListener({
  required final BridgeSettingsRepository _settings,
  required final List<SesoriToolGroup> _groups,
  required final SesoriSkillBundleStorage _storage,
}) {
  StreamSubscription<void>? _subscription;
  List<SesoriToolGuide>? _written;

  void start() {
    if (_subscription != null) return;
    _write(settings: _settings.currentSettings);
    _subscription = _settings.settingsChanges.listen((change) => _write(settings: change.current));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  void _write({required BridgeSettings settings}) {
    final guides = [
      for (final group in _groups)
        if (group.guide case final guide? when settings.toolGroupEnabled(id: group.id)) guide,
    ];
    if (_written case final written? when const ListEquality<SesoriToolGuide>().equals(written, guides)) return;
    _written = guides;
    try {
      _storage.write(guides: guides);
    } on Object catch (error, stackTrace) {
      // Harnesses then load no Sesori skill and use `get_guide` instead.
      Log.w("Writing the Sesori skill bundle failed", error, stackTrace);
    }
  }
}
