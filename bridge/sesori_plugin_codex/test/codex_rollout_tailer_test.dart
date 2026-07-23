import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/services/codex_rollout_tailer.dart";
import "package:path/path.dart" as p;
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

      expect(
        () => tailer.start(sessionId: "session-1"),
        returnsNormally,
      );
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

      tailer.start(sessionId: "session-1");
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
      expect(appends.single.line.payload?.callId, "current-call");
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

      tailer.start(sessionId: "session-1");
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
      expect(appends.single.line.payload?.callId, "late-call");
    });
  });
}

class _ThrowingPositionApi extends CodexRolloutApi {
  _ThrowingPositionApi() : super(environment: const {});

  @override
  CodexRolloutTailPosition rolloutTailPosition({
    required String rolloutPath,
  }) {
    throw const FileSystemException("stat failed");
  }
}

class _FixedCatalogRepository extends CodexCatalogRepository {
  _FixedCatalogRepository({
    required super.rolloutApi,
    required this.path,
  });

  final String path;

  @override
  String? findRolloutPath({required String sessionId}) => path;
}

class _MutableCatalogRepository extends CodexCatalogRepository {
  _MutableCatalogRepository({required super.rolloutApi});

  String? path;

  @override
  String? findRolloutPath({required String sessionId}) => path;
}
