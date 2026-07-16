/// Parses a git remote URL into a forge-style repository slug (`org/repo`).
///
/// Handles the shapes git remotes take in practice:
/// - scheme URLs — `https://github.com/org/repo.git`,
///   `ssh://git@github.com:22/org/repo.git`, `git://host/org/repo` — the slug
///   is the URI path;
/// - scp-like syntax — `git@github.com:org/repo.git` — the slug is the part
///   after the colon.
///
/// Anything without a forge-style repository path parses to `null`: local
/// filesystem remotes (absolute paths, `file://` URLs, Windows drive paths)
/// and unrecognised syntax. A trailing `.git` and surrounding slashes are
/// stripped; nested paths (e.g. GitLab subgroups `org/group/repo`) are kept
/// whole.
class GitRemoteSlugParser {
  const GitRemoteSlugParser();

  /// Remote-URL schemes whose path is a forge-style repository slug.
  /// `file://` is deliberately absent — a filesystem remote has no slug.
  static const Set<String> _forgeSchemes = {"http", "https", "ssh", "git", "git+ssh"};

  /// scp-like remote syntax: `[user@]host:path`. The host part must be at
  /// least two characters with no slashes — a slash means a filesystem path,
  /// and a single character before the colon is a Windows drive letter, not a
  /// host.
  static final RegExp _scpLikeRemote = RegExp(r"^(?:[^@\s]+@)?[^:/\\]{2,}:(.+)$");

  String? parse({required String remoteUrl}) {
    final url = remoteUrl.trim();
    if (url.isEmpty) {
      return null;
    }

    if (url.contains("://")) {
      final uri = Uri.tryParse(url);
      if (uri == null || !_forgeSchemes.contains(uri.scheme)) {
        return null;
      }
      return _cleanSlug(path: uri.path);
    }

    final scpMatch = _scpLikeRemote.firstMatch(url);
    if (scpMatch != null) {
      return _cleanSlug(path: scpMatch.group(1)!);
    }

    return null;
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
