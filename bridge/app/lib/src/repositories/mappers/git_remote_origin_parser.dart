/// Canonicalizes a Git remote for ownership-sensitive glossary scoping.
///
/// Known GitHub transport aliases collapse to one forge origin. Unknown hosts
/// retain protocol, endpoint, SSH account, and exact repository path so the
/// bridge never merges repositories without evidence that they are equivalent.
class const GitRemoteOriginParser() {
  static const Set<String> _gitSchemes = {"http", "https", "ssh", "git", "git+ssh"};
  static const Set<String> _sshSchemes = {"ssh", "git+ssh"};
  static const Map<String, int> _defaultPorts = {
    "http": 80,
    "https": 443,
    "ssh": 22,
    "git": 9418,
    "git+ssh": 22,
  };
  static final RegExp _scpLikeRemote = RegExp(r"^(?:([^@\s]+)@)?([^:/\\]{2,}):(.+)$");

  String? parse({required String remoteUrl}) {
    final value = remoteUrl.trim();
    if (value.isEmpty) return null;

    if (value.contains("://")) {
      final uri = Uri.tryParse(value);
      if (uri == null || !_gitSchemes.contains(uri.scheme) || uri.host.isEmpty) return null;
      if (!_hasRepositoryPath(path: uri.path)) return null;

      final githubOrigin = _parseGithubUri(uri: uri);
      return githubOrigin ?? _canonicalizeGenericUri(uri: uri);
    }

    final match = _scpLikeRemote.firstMatch(value);
    if (match == null) return null;
    final user = match.group(1);
    final host = match.group(2)!.toLowerCase();
    final path = match.group(3)!;
    if (!_hasRepositoryPath(path: path)) return null;

    if (host == "github.com") {
      return _githubOrigin(path: path);
    }
    return _canonicalizeGenericSsh(user: user, host: host, path: path);
  }

  String? _parseGithubUri({required Uri uri}) {
    final defaultPort = _defaultPorts[uri.scheme];
    final usesDefaultEndpoint = !uri.hasPort || uri.port == defaultPort;
    if (uri.host == "github.com" && usesDefaultEndpoint) {
      return _githubOrigin(path: uri.path);
    }
    if (uri.host == "ssh.github.com" && _sshSchemes.contains(uri.scheme) && uri.port == 443) {
      return _githubOrigin(path: uri.path);
    }
    return null;
  }

  String? _githubOrigin({required String path}) {
    var slug = path.trim().toLowerCase();
    while (slug.startsWith("/")) {
      slug = slug.substring(1);
    }
    while (slug.endsWith("/")) {
      slug = slug.substring(0, slug.length - 1);
    }
    if (slug.endsWith(".git")) {
      slug = slug.substring(0, slug.length - ".git".length);
    }
    return slug.isEmpty ? null : "github.com/$slug";
  }

  String _canonicalizeGenericUri({required Uri uri}) {
    final defaultPort = _defaultPorts[uri.scheme];
    final port = uri.hasPort && uri.port != defaultPort ? uri.port : null;
    return Uri(
      scheme: uri.scheme,
      userInfo: _username(userInfo: uri.userInfo),
      host: uri.host,
      port: port,
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
    ).toString();
  }

  String _canonicalizeGenericSsh({
    required String? user,
    required String host,
    required String path,
  }) {
    final absolute = path.startsWith("/");
    return Uri(
      scheme: absolute ? "ssh" : "ssh-relative",
      userInfo: user,
      host: host,
      path: absolute ? path : "/$path",
    ).toString();
  }

  String? _username({required String userInfo}) {
    if (userInfo.isEmpty) return null;
    final separator = userInfo.indexOf(":");
    final username = separator < 0 ? userInfo : userInfo.substring(0, separator);
    return username.isEmpty ? null : username;
  }

  bool _hasRepositoryPath({required String path}) => path.replaceAll("/", "").isNotEmpty;
}
