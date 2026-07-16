/// A git remote's forge identity: the [host] it points at (lowercased, no
/// user info or port) and the forge-style repository [slug] (`org/repo`) on
/// that host. Both are always present together — a remote either has a full
/// forge identity or none.
typedef GitRemoteIdentity = ({String host, String slug});

/// Parses a git remote URL into its forge identity ([GitRemoteIdentity]).
///
/// Handles the shapes git remotes take in practice:
/// - scheme URLs — `https://github.com/org/repo.git`,
///   `ssh://git@github.com:22/org/repo.git`, `git://host/org/repo` — the host
///   is the URI authority's host and the slug is the URI path;
/// - scp-like syntax — `git@github.com:org/repo.git` — the host is the part
///   before the colon (sans `user@`) and the slug is the part after it.
///
/// Anything without a forge-style host + repository path parses to `null`:
/// local filesystem remotes (absolute paths, `file://` URLs, Windows drive
/// paths) and unrecognised syntax. A trailing `.git` and surrounding slashes
/// are stripped from the slug; nested paths (e.g. GitLab subgroups
/// `org/group/repo`) are kept whole. Hosts are case-insensitive per RFC and
/// normalised to lowercase; the slug's case is preserved.
class GitRemoteIdentityParser {
  const GitRemoteIdentityParser();

  /// Remote-URL schemes whose path is a forge-style repository slug.
  /// `file://` is deliberately absent — a filesystem remote has no slug.
  static const Set<String> _forgeSchemes = {"http", "https", "ssh", "git", "git+ssh"};

  /// scp-like remote syntax: `[user@]host:path`. The host part must be at
  /// least two characters with no slashes — a slash means a filesystem path,
  /// and a single character before the colon is a Windows drive letter, not a
  /// host.
  static final RegExp _scpLikeRemote = RegExp(r"^(?:[^@\s]+@)?([^:/\\]{2,}):(.+)$");

  GitRemoteIdentity? parse({required String remoteUrl}) {
    final url = remoteUrl.trim();
    if (url.isEmpty) {
      return null;
    }

    if (url.contains("://")) {
      final uri = Uri.tryParse(url);
      if (uri == null || !_forgeSchemes.contains(uri.scheme) || uri.host.isEmpty) {
        return null;
      }
      // Uri already normalises the host to lowercase and excludes user info
      // and port.
      return _identity(host: uri.host, path: uri.path);
    }

    final scpMatch = _scpLikeRemote.firstMatch(url);
    if (scpMatch != null) {
      return _identity(host: scpMatch.group(1)!.toLowerCase(), path: scpMatch.group(2)!);
    }

    return null;
  }

  GitRemoteIdentity? _identity({required String host, required String path}) {
    final slug = _cleanSlug(path: path);
    if (slug == null) {
      return null;
    }
    return (host: host, slug: slug);
  }

  String? _cleanSlug({required String path}) {
    var slug = path.trim();
    while (slug.startsWith("/")) {
      slug = slug.substring(1);
    }
    while (slug.endsWith("/")) {
      slug = slug.substring(0, slug.length - 1);
    }
    if (slug.endsWith(".git")) {
      slug = slug.substring(0, slug.length - ".git".length);
    }
    while (slug.endsWith("/")) {
      slug = slug.substring(0, slug.length - 1);
    }
    return slug.isEmpty ? null : slug;
  }
}
