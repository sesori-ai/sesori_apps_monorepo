import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:json_annotation/json_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

Map<String, dynamic> option({required String id, required String label, required String kind, bool warning = false}) =>
    {
      "optionId": id,
      "name": label,
      "kind": kind,
      if (warning) "_meta": {"agy.security.warning": "synthetic prompt-injection warning"},
    };

final _allow = option(id: "opaque-yes", label: "Continue", kind: "allow_once");
final _reject = option(id: "opaque-no", label: "Stop", kind: "reject_once");
final _always = option(id: "opaque-always", label: "Always", kind: "allow_always", warning: true);

AcpServerRequest request({
  Object id = 91,
  String session = "session",
  String tool = "command-1",
  String? kind = "execute",
  String title = "Synthetic question?",
  List<Map<String, dynamic>>? options,
}) => AcpServerRequest(
  id: id,
  method: AcpMethods.sessionRequestPermission,
  params: {
    "sessionId": session,
    "toolCall": {"toolCallId": tool, "title": title, "kind": ?kind},
    "options": options ?? [_allow, _always, _reject],
  },
);

class _Harness() {
  final process = FakeAcpProcess();
  final events = <BridgeSseEvent>[];
  late final client = AcpStdioClient(
    launchSpec: const AcpLaunchSpec(command: "synthetic", args: [], includeParentEnvironment: false),
    processFactory: (_) async => process,
  );
  late final service = AntigravityInteractionService(
    protocolMapper: const AntigravityProtocolMapper(),
    repository: AntigravityInteractionRepository(client: client),
  );
  late final registry = AntigravityApprovalRegistry(
    interactionService: service,
    idGenerator: null,
    emit: (event) {
      if (event is BridgeSseQuestionReplied || event is BridgeSsePermissionReplied) {
        expect(process.written, isNotEmpty, reason: "Wire dispatch precedes the terminal UI event");
      }
      events.add(event);
    },
  );
  Future<void> close() async {
    await registry.dispose();
    await client.dispose();
    await process.close();
  }

  void receive({required AcpServerRequest incoming}) => registry.handleServerRequest(request: incoming);
  String get permissionId => registry.pendingPermissionsForSession(sessionId: "session").single.id;
  String get questionId => registry.pendingForSession(sessionId: "session").single.id;
}

