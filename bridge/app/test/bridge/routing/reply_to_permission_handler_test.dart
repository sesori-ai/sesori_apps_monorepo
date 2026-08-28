import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/routing/reply_to_permission_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("ReplyToPermissionHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late ReplyToPermissionHandler handler;

    setUp(() async {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      await recordSessionBinding(
        database: db,
        sessionId: "ses-456",
        backendSessionId: "backend-ses-456",
        pluginId: plugin.id,
        projectId: "/repo",
        parentSessionId: null,
      );
      final pending = buildTestPendingInteractionService(database: db, plugin: plugin);
      addTearDown(pending.dispatcher.dispose);
      addTearDown(pending.service.dispose);
      handler = ReplyToPermissionHandler(pendingInteractionService: pending.service);
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("returns 409 with the archived rejection body for an archived session", () async {
      await db.sessionDao.setArchived(sessionId: "ses-456", archivedAt: 7, updatedAt: 7, projectionUpdatedAt: 7);

      final response = await handler.routeForTest(
        makeRequest(
          "POST",
          "/permission/reply",
          body: jsonEncode(
            const ReplyToPermissionRequest(
              requestId: "perm-123",
              sessionId: "ses-456",
              reply: PermissionReply.once,
            ).toJson(),
          ),
        ),
      );

      expect(response.status, 409);
      expect(
        SessionArchivedRejection.fromJson(jsonDecodeMap(response.body ?? "")),
        const SessionArchivedRejection(sessionId: "ses-456", reason: SessionArchivedReason.archivedReadOnly),
      );
      expect(plugin.lastReplyToPermissionRequestId, isNull);
    });

    test("canHandle POST /permission/reply", () {
      expect(handler.canHandle(makeRequest("POST", "/permission/reply")), isTrue);
    });

    test("does not handle GET /permission/reply", () {
      expect(handler.canHandle(makeRequest("GET", "/permission/reply")), isFalse);
    });

    test("delegates to plugin with correct arguments", () async {
      await handler.handle(
        makeRequest("POST", "/permission/reply"),
        body: const ReplyToPermissionRequest(
          requestId: "perm-123",
          sessionId: "ses-456",
          reply: PermissionReply.once,
        ),
      );

      expect(plugin.lastReplyToPermissionRequestId, equals("perm-123"));
      expect(plugin.lastReplyToPermissionSessionId, equals("backend-ses-456"));
      expect(plugin.lastReplyToPermissionReply, equals(PluginPermissionReply.once));
    });

    test("returns 200 on success", () async {
      final response = await handler.handle(
        makeRequest("POST", "/permission/reply"),
        body: const ReplyToPermissionRequest(
          requestId: "perm-123",
          sessionId: "ses-456",
          reply: PermissionReply.once,
        ),
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("returns 400 on empty request id", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/permission/reply"),
          body: const ReplyToPermissionRequest(
            requestId: "",
            sessionId: "ses-456",
            reply: PermissionReply.once,
          ),
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("returns 400 on empty session id", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/permission/reply"),
          body: const ReplyToPermissionRequest(
            requestId: "perm-123",
            sessionId: "",
            reply: PermissionReply.once,
          ),
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });
  });
}
