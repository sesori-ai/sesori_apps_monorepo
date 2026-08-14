import "dart:async" show TimeoutException;
import "dart:convert";
import "dart:io";

import "package:pi_plugin/pi_plugin.dart";
import "package:pi_plugin/pi_testing.dart";
import "package:pi_plugin/src/api/models/pi_session_history_dto.dart";
import "package:pi_plugin/src/repositories/mappers/pi_history_mapper.dart";
import "package:pi_plugin/src/repositories/mappers/pi_persisted_user_text_codec.dart";
import "package:pi_plugin/src/repositories/pi_session_process_repository.dart";
import "package:pi_plugin/src/repositories/trackers/pi_message_identity_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/pi_rpc_client_test_factory.dart";

void main() {
  group("PiSessionProcessRepository.loadHistory", () {
    test("resumes exact path in header cwd, sends get_entries, maps response, and disposes", () async {
      final process = FakePiProcess();
      late PiLaunchSpec launchSpec;
      final repository = _repository(
        processFactory: ({required spec}) async {
          launchSpec = spec;
          return process;
        },
      );

      final pending = repository.loadHistory(sessionId: "session", knownDirectories: const {"/known"});
      final command = await waitForCommand(process: process, type: "get_entries");
      process.emitResponse(
        id: command["id"]! as String,
        command: "get_entries",
        data: _historyJson(text: "from rpc"),
      );

      final messages = await pending;
      expect(launchSpec.binaryPath, "/runtime/pi");
      expect(launchSpec.workingDirectory, "/exact/header-cwd");
      expect(launchSpec.environment, {"EXTRA": "value", "PI_SKIP_VERSION_CHECK": "1"});
      expect(launchSpec.launch, isA<PiResumedSession>());
      expect((launchSpec.launch as PiResumedSession).sessionPath, "/exact/session.jsonl");
      expect(launchSpec.arguments, ["--mode", "rpc", "--approve", "--session", "/exact/session.jsonl"]);
      expect(command.keys, containsAll(["id", "type"]));
      expect(command, hasLength(2));
      expect(messages.single.parts.single.text, "from rpc");
      expect(process.stdinClosed, isTrue);
      expect(process.killed, isTrue);
    });

    test("uses the injected replay timeout for get_entries", () async {
      final process = FakePiProcess();
      final repository = _repository(
        processFactory: ({required spec}) async => process,
        historyRpcTimeout: const Duration(milliseconds: 10),
      );

      final pending = repository.loadHistory(sessionId: "session", knownDirectories: const {});
      await waitForCommand(process: process, type: "get_entries");

      await expectLater(
        pending,
        throwsA(
          isA<PluginOperationException>().having(
            (error) => error.cause,
            "cause",
            isA<PiSessionHistoryLoadException>().having(
              (error) => error.innerError,
              "innerError",
              isA<TimeoutException>(),
            ),
          ),
        ),
      );
    });

    test("disposes when RPC response is malformed and wraps original parse failure", () async {
      final process = FakePiProcess();
      final repository = _repository(processFactory: ({required spec}) async => process);

      final warnings = await _captureWarnings(
        () async {
          final pending = repository.loadHistory(sessionId: "session", knownDirectories: const {});
          final command = await waitForCommand(process: process, type: "get_entries");
          process.emitResponse(
            id: command["id"]! as String,
            command: "get_entries",
            data: {"entries": "private malformed payload", "leafId": null},
          );
          await expectLater(
            pending,
            throwsA(
              isA<PluginOperationException>()
                  .having((error) => error.operation, "operation", "load Pi session history")
                  .having((error) => error.message, "message", "Pi session history could not be loaded.")
                  .having((error) => error.cause, "cause", isA<PiSessionHistoryLoadException>())
                  .having((error) => error.toString(), "presentation", isNot(contains("private malformed payload"))),
            ),
          );
        },
      );
      expect(warnings, contains("PiSessionHistoryParseException"));
      expect(warnings, isNot(contains("private malformed payload")));
      expect(process.stdinClosed, isTrue);
      expect(process.killed, isTrue);
    });

    test("missing session throws cause-preserving not found without starting a process", () async {
      var starts = 0;
      final repository = _repository(
        storageApi: _FakeStorageApi(missing: true),
        processFactory: ({required spec}) async {
          starts++;
          return FakePiProcess();
        },
      );

      await expectLater(
        repository.loadHistory(sessionId: "missing", knownDirectories: const {"/known"}),
        throwsA(
          isA<PluginOperationException>()
              .having((error) => error.isNotFound, "isNotFound", isTrue)
              .having((error) => error.cause, "cause", isA<PiSessionHistoryNotFoundException>())
              .having((error) => error.message, "message", "Pi session was not found."),
        ),
      );
      expect(starts, 0);
    });

    test("falls back to file only for exact no-model startup failure and logs cause plus path", () async {
      final root = Directory.systemTemp.createTempSync("pi-history-repository-");
      addTearDown(() => root.deleteSync(recursive: true));
      final path = "${root.path}/session.jsonl";
      File(path).writeAsStringSync(
        [
          {
            "type": "session",
            "version": 3,
            "id": "session",
            "timestamp": "2026-08-01T00:00:00Z",
            "cwd": "/exact/header-cwd",
          },
          ..._historyJson(text: "from file")["entries"]! as List<Object?>,
        ].map(jsonEncode).join("\n"),
      );
      final process = FakePiProcess();
      final storage = _FakeStorageApi(path: path);
      final repository = _repository(
        storageApi: storage,
        processFactory: ({required spec}) async {
          process.emitStderrRaw(
            bytes: utf8.encode(
              "${PiRpcClient.noModelsDiagnosticPrefix} /private/home/.pi/agent/models.md\n",
            ),
          );
          process.exit(code: 78);
          return process;
        },
      );

      final warnings = await _captureWarnings(() async {
        final messages = await repository.loadHistory(sessionId: "session", knownDirectories: const {});
        expect(messages.single.parts.single.text, "from file");
      });

      expect(process.written.single["type"], "get_entries");
      expect(process.stdinClosed, isTrue);
      expect(warnings, contains("history RPC startup unavailable"));
      expect(warnings, contains(path));
      expect(warnings, contains("PiRpcProcessExitException(exitCode: 78)"));
      expect(warnings, contains("pi_rpc_client.dart"));
      expect(warnings, isNot(contains("from file")));
      expect(warnings, isNot(contains("/private/home")));
    });

    test("does not fall back for arbitrary send failure", () async {
      final process = FakePiProcess(stdinWritesFail: true);
      final storage = _FakeStorageApi();
      final repository = _repository(
        storageApi: storage,
        processFactory: ({required spec}) async => process,
      );

      await expectLater(
        repository.loadHistory(sessionId: "session", knownDirectories: const {}),
        throwsA(
          isA<PluginOperationException>().having(
            (error) => error.cause,
            "cause",
            isA<PiSessionHistoryLoadException>().having(
              (error) => error.innerError,
              "innerError",
              isA<PiRpcWriteException>(),
            ),
          ),
        ),
      );
      expect(process.stdinClosed, isTrue);
      expect(process.killed, isTrue);
    });

    test("falls back when exact no-model startup surfaces as stdin failure", () async {
      final storage = _FakeStorageApi(
        history: PiSessionFileHistoryDto(
          header: const PiSessionFileHeaderDto(version: 3, id: "session"),
          entries: [_fileUserEntry(id: "entry", parentId: null, text: "from file", timestamp: 1)],
        ),
      );
      final process = FakePiProcess();
      final repository = _repository(
        storageApi: storage,
        processFactory: ({required spec}) async => process,
      );

      final pending = repository.loadHistory(sessionId: "session", knownDirectories: const {});
      await waitForCommand(process: process, type: "get_entries");
      process.emitStderrRaw(bytes: utf8.encode("${PiRpcClient.noModelsDiagnosticPrefix}\n"));
      process.failStdin(error: const SocketException("closed during startup"));

      final messages = await pending;
      expect(messages.single.parts.single.text, "from file");
    });

    test("bounds stdin-failure exit wait and rethrows the original failure", () async {
      final process = FakePiProcess();
      final repository = _repository(
        processFactory: ({required spec}) async => process,
        startupExitTimeout: const Duration(milliseconds: 10),
      );

      final pending = repository.loadHistory(sessionId: "session", knownDirectories: const {});
      await waitForCommand(process: process, type: "get_entries");
      process.failStdin(error: const SocketException("stalled startup"));

      await expectLater(
        pending,
        throwsA(
          isA<PluginOperationException>().having(
            (error) => error.cause,
            "cause",
            isA<PiSessionHistoryLoadException>().having(
              (error) => error.innerError,
              "innerError",
              isA<PiRpcStdinException>(),
            ),
          ),
        ),
      );
      expect(process.killed, isTrue);
    });

    test("logs command failure detail locally without exposing it remotely", () async {
      const detail = "model selection failed before history read";
      final process = FakePiProcess();
      final repository = _repository(processFactory: ({required spec}) async => process);

      final warnings = await _captureWarnings(() async {
        final pending = repository.loadHistory(sessionId: "session", knownDirectories: const {});
        final command = await waitForCommand(process: process, type: "get_entries");
        process.emitFailure(id: command["id"]! as String, command: "get_entries", error: detail);
        await expectLater(
          pending,
          throwsA(
            isA<PluginOperationException>().having(
              (error) => error.toString(),
              "remote error",
              isNot(contains(detail)),
            ),
          ),
        );
      });

      expect(warnings, contains(detail));
    });

    test("does not fall back for process exit without exact no-model diagnostic", () async {
      final process = FakePiProcess();
      final repository = _repository(
        processFactory: ({required spec}) async {
          process.emitStderrRaw(bytes: utf8.encode("unrelated startup failure\n"));
          process.exit(code: 1);
          return process;
        },
      );

      await expectLater(
        repository.loadHistory(sessionId: "session", knownDirectories: const {}),
        throwsA(
          isA<PluginOperationException>().having(
            (error) => error.cause,
            "cause",
            isA<PiSessionHistoryLoadException>().having(
              (error) => error.innerError,
              "innerError",
              isA<PiRpcProcessExitException>(),
            ),
          ),
        ),
      );
    });

    test("migrates v1 file entries into a linear active branch", () async {
      final storage = _FakeStorageApi(
        history: PiSessionFileHistoryDto(
          header: const PiSessionFileHeaderDto(version: null, id: "session"),
          entries: [
            _fileUserEntry(id: null, parentId: null, text: "first", timestamp: 1),
            _fileUserEntry(id: null, parentId: null, text: "second", timestamp: 2),
          ],
        ),
      );

      final messages = await _loadFileFallback(storage: storage);

      expect(messages.map((message) => message.parts.single.text), ["first", "second"]);
    });

    test("migrates v2 hookMessage role to visible custom content", () async {
      final storage = _FakeStorageApi(
        history: PiSessionFileHistoryDto(
          header: const PiSessionFileHeaderDto(version: 2, id: "session"),
          entries: [
            PiSessionFileEntryDto.message(
              id: "hook",
              parentId: null,
              timestamp: DateTime.utc(2026, 8),
              message: const PiSessionFileAgentMessageDto.hookMessage(
                content: [PiContentDto.text(text: "hook content")],
                display: true,
                timestamp: 1,
              ),
            ),
          ],
        ),
      );

      final messages = await _loadFileFallback(storage: storage);

      expect(messages.single.parts.single.text, "hook content");
    });

    test("decodes exact persisted user-visible text marker", () async {
      final process = FakePiProcess();
      final repository = _repository(processFactory: ({required spec}) async => process);
      final persistedText = const PiPersistedUserTextCodec().encode(
        executionText: "private execution context\nvisible authored text",
        userVisibleText: "visible authored text",
      );

      final pending = repository.loadHistory(
        sessionId: "session",
        knownDirectories: const {},
      );
      final command = await waitForCommand(process: process, type: "get_entries");
      process.emitResponse(
        id: command["id"]! as String,
        command: "get_entries",
        data: _historyJson(text: persistedText),
      );

      final messages = await pending;
      expect(messages.single.parts.single.text, "visible authored text");
    });
  });
}

