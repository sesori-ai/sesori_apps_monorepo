import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/services/codex_rollout_tailer.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, LogLevel;
import "package:test/test.dart";

void main() {
  group("CodexRolloutTailer", () {
    test("start fails soft when the existing rollout cannot be statted", () async {
      final api = _ThrowingPositionApi();
      final tailer = CodexRolloutTailer(
        rolloutApi: api,
        catalogRepository: _FixedCatalogRepository(
          rolloutApi: api,
          path: "/unreadable/rollout.jsonl",
        ),
        pollInterval: const Duration(milliseconds: 5),
      );
      addTearDown(tailer.dispose);

      await expectLater(tailer.start(sessionId: "session-1"), completes);
    });

    test("finish waits for a start still resolving its rollout", () async {
      final directory = Directory.systemTemp.createTempSync("codex-tail-");
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = p.join(directory.path, "rollout.jsonl");
      File(path).writeAsStringSync("${_record(callId: "history-call")}\n");
      final api = CodexRolloutApi(environment: const {});
      final lookup = Completer<String?>();
      final tailer = CodexRolloutTailer(
        rolloutApi: api,
        catalogRepository: _DeferredCatalogRepository(rolloutApi: api, lookup: lookup.future),
        pollInterval: const Duration(milliseconds: 5),
      );
      final appends = <CodexRolloutAppend>[];
      final subscription = tailer.appends.listen(appends.add);
      addTearDown(() async {
        await subscription.cancel();
        await tailer.dispose();
      });

      unawaited(tailer.start(sessionId: "session-1"));
      final finished = tailer.finish(sessionId: "session-1");
      lookup.complete(path);
      Timer(const Duration(milliseconds: 10), () {
        File(path).writeAsStringSync("${_record(callId: "live-call")}\n", mode: FileMode.append);
      });
      await finished;

      expect(appends.map((append) => _responseItemCallId(line: append.line)), ["live-call"]);
    });

    test("a start still resolving its rollout when stopAll runs installs no cursor", () async {
      final directory = Directory.systemTemp.createTempSync("codex-tail-");
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = p.join(directory.path, "rollout.jsonl");
      File(path).writeAsStringSync("");
      final api = CodexRolloutApi(environment: const {});
      final lookup = Completer<String?>();
      final tailer = CodexRolloutTailer(
        rolloutApi: api,
        catalogRepository: _DeferredCatalogRepository(rolloutApi: api, lookup: lookup.future),
        pollInterval: const Duration(milliseconds: 5),
      );
      final appends = <CodexRolloutAppend>[];
      final subscription = tailer.appends.listen(appends.add);
      addTearDown(() async {
        await subscription.cancel();
        await tailer.dispose();
      });

      final started = tailer.start(sessionId: "session-1");
      tailer.stopAll();
      lookup.complete(path);
      await started;
      File(path).writeAsStringSync("${_record(callId: "late-call")}\n", mode: FileMode.append);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(appends, isEmpty);
    });

    test("a start after stopAll does not share the overtaken start and tails the rollout", () async {
      final directory = Directory.systemTemp.createTempSync("codex-tail-");
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = p.join(directory.path, "rollout.jsonl");
      File(path).writeAsStringSync("");
      final api = CodexRolloutApi(environment: const {});
      final lookup = Completer<String?>();
      final tailer = CodexRolloutTailer(
        rolloutApi: api,
        catalogRepository: _DeferredCatalogRepository(rolloutApi: api, lookup: lookup.future),
        pollInterval: const Duration(milliseconds: 5),
      );
      final appends = <CodexRolloutAppend>[];
      final subscription = tailer.appends.listen(appends.add);
      addTearDown(() async {
        await subscription.cancel();
        await tailer.dispose();
      });

      final overtaken = tailer.start(sessionId: "session-1");
      tailer.stopAll();
      final fresh = tailer.start(sessionId: "session-1");
      expect(identical(fresh, overtaken), isFalse);
      lookup.complete(path);
      await Future.wait([overtaken, fresh]);
      File(path).writeAsStringSync("${_record(callId: "after-reconnect")}\n", mode: FileMode.append);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(appends, isNotEmpty);
    });

    group("on a cold catalog", () {
      const sessionId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
      late Directory codexHome;
      late CodexRolloutApi api;
      late CodexRolloutTailer tailer;
      late List<CodexRolloutAppend> appends;

      setUp(() {
        codexHome = Directory.systemTemp.createTempSync("codex-tail-home-");
        api = CodexRolloutApi(environment: {"CODEX_HOME": codexHome.path});
        // Polls are driven by hand; the timer never fires.
        tailer = CodexRolloutTailer(
          rolloutApi: api,
          catalogRepository: CodexCatalogRepository(rolloutApi: api),
          pollInterval: const Duration(hours: 1),
        );
        appends = [];
        final subscription = tailer.appends.listen(appends.add);
        addTearDown(() async {
          await subscription.cancel();
          await tailer.dispose();
          codexHome.deleteSync(recursive: true);
        });
      });

      test("an existing rollout tails from its end, not its history", () async {
        final rollout = File(
          p.join(codexHome.path, "sessions", "2026", "04", "17", "rollout-2026-04-17T10-00-00-$sessionId.jsonl"),
        )..createSync(recursive: true);
        rollout.writeAsStringSync("${_record(callId: "history-call")}\n");

        await tailer.start(sessionId: sessionId);
        rollout.writeAsStringSync("${_record(callId: "live-call")}\n", mode: FileMode.append);
        tailer.drain(sessionId: sessionId);

        expect(appends.map((append) => _responseItemCallId(line: append.line)), ["live-call"]);
      });

      test("polls for a rollout created after the start do not rescan the catalog", () async {
        await tailer.start(sessionId: sessionId);

        final now = DateTime.now();
        final logs = await _captureDebugLogs(() async {
          for (var poll = 0; poll < 5; poll++) {
            tailer.drain(sessionId: sessionId);
          }
          File(
              p.join(
                codexHome.path,
                "sessions",
                now.year.toString(),
                now.month.toString().padLeft(2, "0"),
                now.day.toString().padLeft(2, "0"),
                "rollout-2026-04-17T10-00-00-$sessionId.jsonl",
              ),
            )
            ..createSync(recursive: true)
            ..writeAsStringSync("${_record(callId: "first-call")}\n");
          tailer.drain(sessionId: sessionId);
        });

        expect(logs, isNot(contains("rollout catalog scan")));
        expect(appends.map((append) => _responseItemCallId(line: append.line)), ["first-call"]);
      });
    });

    test("finish waits for a partial record present when tailing starts", () async {
      final directory = Directory.systemTemp.createTempSync("codex-tail-");
      addTearDown(() {
        try {
          directory.deleteSync(recursive: true);
        } catch (_) {}
      });
      final path = p.join(directory.path, "rollout.jsonl");
      final completeOldRecord = jsonEncode({
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "name": "wait",
          "call_id": "old-call",
          "arguments": "{}",
        },
      });
      final finalRecord = jsonEncode({
        "type": "response_item",
        "payload": {
          "type": "function_call_output",
          "call_id": "current-call",
          "output": "done",
        },
      });
      final split = finalRecord.length ~/ 2;
      File(path).writeAsStringSync(
        "$completeOldRecord\n${finalRecord.substring(0, split)}",
      );
      final api = CodexRolloutApi(environment: const {});
      final tailer = CodexRolloutTailer(
        rolloutApi: api,
        catalogRepository: _FixedCatalogRepository(
          rolloutApi: api,
          path: path,
        ),
        pollInterval: const Duration(milliseconds: 5),
      );
      final appends = <CodexRolloutAppend>[];
      final subscription = tailer.appends.listen(appends.add);
      addTearDown(() async {
        await subscription.cancel();
        await tailer.dispose();
      });

      await tailer.start(sessionId: "session-1");
      final appendTimer = Timer(const Duration(milliseconds: 10), () {
        File(path).writeAsStringSync(
          "${finalRecord.substring(split)}\n",
          mode: FileMode.append,
        );
      });
      addTearDown(appendTimer.cancel);

      await tailer.finish(sessionId: "session-1");

      expect(appends, hasLength(1));
      expect(appends.single.sessionId, "session-1");
      expect(
        _responseItemCallId(line: appends.single.line),
        "current-call",
      );
    });

    test("finish waits for a rollout created after completion begins", () async {
      final directory = Directory.systemTemp.createTempSync("codex-tail-");
      addTearDown(() {
        try {
          directory.deleteSync(recursive: true);
        } catch (_) {}
      });
      final path = p.join(directory.path, "rollout.jsonl");
      final api = CodexRolloutApi(environment: const {});
      final repository = _MutableCatalogRepository(rolloutApi: api);
      final tailer = CodexRolloutTailer(
        rolloutApi: api,
        catalogRepository: repository,
        pollInterval: const Duration(milliseconds: 5),
      );
      final appends = <CodexRolloutAppend>[];
      final subscription = tailer.appends.listen(appends.add);
      addTearDown(() async {
        await subscription.cancel();
        await tailer.dispose();
      });

      await tailer.start(sessionId: "session-1");
      final createTimer = Timer(const Duration(milliseconds: 10), () {
        File(path).writeAsStringSync(
          "${jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "function_call_output",
              "call_id": "late-call",
              "output": "done",
            },
          })}\n",
        );
        repository.path = path;
      });
      addTearDown(createTimer.cancel);

      await tailer.finish(sessionId: "session-1");

      expect(appends, hasLength(1));
      expect(appends.single.sessionId, "session-1");
      expect(
        _responseItemCallId(line: appends.single.line),
        "late-call",
      );
    });

    test("finish waits for a late append to an existing rollout", () async {
      final directory = Directory.systemTemp.createTempSync("codex-tail-");
      addTearDown(() {
        try {
          directory.deleteSync(recursive: true);
        } catch (_) {}
      });
      final path = p.join(directory.path, "rollout.jsonl");
      File(path).writeAsStringSync(
        "${jsonEncode({
          "type": "response_item",
          "payload": {
            "type": "function_call_output",
            "call_id": "previous-call",
            "output": "old",
          },
        })}\n",
      );
      final api = CodexRolloutApi(environment: const {});
      final tailer = CodexRolloutTailer(
        rolloutApi: api,
        catalogRepository: _FixedCatalogRepository(
          rolloutApi: api,
          path: path,
        ),
        pollInterval: const Duration(milliseconds: 5),
      );
      final appends = <CodexRolloutAppend>[];
      final subscription = tailer.appends.listen(appends.add);
      addTearDown(() async {
        await subscription.cancel();
        await tailer.dispose();
      });

      await tailer.start(sessionId: "session-1");
      final appendTimer = Timer(const Duration(milliseconds: 10), () {
        File(path).writeAsStringSync(
          "${jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "function_call_output",
              "call_id": "late-existing-call",
              "output": "done",
            },
          })}\n",
          mode: FileMode.append,
        );
      });
      addTearDown(appendTimer.cancel);

      await tailer.finish(sessionId: "session-1");

      expect(appends, hasLength(1));
      expect(appends.single.sessionId, "session-1");
      expect(
        _responseItemCallId(line: appends.single.line),
        "late-existing-call",
      );
    });
  });
}

