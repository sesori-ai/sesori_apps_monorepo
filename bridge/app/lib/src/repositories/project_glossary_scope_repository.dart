import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../api/git_cli_api.dart";
import "mappers/git_remote_identity_parser.dart";
import "models/project_glossary_scope_identity.dart";

/// Resolves bridge-private repository or local identity material for glossary
/// key derivation. Operational Git failures remain observable to the caller.
class ProjectGlossaryScopeRepository({required final GitCliApi _gitCliApi}) {
  static const GitRemoteIdentityParser _remoteIdentityParser = GitRemoteIdentityParser();

  Future<ProjectGlossaryScopeIdentity?> resolveIdentity({required String projectPath}) async {
    if (projectPath.trim().isEmpty) {
      return null;
    }

    final normalizedPath = normalizeProjectDirectory(directory: projectPath);
    final remoteUrl = await _gitCliApi.getRemoteUrl(projectPath: normalizedPath);
    final remoteIdentity = remoteUrl == null ? null : _remoteIdentityParser.parse(remoteUrl: remoteUrl);
    if (remoteIdentity != null) {
      return RepositoryProjectGlossaryIdentity(
        canonicalOrigin: "${remoteIdentity.host}/${remoteIdentity.slug}",
      );
    }

    return BridgeLocalProjectGlossaryIdentity(normalizedAbsolutePath: normalizedPath);
  }
}
