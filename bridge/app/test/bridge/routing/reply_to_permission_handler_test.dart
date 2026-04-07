import "package:sesori_bridge/src/bridge/repositories/permission_repository.dart";
import "package:sesori_bridge/src/bridge/routing/reply_to_permission_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("ReplyToPermissionHandler", () {
    late FakeBridgePlugin plugin;
    late PermissionRepository permissionRepository;
    late ReplyToPermissionHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      permissionRepository = PermissionRepository(plugin: plugin);
      handler = ReplyToPermissionHandler(permissionRepository: permissionRepository);
    });

    tearDown(() => plugin.close());

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
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastReplyToPermissionRequestId, equals("perm-123"));
      expect(plugin.lastReplyToPermissionSessionId, equals("ses-456"));
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
        pathParams: {},
        queryParams: {},
        fragment: null,
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
          pathParams: {},
          queryParams: {},
          fragment: null,
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
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });
  });
}
