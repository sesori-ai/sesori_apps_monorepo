import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_shared/sesori_shared.dart";

import "../auth/bridge_id_provider.dart";

/// Tracks the latest resolved glossary scope for each normalized project path.
class ProjectGlossaryScopeTracker({
  required final BridgeIdProvider _bridgeIdProvider,
}) {
  final Map<String, ProjectGlossaryScope> _scopeByProjectPath = {};

  void record({
    required String projectPath,
    required ProjectGlossaryScope? scope,
  }) {
    if (projectPath.trim().isEmpty) return;
    final normalizedPath = normalizeProjectDirectory(directory: projectPath);
    if (scope == null) {
      _scopeByProjectPath.remove(normalizedPath);
    } else {
      _scopeByProjectPath[normalizedPath] = scope;
    }
  }

  ProjectGlossaryKey? projectKeyFor({required String projectPath}) {
    if (projectPath.trim().isEmpty) return null;
    final normalizedPath = normalizeProjectDirectory(directory: projectPath);
    final scope = _scopeByProjectPath[normalizedPath];
    return switch (scope) {
      RepositoryProjectGlossaryScope(:final projectKey) => projectKey,
      BridgeLocalProjectGlossaryScope(:final projectKey, :final bridgeId) when bridgeId == _bridgeIdProvider.bridgeId =>
        projectKey,
      BridgeLocalProjectGlossaryScope() => () {
        _scopeByProjectPath.remove(normalizedPath);
        return null;
      }(),
      null => null,
    };
  }
}
