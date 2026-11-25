import "package:sesori_shared/sesori_shared.dart" show BridgeToolGroupSetting;
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGroup, SesoriToolGroupId;

import "../repositories/bridge_settings.dart";
import "../repositories/bridge_settings_repository.dart";

/// The master switch and per-group toggles of Sesori's tools, as the
/// settings routes show them.
class ToolGroupSettingsService({
  required final BridgeSettingsRepository _settings,
  required final List<SesoriToolGroup> _groups,
}) {
  Future<List<BridgeToolGroupSetting>> list() async => _describe(settings: await _settings.readCommittedSettings());

  /// Turns Sesori's tools on or off as a whole and returns whether they are
  /// on now. Each group keeps its own switch meanwhile.
  Future<bool> updateAgentTools({required bool enabled}) async =>
      (await _settings.updateAgentTools(enabled: enabled)).agentTools;

  /// Turns the group [id] on or off and returns whether it is on now.
  Future<bool> update({required SesoriToolGroupId id, required bool enabled}) async {
    final committed = await _settings.updateToolGroup(id: id, enabled: enabled);
    return committed.agentToolGroups.isEnabled(id: id);
  }

  List<BridgeToolGroupSetting> _describe({required BridgeSettings settings}) {
    return [
      for (final group in _groups)
        BridgeToolGroupSetting(
          id: group.id.value,
          title: group.title,
          summary: group.summary,
          enabled: settings.agentToolGroups.isEnabled(id: group.id),
        ),
    ];
  }
}
