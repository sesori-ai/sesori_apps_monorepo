import "dart:io";

import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/api/models/codex_desktop_state_dto.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/models/codex_session_record.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, LogLevel, PluginSession;
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

      final sessions = await repository.listAllSessions(knownDirectories: const {});

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

    test("logs privacy-safe aggregate rollout scan diagnostics", () async {
      const rolloutId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
      final repository = CodexCatalogRepository(
        rolloutApi: _DiagnosticsRolloutApi(rolloutId: rolloutId),
      );

      final logs = await _captureDebugLogs(() async {
        expect(await repository.listSessionRecords(), hasLength(1));
      });

      expect(logs, contains("rollout catalog scan: files=3, recognizedRollouts=1, parsedHeaders=1, indexEntries=2"));
      expect(logs, contains("rollout catalog records: unreadableOrMissingMetadata=0, mismatchedMetadata=0, records=1"));
      expect(logs, isNot(contains(rolloutId)));
      expect(logs, isNot(contains("private-project")));
    });

    test("propagates the log level into the scan isolate", () async {
      final previousLevel = Log.level;
      try {
        Log.level = LogLevel.debug;
        final repository = CodexCatalogRepository(
          rolloutApi: _LogLevelCheckingRolloutApi(),
        );

        expect((await repository.listSessionRecords()).single.cwd, "/repo/app");
      } finally {
        Log.level = previousLevel;
      }
    });

    // The scan isolate logs the stat failure to its own stderr, which a test
    // zone cannot capture.
    test("an unreadable rollout modification time keeps index activity", () async {
      const rolloutId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
      final repository = CodexCatalogRepository(
        rolloutApi: _UnreadableActivityRolloutApi(rolloutId: rolloutId),
      );

      final record = (await repository.listSessionRecords()).single;

      expect(record.createdAt, DateTime.utc(2026, 8, 1));
      expect(record.updatedAt, DateTime.utc(2026, 8, 1, 12));
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

    test("discovery excludes projectless ids and every session under Documents/Codex", () async {
      final userHome = p.join(Directory.systemTemp.path, "codex-discovery-user");
      final documentsCodex = p.join(userHome, "Documents", "Codex");
      final generatedChat = p.join(documentsCodex, "2026-08-01", "new-chat-2");
      final existingGeneratedChat = p.join(documentsCodex, "2026-08-01", "existing-chat");
      final normalProject = p.join(userHome, "repos", "app");
      final existingStateProject = p.join(userHome, "repos", "existing-projectless");
      final dateShapedProject = p.join(userHome, "repos", "2026-08-01", "small-slug");
      final similarlyNamedProject = p.join(userHome, "Documents", "Codexical", "app");
      final repository = _DiscoveryStubCodexCatalogRepository(
        rolloutApi: _DiscoveryRolloutApi(
          documentsCodexDirectory: documentsCodex,
          projectlessThreadIds: const {"state-filtered", "existing-state-filtered"},
          desktopStateError: null,
        ),
        records: [
          _record(id: "generated-root", cwd: documentsCodex, title: "Generated root"),
          _record(id: "generated-child", cwd: generatedChat, title: "Generated child"),
          _record(id: "existing-generated", cwd: existingGeneratedChat, title: "Existing generated"),
          _record(id: "state-filtered", cwd: normalProject, title: "Projectless elsewhere"),
          _record(
            id: "existing-state-filtered",
            cwd: existingStateProject,
            title: "Existing projectless elsewhere",
          ),
          _record(id: "normal", cwd: normalProject, title: "Normal"),
          _record(id: "date-shaped", cwd: dateShapedProject, title: "Date shaped"),
          _record(id: "similar-name", cwd: similarlyNamedProject, title: "Similar name"),
        ],
      );

      late List<PluginSession> discovered;
      final logs = await _captureDebugLogs(() async {
        discovered = await repository.listAllSessions(
          knownDirectories: {existingGeneratedChat, existingStateProject},
        );
      });

      expect(
        discovered.map((session) => session.id),
        ["existing-generated", "existing-state-filtered", "normal", "date-shaped", "similar-name"],
      );
      expect(
        logs,
        contains(
          "catalog discovery: records=8, knownDirectories=2, "
          "noiseExcluded=3, missingCwd=0, projectDirectories=5, sessions=5",
        ),
      );
      expect(logs, isNot(contains("generated-child")));
      expect(logs, isNot(contains(generatedChat)));
      expect(
        (await repository.getSessions(projectId: generatedChat, start: null, limit: null)).map(
          (session) => session.id,
        ),
        ["generated-child"],
        reason: "discovery filtering must not remove direct access to an already-known session",
      );
    });

    test("discovery keeps using the Documents/Codex filter when desktop state is unreadable", () async {
      final userHome = p.join(Directory.systemTemp.path, "codex-unreadable-state-user");
      final documentsCodex = p.join(userHome, "Documents", "Codex");
      final repository = _DiscoveryStubCodexCatalogRepository(
        rolloutApi: _DiscoveryRolloutApi(
          documentsCodexDirectory: documentsCodex,
          projectlessThreadIds: const {},
          desktopStateError: const FormatException("malformed state"),
        ),
        records: [
          _record(
            id: "generated",
            cwd: p.join(documentsCodex, "2026-08-01", "chat"),
            title: "Generated",
          ),
          _record(id: "normal", cwd: p.join(userHome, "repos", "app"), title: "Normal"),
        ],
      );

      final discovered = await repository.listAllSessions(knownDirectories: const {});

      expect(discovered.map((session) => session.id), ["normal"]);
    });

    test("keeps the index entry when rollout deletion fails", () async {
      final rolloutApi = _DeleteFailingRolloutApi();
      final repository = CodexCatalogRepository(rolloutApi: rolloutApi);

      final deleted = await repository.deleteSession(
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
      );

      expect(deleted, isFalse);
      expect(rolloutApi.wroteIndex, isFalse);
    });

    test("reports failure when rollout absence cannot be confirmed", () async {
      final repository = CodexCatalogRepository(
        rolloutApi: _EnumerationFailingRolloutApi(),
      );

      expect(await repository.deleteSession(sessionId: "session-1"), isFalse);
    });

    test("reports failure when the session index cannot be read", () async {
      final repository = CodexCatalogRepository(
        rolloutApi: _IndexReadFailingRolloutApi(),
      );

      expect(await repository.deleteSession(sessionId: "session-1"), isFalse);
    });

    test("reports failure when the session index cannot be updated", () async {
      final repository = CodexCatalogRepository(
        rolloutApi: _IndexWriteFailingRolloutApi(),
      );

      expect(await repository.deleteSession(sessionId: "session-1"), isFalse);
    });

    group("scan cache", () {
      late _InMemoryRolloutApi rolloutApi;
      late CodexCatalogRepository repository;

      setUp(() {
        rolloutApi = _InMemoryRolloutApi(sessionIds: [for (var i = 0; i < 200; i++) _sessionId(i)]);
        repository = CodexCatalogRepository(rolloutApi: rolloutApi);
      });

      test("enumeration does no file I/O on the main isolate, however many sessions", () async {
        expect(await repository.listSessionRecords(), hasLength(200));
        // A second scan reuses every cached header.
        final logs = await _captureDebugLogs(() async {
          expect(await repository.listSessionRecords(), hasLength(200));
        });

        // Every API call in the isolate counts on its own copy of the API.
        expect(rolloutApi.mainIsolateCalls, 0);
        expect(_scanLines(logs), ["files=200, recognizedRollouts=200, parsedHeaders=0, indexEntries=0"]);
      });

      test("a lookup hit answers from the index without scanning or file I/O", () async {
        await repository.listSessionRecords();

        final logs = await _captureDebugLogs(() async {
          expect(repository.cachedSessionById(sessionId: _sessionId(7))?.cwd, "/repo/app");
          expect((await repository.findSessionById(sessionId: _sessionId(7)))?.cwd, "/repo/app");
          expect(await repository.findRolloutPath(sessionId: _sessionId(7)), rolloutApi.pathOf(_sessionId(7)));
        });

        expect(_scanLines(logs), isEmpty);
        expect(rolloutApi.mainIsolateCalls, 0);
      });

      test("a synchronous miss queues a rescan, and one during a scan queues the follow-up", () async {
        await repository.listSessionRecords();
        rolloutApi.sessionIds.add(_sessionId(200));

        final logs = await _captureDebugLogs(() async {
          expect(repository.cachedSessionById(sessionId: _sessionId(200)), isNull);
          // This miss arrives during that rescan, so it shares the follow-up.
          expect(repository.cachedSessionById(sessionId: _sessionId(200)), isNull);
          expect(await repository.findRolloutPath(sessionId: _sessionId(200)), rolloutApi.pathOf(_sessionId(200)));
        });

        expect(_scanLines(logs), [
          "files=201, recognizedRollouts=201, parsedHeaders=1, indexEntries=0",
          "files=201, recognizedRollouts=201, parsedHeaders=0, indexEntries=0",
        ]);
        expect(rolloutApi.mainIsolateCalls, 0);
      });

      test("an awaited miss rescans once", () async {
        await repository.listSessionRecords();

        final logs = await _captureDebugLogs(() async {
          expect(await repository.findRolloutPath(sessionId: _sessionId(999)), isNull);
        });

        expect(_scanLines(logs), hasLength(1));
      });

      test("callers during a scan share one follow-up scan", () async {
        final logs = await _captureDebugLogs(() async {
          await Future.wait([
            repository.listSessionRecords(),
            repository.listSessionRecords(),
            repository.findRolloutPath(sessionId: _sessionId(999)),
            repository.listSessionRecords(),
          ]);
        });

        expect(_scanLines(logs), hasLength(2));
      });

      test("a delete during a running scan does not resurrect the session", () async {
        await repository.listSessionRecords();

        // The isolate has copied the API, so this scan still lists the rollout.
        final listing = repository.listSessionRecords();
        expect(await repository.deleteSession(sessionId: _sessionId(3)), isTrue);

        expect((await listing).map((record) => record.id), isNot(contains(_sessionId(3))));
        expect(repository.cachedSessionById(sessionId: _sessionId(3)), isNull);
        expect(rolloutApi.deletedPaths, [rolloutApi.pathOf(_sessionId(3))]);
      });
    });
  });
}

