import "package:sesori_bridge/src/repositories/mappers/git_remote_origin_parser.dart";
import "package:test/test.dart";

void main() {
  const parser = GitRemoteOriginParser();

  test("canonicalizes known GitHub transport aliases", () {
    for (final remoteUrl in [
      "git@GitHub.com:Sesori-AI/Sesori_Apps_Monorepo.git",
      "https://github.com/sesori-ai/sesori_apps_monorepo.git",
      "http://github.com/SESORI-AI/SESORI_APPS_MONOREPO.git",
      "ssh://git@github.com:22/SESORI-AI/SESORI_APPS_MONOREPO.git",
      "ssh://git@ssh.github.com:443/SESORI-AI/SESORI_APPS_MONOREPO.git",
      "git://github.com/sesori-ai/sesori_apps_monorepo.git",
    ]) {
      expect(
        parser.parse(remoteUrl: remoteUrl),
        "github.com/sesori-ai/sesori_apps_monorepo",
      );
    }
  });

  test("keeps unknown protocols as distinct ownership endpoints", () {
    final origins = {
      for (final remoteUrl in [
        "http://code.internal/repo.git",
        "https://code.internal/repo.git",
        "ssh://git@code.internal/repo.git",
        "git://code.internal/repo.git",
      ])
        parser.parse(remoteUrl: remoteUrl),
    };

    expect(origins, hasLength(4));
  });

  test("canonicalizes Git SSH scheme aliases", () {
    expect(
      parser.parse(remoteUrl: "ssh://git@code.internal/repo.git"),
      parser.parse(remoteUrl: "git+ssh://git@code.internal/repo.git"),
    );
  });

  test("normalizes explicit default ports within one protocol", () {
    expect(
      parser.parse(remoteUrl: "https://code.internal:443/repo.git"),
      parser.parse(remoteUrl: "https://code.internal/repo.git"),
    );
    expect(
      parser.parse(remoteUrl: "ssh://git@code.internal:22/repo.git"),
      parser.parse(remoteUrl: "ssh://git@code.internal/repo.git"),
    );
  });

  test("keeps non-default network ports in ownership identity", () {
    expect(
      parser.parse(remoteUrl: "ssh://git@code.internal:2222/repo.git"),
      "ssh://git@code.internal:2222/repo.git",
    );
    expect(
      parser.parse(remoteUrl: "ssh://git@code.internal:3333/repo.git"),
      "ssh://git@code.internal:3333/repo.git",
    );
  });

  test("retains SSH users for generic server ownership", () {
    expect(
      parser.parse(remoteUrl: "alice@code.internal:repo.git"),
      "ssh-relative://alice@code.internal/repo.git",
    );
    expect(
      parser.parse(remoteUrl: "bob@code.internal:repo.git"),
      "ssh-relative://bob@code.internal/repo.git",
    );
    expect(
      parser.parse(remoteUrl: "alice@code.internal:/srv/repo.git"),
      "ssh://alice@code.internal/srv/repo.git",
    );
    expect(
      parser.parse(remoteUrl: "bob@code.internal:/srv/repo.git"),
      "ssh://bob@code.internal/srv/repo.git",
    );
  });

  test("preserves exact generic repository path suffixes", () {
    expect(
      parser.parse(remoteUrl: "https://code.internal/srv/repo"),
      "https://code.internal/srv/repo",
    );
    expect(
      parser.parse(remoteUrl: "https://code.internal/srv/repo.git"),
      "https://code.internal/srv/repo.git",
    );
  });

  test("rejects remotes without a network repository origin", () {
    for (final remoteUrl in [
      "file:///Users/dev/repo",
      "ftp://host.xz/org/repo.git",
      "/Users/dev/repo",
      "../relative/repo",
      "repo",
      r"C:\Users\dev\repo",
      "C:/Users/dev/repo",
      "",
      "   ",
      "https://github.com/",
      "https:///org/repo",
    ]) {
      expect(parser.parse(remoteUrl: remoteUrl), isNull);
    }
  });
}
