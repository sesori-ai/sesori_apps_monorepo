import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginCommand, PluginCommandSource;

import "codex_config_reader.dart";
import "codex_skill_reader.dart";
import "session_rollout_reader.dart";

/// Project-scoped codex metadata: slash commands (skills) and model/provider
/// defaults.
///
/// codex is a bridge-derived-projects backend, so a project id handed to the
/// plugin IS the normalized project directory. Everything here is resolved
/// against that directory — a derived project outside the launch cwd gets its
/// own `.codex/skills` and its own most-recent-session model defaults instead
/// of inheriting the launch project's.
class CodexMetadataRepository {
  CodexMetadataRepository({
    required CodexSkillReader skillReader,
    required SessionRolloutReader rolloutReader,
    required CodexConfigReader configReader,
    required String launchDirectory,
  }) : _skillReader = skillReader,
       _rolloutReader = rolloutReader,
       _configReader = configReader,
       _launchDirectory = launchDirectory;

  final CodexSkillReader _skillReader;
  final SessionRolloutReader _rolloutReader;
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

  /// Resolves the model/provider defaults for [projectId]'s project.
  ///
  /// Codex exposes no agent/provider API, so this derives from local state:
  /// the project's most recent session rollout (per-session accurate) wins,
  /// then the global `config.toml`, then `openai` as a last-resort provider.
  /// Sessions are matched to the project by their normalized cwd — a record
  /// with no cwd falls back to the launch directory, the same grouping rule
  /// the session listing uses. A session running in a subdirectory of the
  /// project also counts as the project's: the bridge runs dedicated-worktree
  /// sessions inside the project tree (`<project>/.worktrees/<name>`) while
  /// attributing them to the parent project, so a strict-equality match would
  /// skip the project's newest sessions and hand back stale defaults. The
  /// within-tree rule intentionally avoids coupling to the bridge's worktree
  /// naming; a nested distinct project matching its outer project too is an
  /// accepted trade-off for a "most recent model in this project" heuristic.
  ({String? modelID, String providerID}) resolveModelDefaults({
    required String projectId,
  }) {
    final config = _configReader.readDefaults();
    final target = normalizeProjectDirectory(directory: projectId);
    CodexSessionRecord? latest;
    // listSessions() is sorted newest-first, so the first match is the
    // project's most recent session.
    for (final record in _rolloutReader.listSessions()) {
      final directory = normalizeProjectDirectory(directory: record.cwd ?? _launchDirectory);
      if (directory == target || p.isWithin(target, directory)) {
        latest = record;
        break;
      }
    }
    return (
      modelID: latest?.model ?? config.model,
      providerID: latest?.modelProvider ?? config.modelProvider ?? "openai",
    );
  }

  /// Selects the picker's preselected model for a project given the live
  /// catalog: the project's own most recent model (the [resolveModelDefaults]
  /// result) wins when it is still in the catalog — keeping the provider
  /// picker consistent with the project-scoped default the agent list
  /// resolves — then codex's live default, then the first catalog model.
  /// Returns null only for an empty catalog.
  String? selectCatalogDefaultModel({
    required String? scopedModelID,
    required List<String> catalogModelIds,
    required String? catalogDefaultId,
  }) {
    if (scopedModelID != null && catalogModelIds.contains(scopedModelID)) {
      return scopedModelID;
    }
    if (catalogDefaultId != null) return catalogDefaultId;
    return catalogModelIds.isEmpty ? null : catalogModelIds.first;
  }
}
