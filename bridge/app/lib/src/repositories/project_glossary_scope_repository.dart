import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../api/git_cli_api.dart";
import "mappers/git_remote_identity_parser.dart";
import "models/project_glossary_scope_identity.dart";

/// Resolves bridge-private repository or local identity material for glossary
/// key derivation. Operational Git failures remain observable to the caller.
class ProjectGlossaryScopeRepository({required final GitCliApi _gitCliApi}) {
  static const GitRemoteIdentityParser _remoteIdentityParser = GitRemoteIdentityParser();
  static const Set<String> _caseInsensitiveSlugHosts = {"github.com"};

  Future<ProjectGlossaryScopeIdentity?> resolveIdentity({required String projectPath}) async {
    if (projectPath.trim().isEmpty) {
      return null;
    }

    final normalizedPath = normalizeProjectDirectory(directory: projectPath);
    final remoteUrl = await _gitCliApi.getRemoteUrl(projectPath: normalizedPath);
    final remoteOrigin = remoteUrl == null ? null : _remoteIdentityParser.parseOrigin(remoteUrl: remoteUrl);
    if (remoteOrigin != null) {
      return RepositoryProjectGlossaryIdentity(
        canonicalOrigin: _canonicalOrigin(identity: remoteOrigin),
      );
    }

    return BridgeLocalProjectGlossaryIdentity(normalizedAbsolutePath: normalizedPath);
  }

  String _canonicalOrigin({required GitRemoteOriginIdentity identity}) {
    final host = identity.host.contains(":") ? "[${identity.host}]" : identity.host;
    final authority = identity.port == null ? host : "$host:${identity.port}";
    final slug = _caseInsensitiveSlugHosts.contains(identity.host) ? identity.slug.toLowerCase() : identity.slug;
    return "$authority/$slug";
  }
}
