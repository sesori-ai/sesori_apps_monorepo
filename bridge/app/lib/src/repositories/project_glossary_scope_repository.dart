import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../api/git_cli_api.dart";
import "mappers/git_remote_origin_parser.dart";
import "models/project_glossary_scope_identity.dart";

/// Resolves bridge-private repository or local identity material for glossary
/// key derivation. Operational Git failures remain observable to the caller.
class ProjectGlossaryScopeRepository({required final GitCliApi _gitCliApi}) {
  static const GitRemoteOriginParser _remoteOriginParser = GitRemoteOriginParser();

  Future<ProjectGlossaryScopeIdentity?> resolveIdentity({required String projectPath}) async {
    if (projectPath.trim().isEmpty) {
      return null;
    }

    final normalizedPath = normalizeProjectDirectory(directory: projectPath);
    final remoteUrl = await _gitCliApi.getRemoteUrl(projectPath: normalizedPath);
    final canonicalOrigin = remoteUrl == null ? null : _remoteOriginParser.parse(remoteUrl: remoteUrl);
    if (canonicalOrigin != null) {
      return RepositoryProjectGlossaryIdentity(canonicalOrigin: canonicalOrigin);
    }

    return BridgeLocalProjectGlossaryIdentity(normalizedAbsolutePath: normalizedPath);
  }
}