String _sessionId(int index) => "019a0000-1111-2222-3333-${index.toString().padLeft(12, "0")}";

List<String> _scanLines(String logs) => [
  for (final match in RegExp("rollout catalog scan: (.*)").allMatches(logs)) ?match.group(1),
];

/// Rollouts held in memory. Each scan isolate receives a copy, so
/// [mainIsolateCalls] counts only the calls made on the main isolate.
class _InMemoryRolloutApi({required final List<String> sessionIds}) extends CodexRolloutApi {
  this : super(environment: const {});

  int mainIsolateCalls = 0;
  final List<String> deletedPaths = [];

  String pathOf(String sessionId) => "/sessions/rollout-2026-08-01T00-00-00-$sessionId.jsonl";

  @override
  List<String> listRolloutPaths() {
    mainIsolateCalls++;
    return [for (final id in sessionIds) pathOf(id)];
  }

  @override
  DateTime? lastModified({required String rolloutPath}) {
    mainIsolateCalls++;
    return DateTime.utc(2026, 8, 1, 12);
  }

  @override
  int? rolloutLength({required String rolloutPath}) {
    mainIsolateCalls++;
    return 1;
  }

  @override
  List<CodexSessionIndexEntryDto> readSessionIndex() {
    mainIsolateCalls++;
    return const [];
  }