void main() {
  late _Harness harness;
  setUp(() async {
    harness = _Harness();
    await harness.client.connect();
  });
  tearDown(() => harness.close());

  test("neutral ambiguous attribution rejects through the connection-owned service/repository without pending UI", () {
    final AcpPendingRegistry<AntigravityInteraction> registry = harness.registry;
    registry.rejectAmbiguousServerRequest(request: request(id: "ambiguous"));
    expect(harness.process.written.single["id"], "ambiguous");
    expect(harness.process.written.single["result"], {
      "outcome": {"outcome": "cancelled"},
    });
    expect(harness.process.written.single.containsKey("error"), isFalse);
    expect(harness.events, isEmpty);
    expect(registry.hasAnyPendingInput, isFalse);
  });

  test("normal permission never silently approves and dispatches exact once-only choice once", () {
    harness.receive(incoming: request(id: "rpc-text"));
    final pending = harness.registry.pendingPermissionsForSession(sessionId: "session").single;
    expect(pending.allowAlways, isFalse);
    expect(pending.tool, "execute");
    expect(harness.process.written, isEmpty);
    expect(harness.registry.replyPermission(requestId: pending.id, reply: PluginPermissionReply.once), isTrue);
    expect(harness.registry.replyPermission(requestId: pending.id, reply: PluginPermissionReply.once), isFalse);
    expect(harness.process.written.single, {
      "jsonrpc": "2.0",
      "id": "rpc-text",
      "result": {
        "outcome": {"outcome": "selected", "optionId": "opaque-yes"},
      },
    });
    expect(harness.events.last, isA<BridgeSsePermissionReplied>());
  });

  test("missing or unknown tool kind displays an honest fallback rather than a correlation ID", () {
    for (final kind in [null, "future-kind"]) {
      harness.receive(incoming: request(kind: kind));
      final pending = harness.registry.pendingPermissionsForSession(sessionId: "session").single;
      expect(pending.tool, "tool");
      harness.registry.replyPermission(requestId: pending.id, reply: PluginPermissionReply.reject);
    }
  });

  test("decoder failures retain field and cause without rendering malformed values", () {
    const secret = "synthetic-prompt-do-not-log";
    final incoming = request();
    incoming.params["toolCall"] = {
      "toolCallId": "opaque",
      "title": [secret],
    };
    expect(
      () => const AntigravityProtocolMapper().mapPermissionRequest(request: incoming),
      throwsA(
        isA<AntigravityInteractionException>()
            .having((error) => error.toString(), "field", contains("AntigravityPermissionToolDto.title"))
            .having((error) => error.toString(), "decoder kind", contains("TypeError"))
            .having((error) => error.toString(), "privacy", isNot(contains(secret)))
            .having((error) => error.cause, "original decoder cause", isA<CheckedFromJsonException>()),
      ),
    );
    harness.receive(incoming: incoming);
    expect(harness.registry.hasAnyPendingInput, isFalse);
    expect(harness.process.written.single["result"], {
      "outcome": {"outcome": "cancelled"},
    });
  });

  test("reject chooses only advertised reject-once; absent rejection and always replies cancel", () {
    for (final reply in [PluginPermissionReply.reject, PluginPermissionReply.always]) {
      harness.receive(incoming: request());
      harness.registry.replyPermission(requestId: harness.permissionId, reply: reply);
      expect(
        harness.process.written.last["result"],
        reply == PluginPermissionReply.reject
            ? {
                "outcome": {"outcome": "selected", "optionId": "opaque-no"},
              }
            : {
                "outcome": {"outcome": "cancelled"},
              },
      );
    }
    harness.receive(incoming: request(options: [_allow]));
    harness.registry.replyPermission(requestId: harness.permissionId, reply: PluginPermissionReply.reject);
    expect(harness.process.written.last["result"], {
      "outcome": {"outcome": "cancelled"},
    });
  });

  test("interaction choices preserve reject-kind answers and exclude persistent or warning-bearing options", () async {
    harness.receive(
      incoming: request(
        tool: "interaction_choose",
        options: [
          _allow,
          _reject,
          _always,
          option(id: "warn", label: "Unsafe", kind: "allow_once", warning: true),
          option(id: "unknown", label: "Unknown", kind: "future_kind"),
          option(id: "never", label: "Never", kind: "reject_always"),
        ],
      ),
    );
    final pending = harness.registry.pendingForSession(sessionId: "session").single;
    final question = pending.questions.single;
    expect(question.options.map((value) => value.label), ["Continue", "Stop"]);
    expect(question.multiple, isFalse);
    expect(question.custom, isFalse);
    expect(harness.process.written, isEmpty);
    expect(
      await harness.registry.replyQuestion(
        requestId: pending.id,
        answers: [
          ["Stop"],
        ],
      ),
      isTrue,
    );
    expect(
      await harness.registry.replyQuestion(
        requestId: pending.id,
        answers: [
          ["Continue"],
        ],
      ),
      isFalse,
    );
    expect(harness.process.written.single["result"], {
      "outcome": {"outcome": "selected", "optionId": "opaque-no"},
    });
  });

  test("misrouted permission reply leaves a question pending; explicit question rejection cancels", () async {
    harness.receive(incoming: request(tool: "interaction_1"));
    final id = harness.questionId;
    expect(harness.registry.replyPermission(requestId: id, reply: PluginPermissionReply.once), isFalse);
    expect(harness.registry.hasAnyPendingInput, isTrue);
    expect(await harness.registry.rejectQuestion(requestId: id), isTrue);
    expect(harness.process.written.single["result"], {
      "outcome": {"outcome": "cancelled"},
    });
    expect(harness.events.last, isA<BridgeSseQuestionRejected>());
  });

  test("malformed, multiple, custom, raw-ID and modified-label answers never select a choice", () async {
    for (final answers in <List<List<String>>>[
      [],
      [[]],
      [
        ["Continue", "Stop"],
      ],
      [
        ["Continue"],
        ["Stop"],
      ],
      [
        ["opaque-yes"],
      ],
      [
        [" Continue"],
      ],
      [
        ["invented"],
      ],
    ]) {
      harness.receive(incoming: request(tool: "interaction_1"));
      expect(await harness.registry.replyQuestion(requestId: harness.questionId, answers: answers), isTrue);
      expect(harness.process.written.last["result"], {
        "outcome": {"outcome": "cancelled"},
      });
      expect(harness.events.last, isA<BridgeSseQuestionRejected>());
      expect(harness.registry.hasAnyPendingInput, isFalse);
    }
  });

  test("ambiguous IDs, labels or once-only permission choices are refused without invisible pending entries", () {
    final inputs = [
      request(options: [_allow, _allow]),
      request(
        tool: "interaction_1",
        options: [
          _allow,
          option(id: "other", label: "Continue", kind: "reject_once"),
        ],
      ),
      request(
        options: [
          _allow,
          option(id: "other", label: "Other", kind: "allow_once"),
        ],
      ),
      request(
        options: [
          _allow,
          _reject,
          option(id: "other", label: "Other", kind: "reject_once"),
        ],
      ),
      request(options: [_always, _reject]),
      request(
        options: [
          option(id: "warn", label: "Warn", kind: "allow_once", warning: true),
          _reject,
        ],
      ),
      request(tool: "interaction_1", options: [_allow]),
      request(options: []),
    ];
    for (final incoming in inputs) {
      harness.receive(incoming: incoming);
      expect(harness.process.written.last["result"], {
        "outcome": {"outcome": "cancelled"},
      });
    }
    expect(harness.events, isEmpty);
    expect(harness.registry.hasAnyPendingInput, isFalse);
  });

  test("malformed and bounded external fields fail closed before presentation", () {
    final inputs = [
      const AcpServerRequest(id: 1, method: AcpMethods.sessionRequestPermission, params: {}),
      request(session: ""),
      request(title: " " * 10),
      request(title: "x" * 4097),
      request(tool: "x" * 257),
      request(options: List.filled(33, _allow)),
      request(
        options: [option(id: "x" * 257, label: "Value", kind: "allow_once")],
      ),
      request(
        options: [option(id: "x", label: "x" * 513, kind: "allow_once")],
      ),
      request(
        options: [
          {"optionId": 42, "name": "Invalid", "kind": "allow_once"},
        ],
      ),
    ];
    for (final incoming in inputs) {
      harness.receive(incoming: incoming);
      expect(harness.process.written.last["result"], {
        "outcome": {"outcome": "cancelled"},
      });
    }
    expect(harness.events, isEmpty);
    expect(harness.registry.hasAnyPendingInput, isFalse);
  });

  test("unhandled methods use an explicit JSON-RPC error instead of inventing a permission result", () {
    harness.receive(
      incoming: const AcpServerRequest(id: 9, method: "extension/unknown", params: {}),
    );
    expect(harness.process.written.single["id"], 9);
    expect(harness.process.written.single["error"], containsPair("code", -32601));
    expect(harness.events, isEmpty);
  });

  test("session cancellation and disposal settle each pending input once and detach source stream", () async {
    final source = StreamController<AcpServerRequest>(sync: true);
    harness.registry.attach(stream: source.stream);
    source.add(request(id: 1));
    source.add(request(id: 2, session: "other", tool: "interaction_2"));
    harness.registry.cancelForSession(sessionId: "session");
    expect(harness.registry.pendingSessionIds, {"other"});
    expect(harness.process.written, hasLength(1));
    await harness.registry.dispose();
    await harness.registry.dispose();
    expect(harness.process.written, hasLength(2));
    expect(
      harness.process.written.map((frame) => frame["result"]),
      everyElement({
        "outcome": {"outcome": "cancelled"},
      }),
    );
    expect(harness.registry.hasAnyPendingInput, isFalse);
    source.add(request(id: 3));
    expect(harness.process.written, hasLength(2));
    await source.close();
  });

  test("separate connection registries never dispatch to another attempt", () async {
    final other = _Harness();
    await other.client.connect();
    try {
      harness.receive(incoming: request());
      other.receive(incoming: request());
      harness.registry.replyPermission(requestId: harness.permissionId, reply: PluginPermissionReply.once);
      expect(harness.process.written, hasLength(1));
      expect(other.process.written, isEmpty);
      expect(other.registry.hasAnyPendingInput, isTrue);
    } finally {
      await other.close();
    }
  });
}
