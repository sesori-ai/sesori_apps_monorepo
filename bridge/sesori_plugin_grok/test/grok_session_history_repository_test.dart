import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart" show AcpMethods;
import "package:grok_plugin/src/api/grok_session_store_api.dart";
import "package:grok_plugin/src/api/models/grok_session_notification_dto.dart";
import "package:grok_plugin/src/api/models/grok_session_store_dto.dart";
import "package:grok_plugin/src/repositories/grok_session_history_repository.dart";
import "package:grok_plugin/src/repositories/models/grok_session_replay_context.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const cwd = "/tmp/history-project";

  test("malformed transcript boundaries omit source while preserving diagnostics", () async {
    final sessions = Directory.systemTemp.createTempSync("grok-history-");
    addTearDown(() => sessions.deleteSync(recursive: true));
    final api = GrokSessionStoreApi(sessionsRoot: sessions.path, pluginId: "grok-test");
    final repository = GrokSessionHistoryRepository(api: api);
    final project = p.join(sessions.path, Uri.encodeComponent(cwd));
    final rootUpdates = File(p.join(project, "root", GrokSessionStoreApi.updatesFileName))..createSync(recursive: true);
    rootUpdates.writeAsStringSync(
      [
        _spawnEnvelope(rootSessionId: "root", childSessionId: "missing"),
        _spawnEnvelope(rootSessionId: "root", childSessionId: "child"),
      ].map(jsonEncode).join("\n"),
    );
    const secretTranscriptSource = "PRIVATE_PROMPT_SHOULD_NOT_REACH_LOGS";
    final childUpdates = File(p.join(project, "child", GrokSessionStoreApi.updatesFileName))
      ..createSync(recursive: true);
    childUpdates.writeAsStringSync(
      [
        jsonEncode({"method": "future/update"}),
        jsonEncode(_userEnvelope(sessionId: "child", text: "First prompt")),
        "! malformed $secretTranscriptSource",
        jsonEncode(_userEnvelope(sessionId: "child", text: " fabricated continuation")),
      ].join("\n"),
    );

    final previousLevel = Log.level;
    final stderr = BufferingStdout();
    late GrokSessionReplayContext context;
    try {
      Log.level = LogLevel.warning;
      context = await IOOverrides.runZoned(
        () => repository.prepareReplayContext(cwd: cwd, rootSessionId: "root"),
        stderr: () => stderr,
      );
    } finally {
      Log.level = previousLevel;
    }

    expect(context.childPrompts, {"child": "First prompt"});
    expect(stderr.text, contains("${childUpdates.path}, line 3"));
    expect(stderr.text, contains("FormatException"));
    expect(stderr.text, contains("Unexpected character"));
    expect(stderr.text, contains("offset 0"));
    expect(stderr.text, contains("_parseUpdate"), reason: "the original parse stack remains useful");
    expect(stderr.text, isNot(contains(secretTranscriptSource)));
  });

  test("first child prompt boundary cancels lazy record iteration", () async {
    final api = _EarlyBoundaryStoreApi();
    final context = await GrokSessionHistoryRepository(api: api)
        .prepareReplayContext(cwd: cwd, rootSessionId: "root")
        .timeout(const Duration(seconds: 1));

    expect(context.childPrompts, {"child": "First prompt"});
    expect(api.childStreamCancelled, isTrue);
    expect(api.readPastBoundary, isFalse);
  });
}

Map<String, dynamic> _spawnEnvelope({required String rootSessionId, required String childSessionId}) => {
  "method": GrokSessionProtocol.updateMethod,
  "params": {
    "sessionId": rootSessionId,
    "update": {
      "sessionUpdate": "subagent_spawned",
      "subagent_id": childSessionId,
      "child_session_id": childSessionId,
      "description": "Child task",
    },
  },
};

Map<String, dynamic> _userEnvelope({required String sessionId, required String text}) => {
  "method": AcpMethods.sessionUpdate,
  "params": {
    "sessionId": sessionId,
    "update": {
      "sessionUpdate": "user_message_chunk",
      "content": {"type": "text", "text": text},
    },
  },
};

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