PiSessionProcessRepository _repository({
  PiSessionStorageApi? storageApi,
  required PiProcessFactory processFactory,
  Duration startupExitTimeout = const Duration(seconds: 5),
  Duration historyRpcTimeout = const Duration(minutes: 2),
}) {
  final storage = storageApi ?? _FakeStorageApi();
  return PiSessionProcessRepository(
    storageApi: storage,
    historyStorageApi: _FakeHistoryStorageApi(storageApi: storage),
    binaryPath: "/runtime/pi",
    environment: const {"EXTRA": "value"},
    processFactory: processFactory,
    historyMapper: PiHistoryMapper(pluginId: "pi"),
    identityTracker: PiMessageIdentityTracker(pluginId: "pi"),
    startupExitTimeout: startupExitTimeout,
    historyRpcTimeout: historyRpcTimeout,
  );
}

Map<String, Object?> _historyJson({required String text}) => {
  "entries": [
    {
      "type": "message",
      "id": "entry",
      "parentId": null,
      "timestamp": "2026-08-01T00:00:00Z",
      "message": {
        "role": "user",
        "content": [
          {"type": "text", "text": text, "textSignature": null},
        ],
        "timestamp": 1,
      },
    },
  ],
  "leafId": "entry",
};

PiSessionFileEntryDto _fileUserEntry({
  required String? id,
  required String? parentId,
  required String text,
  required int timestamp,
}) => PiSessionFileEntryDto.message(
  id: id,
  parentId: parentId,
  timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
  message: PiSessionFileAgentMessageDto.user(
    content: [PiContentDto.text(text: text)],
    timestamp: timestamp,
  ),
);

