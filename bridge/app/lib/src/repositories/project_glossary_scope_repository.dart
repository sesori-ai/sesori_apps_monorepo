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
    var host = identity.host;
    var port = identity.port;
    var user = identity.user;
    if (host == "ssh.github.com" && port == 443) {
      host = "github.com";
      port = null;
      user = null;
    } else if (host == "github.com") {
      user = null;
    }

    final formattedHost = host.contains(":") ? "[$host]" : host;
    final hostAndPort = port == null ? formattedHost : "$formattedHost:$port";
    final authority = user == null ? hostAndPort : "$user@$hostAndPort";
    final slug = _caseInsensitiveSlugHosts.contains(host) ? identity.slug.toLowerCase() : identity.slug;
    return "$authority/$slug";
  }
}
