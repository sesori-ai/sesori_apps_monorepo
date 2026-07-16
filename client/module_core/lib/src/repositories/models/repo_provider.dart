/// Well-known git hosting providers, classified from a remote's hostname.
///
/// Drives provider-specific presentation (brand icons); [other] covers hosts
/// with no recognised provider and remotes whose host is unknown.
enum RepoProvider {
  github,
  gitlab,
  bitbucket,
  other;

  /// Classifies [host] — the lowercased remote hostname as delivered on the
  /// wire — into a provider. Substring matching recognises self-hosted
  /// instances too (`gitlab.company.com`, `github.corp.net`); a `null` host
  /// (no usable remote, or a bridge that predates the field) is [other].
  static RepoProvider fromHost({required String? host}) {
    if (host == null) return RepoProvider.other;
    final normalized = host.toLowerCase();
    if (normalized.contains("github")) return RepoProvider.github;
    if (normalized.contains("gitlab")) return RepoProvider.gitlab;
    if (normalized.contains("bitbucket")) return RepoProvider.bitbucket;
    return RepoProvider.other;
  }
}
