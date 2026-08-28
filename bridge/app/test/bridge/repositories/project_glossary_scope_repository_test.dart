import "dart:io";

import "package:sesori_bridge/src/repositories/models/project_glossary_scope_identity.dart";
import "package:sesori_bridge/src/repositories/project_glossary_scope_repository.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:test/test.dart";

import "../../helpers/fake_git_cli_api.dart";

void main() {
  const projectPath = "/tmp/projects/sesori";

  test("canonicalizes equivalent network remotes to one repository origin", () async {
    for (final remoteUrl in [
      "git@GitHub.com:Sesori-AI/Sesori_Apps_Monorepo.git",
      "https://github.com/sesori-ai/sesori_apps_monorepo.git",
      "ssh://git@github.com:22/SESORI-AI/SESORI_APPS_MONOREPO.git",
      "ssh://git@ssh.github.com:443/SESORI-AI/SESORI_APPS_MONOREPO.git",
    ]) {
      final repository = ProjectGlossaryScopeRepository(
        gitCliApi: FakeGitCliApi(remoteUrl: remoteUrl),
      );

      final identity = await repository.resolveIdentity(projectPath: projectPath);

      expect(
        identity,
        isA<RepositoryProjectGlossaryIdentity>().having(
          (value) => value.canonicalOrigin,
          "canonicalOrigin",
          "github.com/sesori-ai/sesori_apps_monorepo",
        ),
      );
    }
  });

  test("keeps non-default network ports in repository ownership", () async {
    Future<String> resolveOrigin({required String remoteUrl}) async {
      final repository = ProjectGlossaryScopeRepository(
        gitCliApi: FakeGitCliApi(remoteUrl: remoteUrl),
      );
      final identity = await repository.resolveIdentity(projectPath: projectPath);
      if (identity case RepositoryProjectGlossaryIdentity(:final canonicalOrigin)) {
        return canonicalOrigin;
      }
      throw StateError("expected repository identity");
    }

    expect(
      await resolveOrigin(remoteUrl: "ssh://git@code.internal:2222/org/repo.git"),
      "ssh://git@code.internal:2222/org/repo.git",
    );
    expect(
      await resolveOrigin(remoteUrl: "ssh://git@code.internal:3333/org/repo.git"),
      "ssh://git@code.internal:3333/org/repo.git",
    );
    expect(
      await resolveOrigin(remoteUrl: "ssh://git@code.internal:22/Org/Repo.git"),
      "ssh://git@code.internal/Org/Repo.git",
    );
    expect(
      await resolveOrigin(remoteUrl: "alice@code.internal:repo.git"),
      "ssh-relative://alice@code.internal/repo.git",
    );
    expect(
      await resolveOrigin(remoteUrl: "bob@code.internal:repo.git"),
      "ssh-relative://bob@code.internal/repo.git",
    );
  });

  test("uses a normalized absolute path without a network remote", () async {
    final repository = ProjectGlossaryScopeRepository(gitCliApi: FakeGitCliApi());

    final identity = await repository.resolveIdentity(projectPath: "$projectPath/../sesori/.");

    expect(
      identity,
      isA<BridgeLocalProjectGlossaryIdentity>().having(
        (value) => value.normalizedAbsolutePath,
        "normalizedAbsolutePath",
        normalizeProjectDirectory(directory: projectPath),
      ),
    );
  });

  test("treats a filesystem Git remote as bridge-local", () async {
    final repository = ProjectGlossaryScopeRepository(
      gitCliApi: FakeGitCliApi(remoteUrl: "file:///srv/git/sesori.git"),
    );

    final identity = await repository.resolveIdentity(projectPath: projectPath);

    expect(identity, isA<BridgeLocalProjectGlossaryIdentity>());
  });

  test("returns no identity for a missing project path", () async {
    final repository = ProjectGlossaryScopeRepository(
      gitCliApi: FakeGitCliApi(remoteUrl: "https://github.com/sesori-ai/sesori.git"),
    );

    expect(await repository.resolveIdentity(projectPath: "  "), isNull);
  });

  test("keeps operational Git failures observable", () async {
    final repository = ProjectGlossaryScopeRepository(gitCliApi: _ThrowingGitCliApi());

    await expectLater(
      repository.resolveIdentity(projectPath: projectPath),
      throwsA(isA<ProcessException>()),
    );
  });
}

class _ThrowingGitCliApi() extends FakeGitCliApi {
  @override
  Future<String?> getRemoteUrl({required String projectPath}) =>
      throw const ProcessException("git", ["remote"], "temporary failure", 1);
}
