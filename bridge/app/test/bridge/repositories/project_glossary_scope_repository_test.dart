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
      "git@GitHub.com:sesori-ai/sesori_apps_monorepo.git",
      "https://github.com/sesori-ai/sesori_apps_monorepo.git",
      "ssh://git@github.com:22/sesori-ai/sesori_apps_monorepo.git",
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