String _responseItemCallId({required CodexRolloutLineDto line}) {
  return switch (line) {
    CodexRolloutResponseItemLineDto(
      payload: CodexRolloutFunctionCallOutputDto(:final callId),
    ) =>
      callId,
    _ => throw StateError("Expected response item rollout line"),
  };
}

class _ThrowingPositionApi() extends CodexRolloutApi {
  this : super(environment: const {});

  @override
  CodexRolloutTailPosition rolloutTailPosition({
    required String rolloutPath,
  }) {
    throw const FileSystemException("stat failed");
  }
}

class _FixedCatalogRepository({
  required super.rolloutApi,
  required final String path,
}) extends CodexCatalogRepository {
  @override
  Future<String?> findRolloutPath({required String sessionId}) async => path;
}

class _MutableCatalogRepository({required super.rolloutApi}) extends CodexCatalogRepository {
  String? path;

  @override
  Future<String?> findRolloutPath({required String sessionId}) async => path;

  @override
  String? findRecentRolloutPath({required String sessionId}) => path;
}

class _DeferredCatalogRepository({
  required super.rolloutApi,
  required final Future<String?> lookup,
}) extends CodexCatalogRepository {
  @override
  Future<String?> findRolloutPath({required String sessionId}) => lookup;
}

String _record({required String callId}) => jsonEncode({
  "type": "response_item",
  "payload": {"type": "function_call_output", "call_id": callId, "output": "done"},
});

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
