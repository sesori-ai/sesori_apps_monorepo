import "dart:convert";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_shared/sesori_shared.dart";

import "../auth/bridge_id_provider.dart";
import "../repositories/models/project_glossary_scope_identity.dart";
import "../repositories/project_glossary_scope_repository.dart";

/// Derives the exact opaque auth scope for a local project without exposing its
/// network origin or filesystem path outside the bridge.
class ProjectGlossaryScopeService({
  required final ProjectGlossaryScopeRepository _repository,
  required final BridgeIdProvider _bridgeIdProvider,
}) {
  static const String _repositoryDomain = "sesori-repo-glossary-v1\u0000";
  static const String _bridgeLocalDomain = "sesori-local-glossary-v1\u0000";
  static const String _keyPrefix = "prj_v1_";

  final Map<String, ProjectGlossaryScope> _scopeByProjectPath = {};

  ProjectGlossaryKey? cachedProjectKey({required String projectPath}) {
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

  Future<ProjectGlossaryScope?> resolve({required String projectPath}) async {
    if (projectPath.trim().isEmpty) return null;
    final normalizedPath = normalizeProjectDirectory(directory: projectPath);
    final identity = await _repository.resolveIdentity(projectPath: normalizedPath);
    final scope = switch (identity) {
      RepositoryProjectGlossaryIdentity(:final canonicalOrigin) => ProjectGlossaryScope.repository(
        projectKey: await _calculateKey(input: "$_repositoryDomain$canonicalOrigin"),
      ),
      BridgeLocalProjectGlossaryIdentity(:final normalizedAbsolutePath) => await _resolveBridgeLocal(
        normalizedAbsolutePath: normalizedAbsolutePath,
      ),
      null => null,
    };
    if (scope == null) {
      _scopeByProjectPath.remove(normalizedPath);
    } else {
      _scopeByProjectPath[normalizedPath] = scope;
    }
    return scope;
  }

  Future<ProjectGlossaryScope?> _resolveBridgeLocal({required String normalizedAbsolutePath}) async {
    final bridgeId = _bridgeIdProvider.bridgeId;
    if (bridgeId == null) {
      return null;
    }

    return ProjectGlossaryScope.bridgeLocal(
      projectKey: await _calculateKey(input: "$_bridgeLocalDomain$bridgeId\u0000$normalizedAbsolutePath"),
      bridgeId: bridgeId,
    );
  }

  Future<ProjectGlossaryKey> _calculateKey({required String input}) async {
    final digest = await calculateSha256(message: utf8.encode(input));
    final encoded = base64UrlEncode(digest).replaceAll("=", "");
    return ProjectGlossaryKey.parse(value: "$_keyPrefix$encoded");
  }
}
