import "package:sesori_bridge/src/bridge/repositories/mappers/git_remote_identity_parser.dart";
import "package:test/test.dart";

void main() {
  group("GitRemoteIdentityParser", () {
    const parser = GitRemoteIdentityParser();

    const cases = <String, GitRemoteIdentity?>{
      // Scheme URLs.
      "https://github.com/org/repo.git": (host: "github.com", slug: "org/repo"),
      "https://github.com/org/repo": (host: "github.com", slug: "org/repo"),
      "https://github.com/org/repo/": (host: "github.com", slug: "org/repo"),
      "https://github.com/org/repo.git/": (host: "github.com", slug: "org/repo"),
      "http://code.internal/org/repo.git": (host: "code.internal", slug: "org/repo"),
      "ssh://git@github.com/org/repo.git": (host: "github.com", slug: "org/repo"),
      "ssh://git@github.com:2222/org/repo.git": (host: "github.com", slug: "org/repo"),
      "git://host.xz/org/repo.git": (host: "host.xz", slug: "org/repo"),
      "git+ssh://git@host.xz/org/repo.git": (host: "host.xz", slug: "org/repo"),
      // Hosts normalise to lowercase; the slug's case is preserved.
      "HTTPS://GitHub.COM/Org/Repo.git": (host: "github.com", slug: "Org/Repo"),
      // scp-like syntax.
      "git@github.com:org/repo.git": (host: "github.com", slug: "org/repo"),
      "git@gitlab.com:org/group/repo.git": (host: "gitlab.com", slug: "org/group/repo"),
      "deploy@host.internal:repo.git": (host: "host.internal", slug: "repo"),
      "host.xz:/srv/git/repo.git": (host: "host.xz", slug: "srv/git/repo"),
      "Git@GitHub.com:Org/Repo.git": (host: "github.com", slug: "Org/Repo"),
      // No forge identity.
      "file:///Users/dev/repo": null,
      "ftp://host.xz/org/repo.git": null,
      "/Users/dev/repo": null,
      "../relative/repo": null,
      "repo": null,
      r"C:\Users\dev\repo": null,
      "C:/Users/dev/repo": null,
      "": null,
      "   ": null,
      "https://github.com/": null,
      "https:///org/repo": null,
    };

    for (final MapEntry(key: url, value: identity) in cases.entries) {
      test(
        "parses ${url.isEmpty
            ? "<empty>"
            : url.trim().isEmpty
            ? "<blank>"
            : url} to ${identity == null ? "null" : "${identity.slug} at ${identity.host}"}",
        () {
          expect(parser.parse(remoteUrl: url), equals(identity));
        },
      );
    }
  });
}
