import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart" show AcpMethods;
import "package:grok_plugin/src/api/grok_session_store_api.dart";
import "package:grok_plugin/src/api/models/grok_session_notification_dto.dart";
import "package:grok_plugin/src/api/models/grok_session_store_dto.dart";
import "package:grok_plugin/src/repositories/grok_session_history_repository.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const cwd = "/tmp/history-project";
  const root = "root";
  late Directory sessions;
  late GrokSessionStoreApi api;
  late GrokSessionHistoryRepository repository;

  String updatesPath({required String sessionId}) =>
      p.join(sessions.path, Uri.encodeComponent(cwd), sessionId, GrokSessionStoreApi.updatesFileName);

  void writeUpdates({required String sessionId, required List<Object> updates}) {
    File(updatesPath(sessionId: sessionId))
      ..createSync(recursive: true)
      ..writeAsStringSync(updates.map((update) => update is String ? update : jsonEncode(update)).join("\n"));
  }

  Map<String, dynamic> spawn({required String childId}) => {
    "method": GrokSessionProtocol.updateMethod,
    "params": {
      "sessionId": root,
      "update": {
        "sessionUpdate": "subagent_spawned",
        "subagent_id": childId,
        "child_session_id": childId,
        "description": "Child $childId",
      },
    },
  };

  Map<String, dynamic> standard({required String sessionId, required Map<String, dynamic> update}) => {
    "method": AcpMethods.sessionUpdate,
    "params": {"sessionId": sessionId, "update": update},
  };

  setUp(() {
    sessions = Directory.systemTemp.createTempSync("grok-history-");
    api = GrokSessionStoreApi(sessionsRoot: sessions.path, pluginId: "grok-test");
    repository = GrokSessionHistoryRepository(api: api);
  });

  tearDown(() => sessions.deleteSync(recursive: true));

  test("keys exact children and concatenates only first child-owned user run", () async {
    writeUpdates(
      sessionId: root,
      updates: [
        spawn(childId: "child-a"),
        spawn(childId: "child-b"),
        spawn(childId: "child-a"),
      ],
    );
    writeUpdates(
      sessionId: "child-a",
      updates: [
        {"method": "foreign/before"},
        standard(
          sessionId: "child-a",
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "text", "text": "first "},
          },
        ),
        standard(
          sessionId: "child-a",
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "image", "data": "ignored"},
          },
        ),
        standard(
          sessionId: "child-a",
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "text", "text": "prompt"},
          },
        ),
        standard(sessionId: "child-a", update: {"sessionUpdate": "future_unknown_update"}),
        standard(
          sessionId: "child-a",
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "text", "text": " later"},
          },
        ),
      ],
    );
    writeUpdates(
      sessionId: "child-b",
      updates: [
        standard(
          sessionId: "different-child",
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "text", "text": "wrong owner"},
          },
        ),
      ],
    );

    final context = await repository.prepareReplayContext(cwd: cwd, rootSessionId: root);
    expect(context.childPrompts, {"child-a": "first prompt"});
    expect(() => context.childPrompts["child-c"] = "mutation", throwsUnsupportedError);
  });

  test("malformed child record is a private diagnosed boundary between user runs", () async {
    const secretTranscriptSource = "PRIVATE_PROMPT_SHOULD_NOT_REACH_LOGS";
    writeUpdates(
      sessionId: root,
      updates: [spawn(childId: "child")],
    );
    writeUpdates(
      sessionId: "child",
      updates: [
        standard(
          sessionId: "child",
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "text", "text": "first prompt"},
          },
        ),
        "! malformed $secretTranscriptSource",
        standard(
          sessionId: "child",
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "text", "text": " fabricated continuation"},
          },
        ),
      ],
    );

    final previousLevel = Log.level;
    final stderr = BufferingStdout();
    late List<GrokPersistedUpdateDto> updates;
    late Map<String, String> prompts;
    try {
      Log.level = LogLevel.warning;
      await IOOverrides.runZoned(
        () async {
          updates = api.readUpdates(cwd: cwd, sessionId: "child");
          prompts = (await repository.prepareReplayContext(cwd: cwd, rootSessionId: root)).childPrompts;
        },
        stderr: () => stderr,
      );
    } finally {
      Log.level = previousLevel;
    }

    expect(updates, [
      isA<GrokPersistedAcpSessionUpdateDto>(),
      isA<GrokPersistedUpdateUnknownDto>(),
      isA<GrokPersistedAcpSessionUpdateDto>(),
    ]);
    expect(prompts, {"child": "first prompt"});
    expect(stderr.text, contains("${updatesPath(sessionId: "child")}, line 2"));
    expect(stderr.text, contains("FormatException"));
    expect(stderr.text, contains("Unexpected character"));
    expect(stderr.text, contains("offset 0"));
    expect(stderr.text, contains("_parseUpdate"), reason: "the original parse stack remains useful");
    expect(stderr.text, isNot(contains(secretTranscriptSource)));
  });

  test("missing files, malformed lines, and blank first runs omit only affected children", () async {
    writeUpdates(
      sessionId: root,
      updates: [
        spawn(childId: "missing"),
        "not json",
        spawn(childId: "empty"),
        spawn(childId: "valid"),
      ],
    );
    writeUpdates(
      sessionId: "empty",
      updates: [
        standard(
          sessionId: "empty",
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "text", "text": "   "},
          },
        ),
        standard(sessionId: "empty", update: {"sessionUpdate": "future_unknown_update"}),
        standard(
          sessionId: "empty",
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "text", "text": "must not replace blank first run"},
          },
        ),
      ],
    );
    writeUpdates(
      sessionId: "valid",
      updates: [
        "broken child line",
        standard(
          sessionId: "valid",
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "text", "text": "valid prompt"},
          },
        ),
      ],
    );

    expect(
      (await repository.prepareReplayContext(cwd: cwd, rootSessionId: root)).childPrompts,
      {"valid": "valid prompt"},
    );
    expect(() => api.readUpdates(cwd: cwd, sessionId: "../root"), throwsArgumentError);
  });

  test("first child prompt boundary cancels lazy record iteration", () async {
    final earlyBoundaryApi = _EarlyBoundaryStoreApi();
    final context = await GrokSessionHistoryRepository(api: earlyBoundaryApi)
        .prepareReplayContext(cwd: cwd, rootSessionId: root)
        .timeout(const Duration(seconds: 1));

    expect(context.childPrompts, {"child": "First prompt"});
    expect(earlyBoundaryApi.childStreamCancelled, isTrue);
    expect(earlyBoundaryApi.readPastBoundary, isFalse);
  });
}

final class _EarlyBoundaryStoreApi() extends GrokSessionStoreApi {
  this : super(sessionsRoot: null, pluginId: "grok-test");

  bool childStreamCancelled = false;
  bool readPastBoundary = false;

  @override
  Stream<GrokPersistedUpdateDto> streamUpdates({required String cwd, required String sessionId}) async* {
    if (sessionId == "root") {
      yield const GrokPersistedUpdateDto.grokSessionUpdate(
        params: GrokSessionNotificationDto(
          sessionId: "root",
          update: GrokSubagentUpdate.subagentSpawned(
            subagentId: "child",
            childSessionId: "child",
            subagentType: null,
            description: "Child task",
            model: null,
          ),
        ),
      );
      return;
    }

    try {
      yield const GrokPersistedUpdateDto.acpSessionUpdate(
        params: GrokPersistedAcpNotificationDto(
          sessionId: "child",
          update: GrokPersistedAcpUpdateDto.userMessageChunk(
            content: GrokPersistedContentDto.text(text: "First prompt"),
          ),
        ),
      );
      yield const GrokPersistedUpdateDto.unknown();
      readPastBoundary = true;
      throw StateError("child transcript was read past its first prompt run");
    } finally {
      childStreamCancelled = true;
    }
  }
}