  @override
  CodexRolloutHeader readHeader({required String rolloutPath}) {
    mainIsolateCalls++;
    final id = p.basenameWithoutExtension(rolloutPath).substring("rollout-2026-08-01T00-00-00-".length);
    return CodexRolloutHeader(
      lines: [
        CodexRolloutLineDto.sessionMetadata(
          timestamp: "2026-08-01T00:00:00Z",
          payload: CodexRolloutSessionMetadataPayloadDto(
            id: id,
            cwd: "/repo/app",
            timestamp: "2026-08-01T00:00:00Z",
            modelProvider: "openai",
            cliVersion: "0.147.0",
            parentThreadId: null,
            threadSource: null,
            agentNickname: null,
            agentPath: null,
          ),
        ),
      ],
      reachedLineLimit: true,
      fileLength: 1,
    );
  }

  /// Deletion runs on the main isolate; it is not counted as enumeration.
  @override
  void deleteRollout({required String rolloutPath}) {
    deletedPaths.add(rolloutPath);
    sessionIds.removeWhere((id) => pathOf(id) == rolloutPath);
  }

  @override
  List<CodexSessionIndexLine> readSessionIndexLines() => const [];
}

CodexSessionRecord _record({
  required String id,
  required String? cwd,
  required String? title,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? parentId,
}) => CodexSessionRecord(
  id: id,
  parentId: parentId,
  rolloutPath: "/rollouts/$id.jsonl",
  cwd: cwd,
  threadName: title,
  createdAt: createdAt,
  updatedAt: updatedAt,
  cliVersion: "0.142.0",
  modelProvider: "openai",
  model: "gpt-5.4-codex",
  agentNickname: null,
  agentPath: null,
);

