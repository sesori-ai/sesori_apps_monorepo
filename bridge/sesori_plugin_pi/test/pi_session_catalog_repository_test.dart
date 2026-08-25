import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:test/test.dart";

import "support/fake_pi_session_storage_api.dart";

void main() {
  group("PiSessionCatalogRepository", () {
    test("maps metadata, normalizes projects, and sorts newest first", () async {
      final api = FakePiCatalogSessionStorageApi(
        initialSessions: [
          _metadata(id: "older", cwd: "/repo/./app", updated: 10, created: 5),
          _metadata(id: "newer", cwd: "/repo/app/", updated: 20, created: null, title: "Named"),
        ],
      );
      final repository = PiSessionCatalogRepository(storageApi: api);

      final sessions = await repository.listAllSessions(knownDirectories: const {"/repo/app"});

      expect(sessions.map((session) => session.id), ["newer", "older"]);
      expect(sessions.first.projectID, normalizeProjectDirectory(directory: "/repo/app"));
      expect(sessions.first.directory, normalizeProjectDirectory(directory: "/repo/app"));
      expect(sessions.first.title, "Named");
      expect(sessions.first.time?.created, 20);
      expect(sessions.first.time?.updated, 20);
    });

    test("filters by normalized project before applying pagination", () async {
      final repository = PiSessionCatalogRepository(
        storageApi: FakePiCatalogSessionStorageApi(
          initialSessions: [
            _metadata(id: "other", cwd: "/repo/other", updated: 40),
            _metadata(id: "third", cwd: "/repo/app", updated: 30),
            _metadata(id: "second", cwd: "/repo/app", updated: 20),
            _metadata(id: "first", cwd: "/repo/app", updated: 10),
          ],
        ),
      );

      expect(
        (await repository.getSessions(projectId: "/repo/app/.", start: 1, limit: 2)).map((session) => session.id),
        ["second", "first"],
      );
      expect(await repository.getSessions(projectId: "/repo/app", start: 99, limit: 2), isEmpty);
      expect(await repository.getSessions(projectId: "/repo/app", start: 0, limit: 0), isEmpty);
    });

    test("lists direct children using resolved parent ids", () async {
      final repository = PiSessionCatalogRepository(
        storageApi: FakePiCatalogSessionStorageApi(
          initialSessions: [
            _metadata(id: "root", cwd: "/repo", updated: 30),
            _metadata(id: "child", cwd: "/repo", updated: 20, parentId: "root"),
            _metadata(id: "grandchild", cwd: "/repo", updated: 10, parentId: "child"),
          ],
        ),
      );

      expect((await repository.getChildSessions(sessionId: "root")).map((session) => session.id), ["child"]);
    });

    test("resolves the top imported parent and owning worktree project", () async {
      final repository = PiSessionCatalogRepository(
        storageApi: FakePiCatalogSessionStorageApi(
          initialSessions: [
            _metadata(id: "root", cwd: "/repo", updated: 30),
            _metadata(id: "child", cwd: "/repo/worktree", updated: 20, parentId: "root"),
            _metadata(id: "leaf", cwd: "/repo/worktree", updated: 10, parentId: "child"),
          ],
        ),
      );

      final scope = await repository.resolveDisplayScope(sessionId: "leaf");

      expect(scope?.displaySessionId, "root");
      expect(scope?.projectId, normalizeProjectDirectory(directory: "/repo/worktree"));
      expect(await repository.resolveDisplayScope(sessionId: "missing"), isNull);
    });

    test("retains primed attribution as a scan root after metadata appears", () async {
      final api = FakePiCatalogSessionStorageApi(initialSessions: const []);
      final repository = PiSessionCatalogRepository(storageApi: api);
      repository.primeSessionDirectory(sessionId: "pending", directory: "/repo/new/.");

      final pending = await repository.listAllSessions(knownDirectories: const {});
      expect(pending.single.id, "pending");
      expect(pending.single.directory, normalizeProjectDirectory(directory: "/repo/new"));
      expect(pending.single.time, isNull);

      api.sessions = [_metadata(id: "pending", cwd: "/repo/new", updated: 10)];
      final observed = await repository.listAllSessions(knownDirectories: const {});
      expect(observed.single.time?.updated, 10);

      api.sessions = const [];
      await repository.listAllSessions(knownDirectories: const {});
      expect(api.listedKnownDirectories.last, contains(normalizeProjectDirectory(directory: "/repo/new")));
    });

    test("directory priming preserves pending parent lineage", () async {
      final repository = PiSessionCatalogRepository(
        storageApi: FakePiCatalogSessionStorageApi(initialSessions: const []),
      );
      repository.recordPendingSession(
        sessionId: "child",
        directory: "/repo/old",
        parentSessionId: "parent",
      );

      repository.primeSessionDirectory(sessionId: "child", directory: "/repo/new");

      final child = (await repository.listAllSessions(knownDirectories: const {})).single;
      expect(child.directory, normalizeProjectDirectory(directory: "/repo/new"));
      expect(child.parentID, "parent");
    });

    test("propagates storage failures instead of returning an empty catalog", () async {
      final repository = PiSessionCatalogRepository(
        storageApi: FakePiCatalogSessionStorageApi(initialSessions: const [], listError: StateError("scan failed")),
      );

      await expectLater(
        repository.listAllSessions(knownDirectories: const {}),
        throwsA(isA<StateError>()),
      );
    });
  });
}

PiSessionMetadata _metadata({
  required String id,
  required String cwd,
  required int updated,
  int? created,
  String? parentId,
  String? title,
}) => PiSessionMetadata(
  id: id,
  cwd: cwd,
  parentId: parentId,
  title: title,
  createdAt: created == null ? null : DateTime.fromMillisecondsSinceEpoch(created, isUtc: true),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(updated, isUtc: true),
);
