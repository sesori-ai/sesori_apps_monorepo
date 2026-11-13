import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_app_server_api.dart";
import "../api/models/codex_skill_dto.dart";

/// Maps Codex's authoritative app-server skill catalog into plugin commands.
class CodexSkillRepository({required final CodexAppServerApi _appServerApi}) {
  Future<List<PluginCommand>> listCommands({required String cwd}) async {
    final response = await _appServerApi.listSkills(cwd: cwd);
    if (response.data.isEmpty) return const [];
    return [
      for (final skill in response.data.first.skills)
        if (skill.enabled)
          PluginCommand(
            name: skill.name,
            description: _description(skill: skill),
            provider: null,
            source: PluginCommandSource.skill,
          ),
    ];
  }

  /// The `SKILL.md` path of the enabled skill [name] that Codex resolves for
  /// [cwd], or null when it has none.
  Future<String?> findSkillPath({required String cwd, required String name}) async {
    final response = await _appServerApi.listSkills(cwd: cwd);
    if (response.data.isEmpty) return null;
    for (final skill in response.data.first.skills) {
      if (skill.enabled && skill.name == name) return skill.path;
    }
    return null;
  }

  String? _description({required CodexSkillDto skill}) {
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
