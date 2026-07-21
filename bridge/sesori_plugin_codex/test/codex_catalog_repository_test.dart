import "dart:io";

import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/models/codex_session_record.dart";
import "package:test/test.dart";

void main() {
  group("CodexCatalogRepository", () {
    test("maps rollout records to plugin sessions", () async {
      final createdAt = DateTime.utc(2026, 7, 16, 9);
      final updatedAt = DateTime.utc(2026, 7, 16, 10);
      final repository = _StubCodexCatalogRepository(
        [
          _record(
            id: "session-with-cwd",
            cwd: "/repo/app/../app",
            title: "Mapped session",
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          _record(
            id: "session-without-cwd",
            cwd: null,
            title: null,
            createdAt: null,
            updatedAt: null,
          ),
          _record(
            id: "session-with-blank-cwd",
            cwd: "  ",
            title: null,
            createdAt: null,
            updatedAt: null,
          ),
        ],
      );

      final sessions = await repository.listAllSessions();

      expect(sessions, hasLength(1));
      expect(sessions[0].id, "session-with-cwd");
      expect(sessions[0].projectID, "/repo/app");
      expect(sessions[0].directory, "/repo/app");
      expect(sessions[0].parentID, isNull);
      expect(sessions[0].title, "Mapped session");
      expect(
        sessions[0].time?.created,
        createdAt.millisecondsSinceEpoch,
      );
      expect(
        sessions[0].time?.updated,
        updatedAt.millisecondsSinceEpoch,
      );
      expect(sessions[0].time?.archived, isNull);
    });

    test("filters normalized project directories before paginating", () async {
      final repository = _StubCodexCatalogRepository(
        [
          _record(id: "first", cwd: "/repo/app", title: "First"),
          _record(id: "other", cwd: "/repo/other", title: "Other"),
          _record(id: "second", cwd: "/repo/app/.", title: "Second"),
          _record(id: "third", cwd: "/repo/app", title: "Third"),
        ],
      );

      final page = await repository.getSessions(
        projectId: "/repo/app/.",
        start: 1,
        limit: 1,
      );

      expect(page.map((session) => session.id), ["second"]);
      expect(
        await repository.getSessions(
          projectId: "/repo/app",
          start: 3,
          limit: null,
        ),
        isEmpty,
      );
      expect(
        await repository.getSessions(
          projectId: "/repo/app",
          start: -1,
          limit: 1,
        ),
        hasLength(1),
      );
      expect(
        await repository.getSessions(
          projectId: "/repo/app",
          start: 1,
          limit: -1,
        ),
        isEmpty,
      );
      expect(
        await repository.getSessions(
          projectId: "/repo/app",
          start: null,
          limit: 0,
        ),
        isEmpty,
      );
    });

    test("keeps the index entry when rollout deletion fails", () {
      final rolloutApi = _DeleteFailingRolloutApi();
      final repository = CodexCatalogRepository(rolloutApi: rolloutApi);

      repository.deleteSession(
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
      );

      expect(rolloutApi.wroteIndex, isFalse);
    });
  });
}

CodexSessionRecord _record({
  required String id,
  required String? cwd,
  required String? title,
  DateTime? createdAt,
  DateTime? updatedAt,
}) => CodexSessionRecord(
  id: id,
  rolloutPath: "/rollouts/$id.jsonl",
  cwd: cwd,
  threadName: title,
  createdAt: createdAt,
  updatedAt: updatedAt,
  cliVersion: "0.142.0",
  modelProvider: "openai",
  model: "gpt-5.4-codex",
);

class _StubCodexCatalogRepository extends CodexCatalogRepository {
  _StubCodexCatalogRepository(this.records) : super(rolloutApi: CodexRolloutApi(environment: const {}));

  final List<CodexSessionRecord> records;

  @override
  Future<List<CodexSessionRecord>> listSessionRecordsInIsolate() async => records;
}

class _DeleteFailingRolloutApi extends CodexRolloutApi {
  _DeleteFailingRolloutApi() : super(environment: const {});

  bool wroteIndex = false;

  @override
  List<String> listRolloutPaths() => [
    "/rollout-2026-01-01T00-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
  ];

  @override
  List<CodexSessionIndexLine> readSessionIndexLines() => [
    (
      entry: const CodexSessionIndexEntryDto(
        id: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        threadName: "Session",
        updatedAt: null,
      ),
      raw: '{"id":"019a0000-1111-2222-3333-aaaaaaaaaaaa"}',
    ),
  ];

  @override
  void deleteRollout({required String rolloutPath}) {
    throw const FileSystemException("denied");
  }

  @override
  void writeSessionIndex({required List<String> lines}) {
    wroteIndex = true;
  }
}
