import "dart:async";
import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
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

  group("PiSessionCatalogRepository cache", () {
    late _DiskFixture disk;
    late PiSessionCatalogRepository repository;

    setUp(() {
      disk = _DiskFixture();
      repository = PiSessionCatalogRepository(storageApi: disk.api);
    });
    tearDown(() => disk.dispose());

    test("an unchanged rescan reads no file and a rename re-reads only that file", () async {
      final renamed = disk.writeSession(id: "renamed");
      disk.writeSession(id: "untouched");

      await repository.listAllSessions(knownDirectories: const {});
      expect(disk.api.scans.last.parsed, hasLength(2));

      final unchanged = await repository.listAllSessions(knownDirectories: const {});
      expect(disk.api.scans.last.parsed, isEmpty);
      expect(unchanged.map((session) => session.id), unorderedEquals(["renamed", "untouched"]));

      disk.append(path: renamed, record: {"type": "session_info", "name": "New name"});
      final afterRename = await repository.listAllSessions(knownDirectories: const {});
      expect(disk.api.scans.last.parsed.keys, [File(renamed).resolveSymbolicLinksSync()]);
      expect(afterRename.firstWhere((session) => session.id == "renamed").title, "New name");
    });

    test("a deleted file is evicted", () async {
      final deleted = disk.writeSession(id: "deleted");
      disk.writeSession(id: "kept");
      await repository.listAllSessions(knownDirectories: const {});

      File(deleted).deleteSync();
      final sessions = await repository.listAllSessions(knownDirectories: const {});

      expect(sessions.map((session) => session.id), ["kept"]);
      expect(repository.sessionSnapshot.keys, ["kept"]);
    });

    test("a lookup hit does not scan and a miss rescans once", () async {
      final path = disk.writeSession(id: "known");
      await repository.listAllSessions(knownDirectories: const {});
      final scans = disk.api.scans.length;

      expect((await repository.findSessionById(sessionId: "known"))?.id, "known");
      expect(
        (await repository.resolveSession(sessionId: "known", knownDirectories: const {}))?.path,
        File(path).resolveSymbolicLinksSync(),
      );
      expect(disk.api.scans, hasLength(scans));

      expect(await repository.findSessionById(sessionId: "missing"), isNull);
      expect(disk.api.scans, hasLength(scans + 1));
    });

    test("calls during a scan share one follow-up scan", () async {
      disk.writeSession(id: "session");
      final gate = Completer<void>();
      disk.api.gate = gate;
      final first = repository.listAllSessions(knownDirectories: const {});
      await disk.api.waitForScans(count: 1);
      disk.api.gate = null;

      final second = repository.listAllSessions(knownDirectories: const {});
      final third = repository.findSessionById(sessionId: "missing");
      gate.complete();
      await Future.wait([first, second, third]);

      expect(disk.api.scans, hasLength(2));
    });

    test("a delete during a running scan does not bring the session back", () async {
      final path = disk.writeSession(id: "deleted");
      await repository.listAllSessions(knownDirectories: const {});
      // A changed file makes the running scan read it again.
      disk.append(path: path, record: {"type": "session_info", "name": "Changed"});
      final gate = Completer<void>();
      disk.api.gate = gate;
      final listing = repository.listAllSessions(knownDirectories: const {});
      await disk.api.waitForScans(count: 2);
      expect(disk.api.scans.last.parsed, hasLength(1));

      await repository.deleteSession(sessionId: "deleted", directory: null);
      gate.complete();

      expect(await listing, isEmpty);
      expect(File(path).existsSync(), isFalse);
      expect(repository.sessionSnapshot, isEmpty);
    });
  });
}

final class _DiskFixture() {
  final Directory root = Directory.systemTemp.createTempSync("pi-session-catalog-");
  late final String sessions = (Directory(p.join(root.path, "sessions"))..createSync()).path;
  late final String project = (Directory(p.join(root.path, "project"))..createSync()).path;
  late final _ScanRecordingStorageApi api = _ScanRecordingStorageApi(
    environment: {
      "HOME": p.join(root.path, "home"),
      "PI_CODING_AGENT_DIR": p.join(root.path, "agent"),
      "PI_CODING_AGENT_SESSION_DIR": sessions,
    },
  );

  String writeSession({required String id}) {
    final path = p.join(sessions, "$id.jsonl");
    File(path).writeAsStringSync(
      "${jsonEncode({"type": "session", "version": 3, "id": id, "timestamp": "2026-08-01T00:00:00Z", "cwd": project})}\n",
    );
    return path;
  }

  void append({required String path, required Map<String, Object?> record}) =>
      File(path).writeAsStringSync("${jsonEncode(record)}\n", mode: FileMode.append);

  void dispose() => root.deleteSync(recursive: true);
}

/// The real storage API, recording each scan and optionally holding it before
/// the catalog merges it.
final class _ScanRecordingStorageApi({required super.environment}) extends PiSessionStorageApi {
  final List<PiSessionFileScan> scans = [];
  Completer<void>? gate;

  @override
  Future<PiSessionFileScan> scanSessionFiles({
    required Set<String> knownDirectories,
    required Map<String, PiKnownSessionFile> known,
  }) async {
    final held = gate;
    final scan = await super.scanSessionFiles(knownDirectories: knownDirectories, known: known);
    scans.add(scan);
    await held?.future;
    return scan;
  }

  Future<void> waitForScans({required int count}) async {
    for (var attempt = 0; attempt < 500 && scans.length < count; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(scans, hasLength(count));
  }
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
