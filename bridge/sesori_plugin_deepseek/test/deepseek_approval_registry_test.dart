import "dart:async";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  late FakeAcpProcess fake;
  late AcpStdioClient client;
  late DeepSeekApprovalRegistry registry;
  late List<BridgeSseEvent> events;
  late int nextBridgeId;
  AcpServerRequest questionRequest(int id, Map<String, dynamic> params) => AcpServerRequest(
    id: id,
    method: DeepSeekAcpApi.askUserQuestionMethod,
    params: params,
  );
  setUp(() async {
    fake = FakeAcpProcess();
    client = AcpStdioClient(
      launchSpec: const AcpLaunchSpec(command: "deepseek", args: ["serve"]),
      processFactory: (_) async => fake,
    );
    await client.connect();
    events = [];
    nextBridgeId = 0;
    registry = DeepSeekApprovalRegistry(
      client: client,
      emit: events.add,
      api: const DeepSeekAcpApi(pluginId: DeepSeekIdentity.id),
      idGenerator: () => "request-${++nextBridgeId}",
      activeSessionResolver: () => "active-session",
    );
  });
  tearDown(() async {
    await registry.dispose();
    await client.dispose();
    await fake.close();
  });
  test("production plugin composes the DeepSeek approval registry", () async {
    const api = DeepSeekAcpApi(pluginId: DeepSeekIdentity.id);
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
    final childSessionTracker = AcpChildSessionTracker();
    final mapper = DeepSeekEventMapper(
      launchDirectory: "/project",
      pluginId: DeepSeekIdentity.id,
      configurationTracker: configurationTracker,
      childSessions: childSessionTracker,
      api: api,
      messageTimeParser: const DeepSeekMessageTimeParser(),
      subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
    );
    final plugin = DeepSeekPlugin(
      launchSpec: const AcpLaunchSpec(command: "deepseek", args: []),
      launchDirectory: "/project",
      processFactory: (_) async => fake,
      childSessionTracker: childSessionTracker,
      mapper: mapper,
      api: api,
      historyRepository: DeepSeekHistoryRepository(
        api: api,
        eventMapper: mapper,
        pluginId: DeepSeekIdentity.id,
        messageTimeParser: const DeepSeekMessageTimeParser(),
        subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
      ),
      deepSeekSessionService: DeepSeekSessionService(
        repository: const DeepSeekSessionRepository(api: api),
        childSessions: childSessionTracker,
      ),
      deepSeekSessionOptionsService: DeepSeekSessionOptionsService(
        repository: const DeepSeekCatalogRepository(api: api, mapper: DeepSeekCatalogMapper()),
        configurationTracker: configurationTracker,
        pluginId: DeepSeekIdentity.id,
        discoveryTimeout: const Duration(seconds: 30),
      ),
      commandTracker: commandTracker,
      sessionOptionsService: AcpSessionOptionsService(
        configurationTracker: configurationTracker,
        commandTracker: commandTracker,
        pluginId: DeepSeekIdentity.id,
        agentDisplayName: "DeepSeek",
      ),
    );
    final built = plugin.buildApprovalRegistry(client);
    expect(built, isA<DeepSeekApprovalRegistry>());
    await built.dispose();
    await plugin.dispose();
  });
  test("option, custom, and free-form answers preserve ordered question IDs", () {
    registry.handleExtensionRequest(
      questionRequest(7, const {
        "sessionId": "session-1",
        "questions": [
          {
            "id": "q-option",
            "text": "Proceed?",
            "options": ["Yes", "No"],
            "multiSelect": true,
          },
          {"id": "q-free", "text": "Why?", "detail": "Explain the tradeoff."},
        ],
      }),
    );
    final questions = (events.single as BridgeSseQuestionAsked).questions;
    expect(questions.first.custom, isTrue);
    expect(questions.last.question, "Why?\n\nExplain the tradeoff.");
    expect(
      registry.replyQuestion(
        requestId: "request-1",
        answers: const [
          ["Yes", "With safeguards"],
          ["Because"],
        ],
      ),
      isTrue,
    );
    expect(fake.written.single["id"], 7);
    expect((fake.written.single["result"] as Map)["answers"], [
      {
        "questionId": "q-option",
        "selectedLabels": ["Yes"],
        "customAnswer": "With safeguards",
      },
      {"questionId": "q-free", "selectedLabels": <String>[], "customAnswer": "Because"},
    ]);
  });
  test("standard permissions retain active-session fallback", () async {
    registry.attach(stream: client.serverRequests);
    fake.emit({
      "jsonrpc": "2.0",
      "id": 6,
      "method": AcpMethods.sessionRequestPermission,
      "params": {
        "toolCall": {"toolCallId": "call-1", "title": "Edit file", "kind": "edit"},
        "options": [
          {"optionId": "allow-once", "name": "Allow once", "kind": "allow_once"},
          {"optionId": "reject-once", "name": "Reject", "kind": "reject_once"},
        ],
      },
    });
    await Future<void>.delayed(Duration.zero);

    final asked = events.single as BridgeSsePermissionAsked;
    expect([asked.sessionID, asked.tool, asked.allowAlways], ["active-session", "edit", false]);
    expect(registry.replyPermission(requestId: asked.requestID, reply: PluginPermissionReply.once), isTrue);
    expect(fake.written.single["result"], {
      "outcome": {"outcome": "selected", "optionId": "allow-once"},
    });
  });
  test("two sessions retain exact question and request correlation", () {
    for (final entry in [(11, "session-1", "q1"), (12, "session-2", "q2")]) {
      registry.handleExtensionRequest(
        questionRequest(entry.$1, {
          "sessionId": entry.$2,
          "questions": [
            {
              "id": entry.$3,
              "text": "Proceed?",
              "options": ["Yes", "No"],
            },
          ],
        }),
      );
    }

    expect(events.whereType<BridgeSseQuestionAsked>().map((event) => event.sessionID), ["session-1", "session-2"]);
    expect(
      registry.replyQuestion(
        requestId: "request-2",
        answers: const [
          ["No"],
        ],
      ),
      isTrue,
    );
    expect(
      registry.replyQuestion(
        requestId: "request-1",
        answers: const [
          ["Yes"],
        ],
      ),
      isTrue,
    );
    expect(fake.written.map((frame) => frame["id"]), [12, 11]);
    expect((fake.written.first["result"] as Map)["answers"], [
      {
        "questionId": "q2",
        "selectedLabels": ["No"],
      },
    ]);
  });
  test("abort clears only its session and discards a late reply", () async {
    for (final entry in [(21, "session-1", "q1"), (22, "session-2", "q2")]) {
      registry.handleExtensionRequest(
        questionRequest(entry.$1, {
          "sessionId": entry.$2,
          "questions": [
            {
              "id": entry.$3,
              "text": "Proceed?",
              "options": ["Yes", "No"],
            },
          ],
        }),
      );
    }

    registry.cancelForSession(sessionId: "session-1");
    await Future<void>.delayed(Duration.zero);
    expect(
      registry.replyQuestion(
        requestId: "request-1",
        answers: const [
          ["Yes"],
        ],
      ),
      isFalse,
    );
    expect(registry.pendingForSession(sessionId: "session-1"), isEmpty);
    expect(registry.pendingForSession(sessionId: "session-2"), hasLength(1));
    expect(fake.written.single["error"], {"code": -32603, "message": "aborted"});
  });
  test("plan review exposes fixed options and rejects custom input", () async {
    registry.handleExtensionRequest(
      questionRequest(13, const {
        "sessionId": "session-1",
        "questions": [
          {
            "id": "plan",
            "text": "Review plan",
            "intent": "plan_review",
            "approveLabel": "Approve",
            "options": ["Approve", "Reject"],
          },
        ],
      }),
    );
    final question = (events.single as BridgeSseQuestionAsked).questions.single;
    expect([question.multiple, question.custom], [false, false]);

    final logs = await _captureWarnings(() async {
      expect(
        registry.replyQuestion(
          requestId: "request-1",
          answers: const [
            ["Change it"],
          ],
        ),
        isTrue,
      );
    });
    await Future<void>.delayed(Duration.zero);
    expect(logs, contains("DeepSeek plan-review questions do not accept custom answers"));
    expect(fake.written.single["error"], {"code": -32603, "message": "invalid answer"});
    expect(
      registry.replyQuestion(
        requestId: "request-1",
        answers: const [
          ["Approve"],
        ],
      ),
      isFalse,
    );
  });
  test("duplicate selected labels reject and settle the question", () async {
    registry.handleExtensionRequest(
      questionRequest(14, const {
        "sessionId": "session-1",
        "questions": [
          {
            "id": "q1",
            "text": "Pick",
            "options": ["A", "B"],
            "multiSelect": true,
          },
        ],
      }),
    );
    final logs = await _captureWarnings(() async {
      expect(
        registry.replyQuestion(
          requestId: "request-1",
          answers: const [
            ["A", "A"],
          ],
        ),
        isTrue,
      );
    });
    await Future<void>.delayed(Duration.zero);
    expect(logs, contains("DeepSeek question answers must not contain duplicates"));
    expect(fake.written.single["error"], {"code": -32603, "message": "invalid answer"});
    expect(registry.hasAnyPendingInput, isFalse);
  });
  test("empty answer rejects and settles pending question", () async {
    registry.handleExtensionRequest(
      questionRequest(8, const {
        "sessionId": "session-1",
        "questions": [
          {
            "id": "q1",
            "text": "Proceed?",
            "options": ["Yes", "No"],
          },
        ],
      }),
    );
    expect(registry.replyQuestion(requestId: "request-1", answers: const [<String>[]]), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(fake.written.single["error"], {"code": -32603, "message": "invalid answer"});
    expect(registry.hasAnyPendingInput, isFalse);
  });
  test("oversized custom answer rejects and settles pending question", () async {
    registry.handleExtensionRequest(
      questionRequest(9, const {
        "sessionId": "session-1",
        "questions": [
          {"id": "q1", "text": "Explain"},
        ],
      }),
    );
    expect(
      registry.replyQuestion(
        requestId: "request-1",
        answers: [
          ["x".padRight(2049, "x")],
        ],
      ),
      isTrue,
    );
    await Future<void>.delayed(Duration.zero);
    expect(fake.written.single["error"], {"code": -32603, "message": "invalid answer"});
    expect(registry.hasAnyPendingInput, isFalse);
  });
  test("malformed question rejects without pending state", () {
    registry.handleExtensionRequest(questionRequest(10, const {"questions": <Object>[]}));
    expect(fake.written.single["error"], {"code": -32602, "message": "Invalid DeepSeek question request"});
    expect(registry.hasAnyPendingInput, isFalse);
  });
  test("dispose rejects pending DeepSeek questions and clears phone state", () async {
    registry.handleExtensionRequest(
      questionRequest(15, const {
        "sessionId": "session-1",
        "questions": [
          {
            "id": "q1",
            "text": "Proceed?",
            "options": ["Yes", "No"],
          },
        ],
      }),
    );
    await registry.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(fake.written.single["error"], {"code": -32603, "message": "bridge dispose"});
    expect(events.last, isA<BridgeSseQuestionRejected>());
    expect(registry.hasAnyPendingInput, isFalse);
  });
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
