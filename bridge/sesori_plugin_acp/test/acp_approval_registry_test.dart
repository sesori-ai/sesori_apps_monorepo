import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("AcpApprovalRegistry", () {
    late StreamController<AcpServerRequest> requests;
    late List<BridgeSseEvent> emitted;
    late List<(Object, Object?)> responds;
    late List<(Object, int, String)> errors;
    late AcpApprovalRegistry registry;

    setUp(() {
      requests = StreamController<AcpServerRequest>.broadcast();
      emitted = [];
      responds = [];
      errors = [];
      registry = AcpApprovalRegistry(
        emit: emitted.add,
        respond: (id, result) => responds.add((id, result)),
        respondError: (id, code, message) => errors.add((id, code, message)),
      );
      registry.attach(requests.stream);
    });

    tearDown(() async {
      await registry.dispose();
      await requests.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    AcpServerRequest permission() => const AcpServerRequest(
      id: 7,
      method: "session/request_permission",
      params: {
        "sessionId": "s1",
        "toolCall": {"toolCallId": "tc-1", "title": "Run rm", "kind": "execute"},
        "options": [
          {"optionId": "opt-allow-once", "name": "Allow", "kind": "allow_once"},
          {"optionId": "opt-allow-always", "name": "Always", "kind": "allow_always"},
          {"optionId": "opt-reject", "name": "Reject", "kind": "reject_once"},
        ],
      },
    );

    test("permission request surfaces as BridgeSsePermissionAsked", () async {
      requests.add(permission());
      await pump();
      final asked = emitted.single as BridgeSsePermissionAsked;
      expect(asked.sessionID, "s1");
      expect(asked.tool, "execute");
      expect(asked.description, "Run rm");
      expect(asked.requestID, isNotEmpty);
    });

    test("permission with no resolvable session is auto-cancelled, not enqueued", () async {
      // No sessionId in params and no activeSessionResolver → resolves to "". A
      // request stamped with "" is dropped by the mobile client, so it must be
      // auto-cancelled here instead of enqueued (which would deadlock the turn
      // on a reply that can never arrive).
      requests.add(const AcpServerRequest(
        id: 9,
        method: "session/request_permission",
        params: {
          "toolCall": {"toolCallId": "tc-9", "title": "Run rm", "kind": "execute"},
          "options": [
            {"optionId": "opt-allow-once", "name": "Allow", "kind": "allow_once"},
          ],
        },
      ));
      await pump();
      // Responded immediately with a cancelled outcome…
      final (id, result) = responds.single;
      expect(id, 9);
      expect(result, const {
        "outcome": {"outcome": "cancelled"},
      });
      // …and nothing was surfaced to the user or left pending.
      expect(emitted, isEmpty);
      expect(registry.pendingPermissionsForSession(""), isEmpty);
    });

    test("reply 'once' echoes the allow_once optionId", () async {
      requests.add(permission());
      await pump();
      final id = (emitted.single as BridgeSsePermissionAsked).requestID;

      expect(registry.replyPermission(id, PluginPermissionReply.once), isTrue);
      final (_, result) = responds.single;
      expect((result! as Map)["outcome"], {"outcome": "selected", "optionId": "opt-allow-once"});
      expect(emitted.whereType<BridgeSsePermissionReplied>(), hasLength(1));
    });

    test("reply 'always' echoes the allow_always optionId", () async {
      requests.add(permission());
      await pump();
      final id = (emitted.single as BridgeSsePermissionAsked).requestID;
      registry.replyPermission(id, PluginPermissionReply.always);
      final (_, result) = responds.single;
      expect(((result! as Map)["outcome"] as Map)["optionId"], "opt-allow-always");
    });

    test("reply 'reject' echoes the reject optionId", () async {
      requests.add(permission());
      await pump();
      final id = (emitted.single as BridgeSsePermissionAsked).requestID;
      registry.replyPermission(id, PluginPermissionReply.reject);
      final (_, result) = responds.single;
      expect(((result! as Map)["outcome"] as Map)["optionId"], "opt-reject");
    });

    test("missing matching option falls back to cancelled", () async {
      requests.add(const AcpServerRequest(
        id: 9,
        method: "session/request_permission",
        params: {
          "sessionId": "s1",
          "toolCall": {"kind": "execute"},
          "options": [
            {"optionId": "opt-allow-once", "kind": "allow_once"},
          ],
        },
      ));
      await pump();
      final id = (emitted.single as BridgeSsePermissionAsked).requestID;
      registry.replyPermission(id, PluginPermissionReply.reject);
      final (_, result) = responds.single;
      expect((result! as Map)["outcome"], {"outcome": "cancelled"});
    });

    test("reply 'once' does NOT escalate to allow_always when allow_once is absent", () async {
      // The agent only offers a session-persistent option. A user who chose a
      // one-time approval must not be silently upgraded to it — cancel instead.
      requests.add(const AcpServerRequest(
        id: 21,
        method: "session/request_permission",
        params: {
          "sessionId": "s1",
          "toolCall": {"kind": "execute"},
          "options": [
            {"optionId": "opt-allow-always", "kind": "allow_always"},
            {"optionId": "opt-reject", "kind": "reject_once"},
          ],
        },
      ));
      await pump();
      final id = (emitted.single as BridgeSsePermissionAsked).requestID;
      registry.replyPermission(id, PluginPermissionReply.once);
      final (_, result) = responds.single;
      expect((result! as Map)["outcome"], {"outcome": "cancelled"});
    });

    test("cancelForSession resolves pending permission + question and emits clearing events", () async {
      requests.add(permission());
      await pump();
      registry.addPendingQuestion(
        bridgeRequestId: "q-1",
        acpId: 5,
        sessionId: "s1",
        questions: const [
          PluginQuestionInfo(question: "Pick", header: "H", options: [], multiple: false, custom: false),
        ],
        replyBuilder: (answers) => null,
      );
      responds.clear();
      errors.clear();
      emitted.clear();

      registry.cancelForSession("s1");

      // Permission answered with a cancelled outcome; question answered with an error.
      expect(responds.single.$2, const {
        "outcome": {"outcome": "cancelled"},
      });
      expect(errors.single.$2, -32603);
      // Both pending entries cleared, and the phone gets clearing events.
      expect(registry.hasPendingInput("s1"), isFalse);
      expect(emitted.whereType<BridgeSsePermissionReplied>(), hasLength(1));
      expect(emitted.whereType<BridgeSseQuestionRejected>(), hasLength(1));
    });

    test("unknown server methods get a soft -32601 error", () async {
      requests.add(const AcpServerRequest(id: 11, method: "cursor/mystery", params: {}));
      await pump();
      expect(errors.single.$2, -32601);
    });

    test("registered questions reply via the builder and surface as pending", () {
      registry.addPendingQuestion(
        bridgeRequestId: "q-1",
        acpId: 5,
        sessionId: "s1",
        questions: [
          const PluginQuestionInfo(
            question: "Pick one",
            header: "Choice",
            options: [],
            multiple: false,
            custom: false,
          ),
        ],
        replyBuilder: (answers) => {"selected": answers.first.first},
      );

      expect(registry.pendingForSession("s1"), hasLength(1));
      expect(registry.replyQuestion("q-1", [["yes"]]), isTrue);
      final (_, result) = responds.single;
      expect((result! as Map)["selected"], "yes");
      expect(emitted.whereType<BridgeSseQuestionReplied>(), hasLength(1));
    });
  });
}
