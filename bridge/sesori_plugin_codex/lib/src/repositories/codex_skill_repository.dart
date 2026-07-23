import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_app_server_api.dart";
import "../api/models/codex_skill_dto.dart";

/// Maps Codex's authoritative app-server skill catalog into plugin commands.
class CodexSkillRepository {
  CodexSkillRepository({required CodexAppServerApi appServerApi}) : _appServerApi = appServerApi;

  final CodexAppServerApi _appServerApi;

  Future<List<PluginCommand>> listCommands({required String cwd}) async {
    final response = await _appServerApi.listSkills(cwd: cwd);
    CodexSkillsListEntryDto? entry;
    for (final item in response.data) {
      if (item.cwd == cwd) {
        entry = item;
        break;
      }
    }
    if (entry == null && response.data.isNotEmpty) entry = response.data.first;
    if (entry == null) return const [];
    return [
      for (final skill in entry.skills)
        if (skill.enabled)
          PluginCommand(
            name: skill.name,
            description: _description(skill),
            provider: null,
            source: PluginCommandSource.skill,
          ),
    ];
  }

  String? _description(CodexSkillDto skill) {
    for (final value in [
      skill.interface?.shortDescription,
      skill.shortDescription,
      skill.description,
    ]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
