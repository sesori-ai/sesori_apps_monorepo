import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginCommand, PluginCommandSource;

import "codex_config_reader.dart";
import "codex_skill_reader.dart";

/// Maps project-scoped Codex skills and configuration metadata.
///
/// codex is a bridge-derived-projects backend, so a project id handed to the
/// plugin IS the normalized project directory. Skill discovery is resolved
/// against that directory; configuration remains sourced from Codex's global
/// config.
class CodexMetadataRepository {
  CodexMetadataRepository({
    required CodexSkillReader skillReader,
    required CodexConfigReader configReader,
    required String launchDirectory,
  }) : _skillReader = skillReader,
       _configReader = configReader,
       _launchDirectory = launchDirectory;

  final CodexSkillReader _skillReader;
  final CodexConfigReader _configReader;
  final String _launchDirectory;

  /// The slash commands (codex skills) available to [projectId]'s project:
  /// user-level skills plus that project directory's own `.codex/skills`.
  ///
  /// A null [projectId] comes from the deprecated project-less commands route
  /// and falls back to the launch directory.
  List<PluginCommand> getCommands({required String? projectId}) {
    final target = normalizeProjectDirectory(directory: projectId ?? _launchDirectory);
    final skills = _skillReader.list(projectCwd: target);
    return [
      for (final skill in skills)
        PluginCommand(
          name: skill.name,
          description: skill.description.isEmpty ? null : skill.description,
          source: PluginCommandSource.skill,
          provider: null,
        ),
    ];
  }

  CodexConfigDefaults readConfigDefaults() => _configReader.readDefaults();
}
