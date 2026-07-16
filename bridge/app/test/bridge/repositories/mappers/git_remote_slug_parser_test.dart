import "package:sesori_bridge/src/bridge/repositories/mappers/git_remote_slug_parser.dart";
import "package:test/test.dart";

void main() {
  group("GitRemoteSlugParser", () {
    const parser = GitRemoteSlugParser();

    const cases = <String, String?>{
      // Scheme URLs.
      "https://github.com/org/repo.git": "org/repo",
      "https://github.com/org/repo": "org/repo",
      "https://github.com/org/repo/": "org/repo",
      "https://github.com/org/repo.git/": "org/repo",
      "http://code.internal/org/repo.git": "org/repo",
      "ssh://git@github.com/org/repo.git": "org/repo",
      "ssh://git@github.com:2222/org/repo.git": "org/repo",
      "git://host.xz/org/repo.git": "org/repo",
      "git+ssh://git@host.xz/org/repo.git": "org/repo",
      // scp-like syntax.
      "git@github.com:org/repo.git": "org/repo",
      "git@gitlab.com:org/group/repo.git": "org/group/repo",
      "deploy@host.internal:repo.git": "repo",
      "host.xz:/srv/git/repo.git": "srv/git/repo",
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
    };

    for (final MapEntry(key: url, value: slug) in cases.entries) {
      test(
        "parses ${url.isEmpty
            ? "<empty>"
            : url.trim().isEmpty
            ? "<blank>"
            : url} to ${slug ?? "null"}",
        () {
          expect(parser.parse(remoteUrl: url), equals(slug));
        },
      );
    }
  });
}
