import "package:sesori_dart_core/src/repositories/models/repo_provider.dart";
import "package:test/test.dart";

void main() {
  group("RepoProvider.fromHost", () {
    const cases = <String?, RepoProvider>{
      "github.com": RepoProvider.github,
      "gitlab.com": RepoProvider.gitlab,
      "bitbucket.org": RepoProvider.bitbucket,
      // Self-hosted instances are recognised by substring.
      "github.corp.net": RepoProvider.github,
      "gitlab.company.com": RepoProvider.gitlab,
      "bitbucket.internal": RepoProvider.bitbucket,
      // Defensive: the wire host is already lowercase, but classification
      // must not depend on it.
      "GitHub.com": RepoProvider.github,
      // Unrecognised or unknown hosts.
      "codeberg.org": RepoProvider.other,
      "git.sr.ht": RepoProvider.other,
      "code.internal": RepoProvider.other,
      null: RepoProvider.other,
    };

    for (final MapEntry(key: host, value: provider) in cases.entries) {
      test("classifies ${host ?? "<null>"} as $provider", () {
        expect(RepoProvider.fromHost(host: host), equals(provider));
      });
    }
  });
}