class _StubCodexCatalogRepository(final List<CodexSessionRecord> records) extends CodexCatalogRepository {
  this : super(rolloutApi: CodexRolloutApi(environment: const {}));

  @override
  Future<List<CodexSessionRecord>> listSessionRecords() async => records;
}

class _DiscoveryStubCodexCatalogRepository({
  required super.rolloutApi,
  required final List<CodexSessionRecord> records,
}) extends CodexCatalogRepository {
  @override
  Future<List<CodexSessionRecord>> listSessionRecords() async => records;
}

class _DiscoveryRolloutApi({
  @override required final String? documentsCodexDirectory,
  required final Set<String> projectlessThreadIds,
  required final Object? desktopStateError,
}) extends CodexRolloutApi {
  this : super(environment: const {});

  @override
  Future<CodexDesktopStateDto> readDesktopState() async {
    final error = desktopStateError;
    if (error != null) {
      throw CodexDesktopStateReadException(cause: error);
    }
    return CodexDesktopStateDto(
      projectlessThreadIds: projectlessThreadIds,
    );
  }
}

class _DiagnosticsRolloutApi({required final String rolloutId}) extends CodexRolloutApi {
  this : super(environment: const {});

  String get _firstPath => p.join(
    Directory.systemTemp.path,
    "private-project",
    "rollout-2026-08-01T00-00-00-$rolloutId.jsonl",
  );

  String get _duplicatePath => p.join(
    Directory.systemTemp.path,
    "private-project",
    "rollout-2026-08-02T00-00-00-$rolloutId.jsonl",
  );

  @override
  List<String> listRolloutPaths() => [
    _firstPath,
    _duplicatePath,
    p.join(Directory.systemTemp.path, "private-project", "rollout-invalid.jsonl"),
  ];

  @override
  List<CodexSessionIndexEntryDto> readSessionIndex() => [
    CodexSessionIndexEntryDto(
      id: rolloutId,
      threadName: "Private title",
      updatedAt: null,
    ),
    const CodexSessionIndexEntryDto(
      id: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
      threadName: null,
      updatedAt: null,
    ),
  ];