Future<List<PluginMessageWithParts>> _loadFileFallback({required _FakeStorageApi storage}) {
  final process = FakePiProcess();
  return _repository(
    storageApi: storage,
    processFactory: ({required spec}) async {
      process.emitStderrRaw(bytes: utf8.encode("${PiRpcClient.noModelsDiagnosticPrefix}\n"));
      process.exit(code: 1);
      return process;
    },
  ).loadHistory(sessionId: "session", knownDirectories: const {});
}

final class _FakeStorageApi({
  bool missing = false,
  final String path = "/exact/session.jsonl",
  final PiSessionFileHistoryDto? history,
}) implements PiSessionStorageApi {
  final bool _missing = missing;

  @override
  Future<PiResolvedSession?> resolveSession({required String sessionId, required Set<String> knownDirectories}) async {
    if (_missing) return null;
    return PiResolvedSession(
      metadata: PiSessionMetadata(
        id: sessionId,
        cwd: "/exact/header-cwd",
        parentId: null,
        title: null,
        createdAt: null,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      path: path,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeHistoryStorageApi({required super.storageApi}) extends PiSessionHistoryStorageApi {
  @override
  Future<PiSessionFileHistoryDto> readSessionHistory({required String path}) {
    if (storageApi case _FakeStorageApi(:final history?)) return Future.value(history);
    return PiSessionHistoryStorageApi(
      storageApi: PiSessionStorageApi(environment: const {}),
    ).readSessionHistory(path: path);
  }
}

Future<String> _captureWarnings(Future<void> Function() action) async {
  final previousLevel = Log.level;
  final stderr = _BufferingStdout();
  try {
    Log.level = LogLevel.warning;
    await IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}

final class _BufferingStdout() implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
