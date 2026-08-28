typedef _ScpRemote = ({String? user, String host, String path});

/// Canonicalizes a Git remote for ownership-sensitive glossary scoping.
///
/// Known GitHub transport aliases collapse to one forge origin. Unknown hosts
/// retain protocol, endpoint, SSH account, and exact repository target so the
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
  static final RegExp _bracketedScpRemote = RegExp(r"^(?:([^@\s]+)@)?\[([^\]\s]+)\]:(.+)$");
  static final RegExp _scpLikeRemote = RegExp(r"^(?:([^@\s]+)@)?([^:/\\\s]+):(.+)$");
  static final RegExp _windowsDrivePath = RegExp(r"^[A-Za-z]:[\\/]");

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

    final scpRemote = _parseScpRemote(value: value);
    if (scpRemote == null || !_hasRepositoryPath(path: scpRemote.path)) return null;

    if (scpRemote.host == "github.com") {
      return _githubOrigin(path: scpRemote.path);
    }
    return _canonicalizeGenericSsh(
      user: scpRemote.user,
      host: scpRemote.host,
      path: scpRemote.path,
    );
  }

  _ScpRemote? _parseScpRemote({required String value}) {
    if (_windowsDrivePath.hasMatch(value)) return null;
    final bracketed = _bracketedScpRemote.firstMatch(value);
    if (bracketed != null) {
      return (
        user: bracketed.group(1),
        host: bracketed.group(2)!.toLowerCase(),
        path: bracketed.group(3)!,
      );
    }
    final regular = _scpLikeRemote.firstMatch(value);
    if (regular == null) return null;
    return (
      user: regular.group(1),
      host: regular.group(2)!.toLowerCase(),
      path: regular.group(3)!,
    );
  }

  String? _parseGithubUri({required Uri uri}) {
    if (uri.hasQuery || uri.hasFragment) return null;
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
    final scheme = uri.scheme == "git+ssh" ? "ssh" : uri.scheme;
    final defaultPort = _defaultPorts[scheme];
    final port = uri.hasPort && uri.port != defaultPort ? uri.port : null;
    return Uri(
      scheme: scheme,
      userInfo: _username(userInfo: uri.userInfo),
      host: uri.host,
      port: port,
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
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
