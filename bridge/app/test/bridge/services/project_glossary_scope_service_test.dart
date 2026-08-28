import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/repositories/models/project_glossary_scope_identity.dart";
import "package:sesori_bridge/src/repositories/project_glossary_scope_repository.dart";
import "package:sesori_bridge/src/services/project_glossary_scope_service.dart";
import "package:test/test.dart";

void main() {
  test("derives an account-partitioned repository scope from canonical origin", () async {
    final service = _service(
      identity: const RepositoryProjectGlossaryIdentity(
        canonicalOrigin: "github.com/sesori-ai/sesori_apps_monorepo",
      ),
      bridgeId: null,
    );

    final scope = await service.resolve(projectPath: "/private/repository/path");

    expect(scope?.toJson(), {
      "type": "repository",
      "projectKey": "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    });
    expect(scope?.toJson().toString(), isNot(contains("/private/repository/path")));
    expect(
      service.cachedProjectKey(projectPath: "/private/repository/path"),
      scope?.projectKey,
    );
  });

  test("derives a bridge-owned local scope from normalized path", () async {
    final service = _service(
      identity: const BridgeLocalProjectGlossaryIdentity(
        normalizedAbsolutePath: "/tmp/projects/sesori",
      ),
      bridgeId: "br_bridge0001",
    );

    final scope = await service.resolve(projectPath: "/ignored/raw/path");

    expect(scope?.toJson(), {
      "type": "bridge_local",
      "projectKey": "prj_v1_gBrBSzNu-bDcQWAcJVHWREq3Mlkj9J6GQoxl2Mlt7LY",
      "bridgeId": "br_bridge0001",
    });
    expect(scope?.toJson().toString(), isNot(contains("/tmp/projects/sesori")));
  });

  test("invalidates a cached local scope when the registered bridge changes", () async {
    final bridgeIdProvider = _FakeBridgeIdProvider(bridgeId: "br_bridge0001");
    final service = ProjectGlossaryScopeService(
      repository: _FakeProjectGlossaryScopeRepository(
        identity: const BridgeLocalProjectGlossaryIdentity(
          normalizedAbsolutePath: "/tmp/projects/sesori",
        ),
      ),
      bridgeIdProvider: bridgeIdProvider,
    );

    final scope = await service.resolve(projectPath: "/tmp/projects/sesori");
    expect(service.cachedProjectKey(projectPath: "/tmp/projects/sesori"), scope?.projectKey);

    bridgeIdProvider.bridgeId = "br_bridge0002";

    expect(service.cachedProjectKey(projectPath: "/tmp/projects/sesori"), isNull);
  });

  test("returns no local scope before bridge registration", () async {
    final service = _service(
      identity: const BridgeLocalProjectGlossaryIdentity(
        normalizedAbsolutePath: "/tmp/projects/sesori",
      ),
      bridgeId: null,
    );

    expect(await service.resolve(projectPath: "/tmp/projects/sesori"), isNull);
  });

  test("returns no scope when project identity is unavailable", () async {
    final service = _service(identity: null, bridgeId: "br_bridge0001");

    expect(await service.resolve(projectPath: ""), isNull);
  });
}

ProjectGlossaryScopeService _service({
  required ProjectGlossaryScopeIdentity? identity,
  required String? bridgeId,
}) {
  return ProjectGlossaryScopeService(
    repository: _FakeProjectGlossaryScopeRepository(identity: identity),
    bridgeIdProvider: _FakeBridgeIdProvider(bridgeId: bridgeId),
  );
}

class _FakeProjectGlossaryScopeRepository({required final ProjectGlossaryScopeIdentity? identity})
    implements ProjectGlossaryScopeRepository {
  @override
  Future<ProjectGlossaryScopeIdentity?> resolveIdentity({required String projectPath}) async => identity;
}

class _FakeBridgeIdProvider({@override required var String? bridgeId}) implements BridgeIdProvider;
