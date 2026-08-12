import "package:acp_plugin/acp_plugin.dart";
import "package:omp_plugin/src/repositories/omp_session_cleanup_repository.dart";
import "package:omp_plugin/src/services/omp_session_cleanup_service.dart";
import "package:test/test.dart";

void main() {
  test("pages until found then resumes, deletes, closes, and settles", () async {
    final repository = _FakeCleanupRepository(
      pages: [
        OmpCleanupPage(sessions: const [], nextCursor: "next"),
        OmpCleanupPage(
          sessions: [
            const OmpCleanupSession(
              sessionId: "target",
              cwd: "/real/project",
            ),
          ],
          nextCursor: null,
        ),
      ],
    );
    final service = _service(repository: repository, maxPages: 5);

    await service.deletePersistedSession(backendSessionId: "target");

    expect(repository.operations, [
      "open:/launch",
      "list:null",
      "list:next",
      "resume:target:/real/project",
      "delete:target",
      "close:target",
      "settle",
    ]);
  });

  test("cursor exhaustion is idempotent not-found", () async {
    final repository = _FakeCleanupRepository(
      pages: [OmpCleanupPage(sessions: const [], nextCursor: null)],
    );

    await _service(repository: repository, maxPages: 5).deletePersistedSession(backendSessionId: "missing");

    expect(repository.operations, ["open:/launch", "list:null", "settle"]);
  });

  test("truncated scan uses global-ID resume fallback", () async {
    final repository = _FakeCleanupRepository(
      pages: [OmpCleanupPage(sessions: const [], nextCursor: "more")],
    );

    await _service(repository: repository, maxPages: 1).deletePersistedSession(backendSessionId: "target");

    expect(repository.operations, [
      "open:/launch",
      "list:null",
      "scratch:create",
      startsWith("resume:target:"),
      "delete:target",
      "close:target",
      "scratch:delete",
      "settle",
    ]);
  });

  test("listed session without cwd resumes through an isolated scratch cwd", () async {
    final repository = _FakeCleanupRepository(
      pages: [
        OmpCleanupPage(
          sessions: const [OmpCleanupSession(sessionId: "target", cwd: null)],
          nextCursor: null,
        ),
      ],
    );

    await _service(repository: repository, maxPages: 5).deletePersistedSession(backendSessionId: "target");

    expect(repository.operations, [
      "open:/launch",
      "list:null",
      "scratch:create",
      "resume:target:/scratch/omp-cleanup-test",
      "delete:target",
      "close:target",
      "scratch:delete",
      "settle",
    ]);
  });

  test("non-success delete command remains observable", () async {
    final repository = _FakeCleanupRepository(
      pages: [
        OmpCleanupPage(
          sessions: const [OmpCleanupSession(sessionId: "target", cwd: "/project")],
          nextCursor: null,
        ),
      ],
    )..deleteError = StateError("deletion cancelled");

    expect(
      _service(repository: repository, maxPages: 5).deletePersistedSession(backendSessionId: "target"),
      throwsStateError,
    );
  });
}

OmpSessionCleanupService _service({required _FakeCleanupRepository repository, required int maxPages}) =>
    OmpSessionCleanupService(
      repository: repository,
      launchDirectory: "/launch",
      totalTimeout: const Duration(seconds: 2),
      maxPages: maxPages,
    );

class _FakeCleanupRepository implements OmpSessionCleanupRepository {
  _FakeCleanupRepository({required this.pages});

  final List<OmpCleanupPage> pages;
  final List<Object> operations = [];
  Object? deleteError;

  @override
  Future<AcpInitializeResult> open({required String cwd, required Duration timeout}) async {
    operations.add("open:$cwd");
    return AcpInitializeResult.fromJson(const {
      "protocolVersion": 1,
      "agentCapabilities": {
        "sessionCapabilities": {
          "list": <String, dynamic>{},
          "resume": <String, dynamic>{},
          "close": <String, dynamic>{},
        },
      },
    });
  }

  @override
  Future<OmpCleanupPage> listPage({required String? cursor, required Duration timeout}) async {
    operations.add("list:$cursor");
    return pages.removeAt(0);
  }

  @override
  Future<void> resume({required String sessionId, required String cwd, required Duration timeout}) async {
    operations.add("resume:$sessionId:$cwd");
  }

  @override
  Future<void> delete({required String sessionId, required Duration timeout}) async {
    operations.add("delete:$sessionId");
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  Future<void> close({required String sessionId, required Duration timeout}) async {
    operations.add("close:$sessionId");
  }

  @override
  Future<String> createScratchDirectory() async {
    operations.add("scratch:create");
    return "/scratch/omp-cleanup-test";
  }

  @override
  Future<void> deleteScratchDirectory() async {
    operations.add("scratch:delete");
  }

  @override
  Future<void> settle() async {
    operations.add("settle");
  }

  @override
  Future<void> dispose() async {}
}