  @override
  CodexRolloutHeader readHeader({required String rolloutPath}) => CodexRolloutHeader(
    reachedLineLimit: true,
    fileLength: 1,
    lines: [
      CodexRolloutLineDto.sessionMetadata(
        timestamp: "2026-08-01T00:00:00Z",
        payload: CodexRolloutSessionMetadataPayloadDto(
          id: rolloutId,
          cwd: p.join(Directory.systemTemp.path, "private-project"),
          timestamp: "2026-08-01T00:00:00Z",
          modelProvider: "openai",
          cliVersion: "0.147.0",
          parentThreadId: null,
          threadSource: null,
          agentNickname: null,
          agentPath: null,
        ),
      ),
    ],
  );
}

class _UnreadableActivityRolloutApi({required super.rolloutId}) extends _DiagnosticsRolloutApi {
  @override
  DateTime? lastModified({required String rolloutPath}) =>
      throw FileSystemException("fixture stat failure", rolloutPath);

  @override
  List<CodexSessionIndexEntryDto> readSessionIndex() => [
    CodexSessionIndexEntryDto(
      id: rolloutId,
      threadName: "Indexed title",
      updatedAt: "2026-08-01T12:00:00Z",
    ),
  ];
}

class _LogLevelCheckingRolloutApi() extends CodexRolloutApi {
  this : super(environment: const {});

  static const _sessionId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";

  @override
  List<String> listRolloutPaths() => const ["/sessions/rollout-2026-08-01T00-00-00-$_sessionId.jsonl"];

  @override
  List<CodexSessionIndexEntryDto> readSessionIndex() => const [];

  @override
  CodexRolloutHeader readHeader({required String rolloutPath}) {
    if (Log.level != LogLevel.debug) {
      throw StateError("Expected debug logging in the scan isolate");
    }
    return const CodexRolloutHeader(
      lines: [
        CodexRolloutLineDto.sessionMetadata(
          timestamp: "2026-08-01T00:00:00Z",
          payload: CodexRolloutSessionMetadataPayloadDto(
            id: _sessionId,
            cwd: "/repo/app",
            timestamp: "2026-08-01T00:00:00Z",
            modelProvider: "openai",
            cliVersion: "0.147.0",
            parentThreadId: null,
            threadSource: null,
            agentNickname: null,
            agentPath: null,
          ),
        ),
      ],
      reachedLineLimit: true,
      fileLength: 1,
    );
  }
}

class _DeleteFailingRolloutApi() extends CodexRolloutApi {
  this : super(environment: const {});

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

class _EnumerationFailingRolloutApi() extends CodexRolloutApi {
  this : super(environment: const {});

  @override
  List<String> listRolloutPaths() {
    throw const FileSystemException("denied");
  }
}

class _IndexReadFailingRolloutApi() extends CodexRolloutApi {
  this : super(environment: const {});

  @override
  List<String> listRolloutPaths() => const [];

  @override
  List<CodexSessionIndexLine> readSessionIndexLines() {
    throw const FileSystemException("denied");
  }
}

class _IndexWriteFailingRolloutApi() extends CodexRolloutApi {
  this : super(environment: const {});

  @override
  List<String> listRolloutPaths() => const [];

  @override
  List<CodexSessionIndexLine> readSessionIndexLines() => [
    (
      entry: const CodexSessionIndexEntryDto(
        id: "session-1",
        threadName: "Session",
        updatedAt: null,
      ),
      raw: '{"id":"session-1"}',
    ),
  ];

  @override
  void writeSessionIndex({required List<String> lines}) {
    throw const FileSystemException("denied");
  }
}

Future<String> _captureDebugLogs(Future<void> Function() action) async {
  final previousLevel = Log.level;
  final stderr = BufferingStdout();
  try {
    Log.level = LogLevel.debug;
    await IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}
