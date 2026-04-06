import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/opencode_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PermissionReply;
import "package:test/test.dart";

void main() {
  group("OpenCodeApi.replyToPermission", () {
    test("sends POST to /permission/{requestId}/reply with reply body", () async {
      late http.BaseRequest capturedRequest;
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = request.body;
        return http.Response("true", 200);
      });

      final api = OpenCodeApi(
        serverURL: "http://localhost:1234",
        password: "test-pass",
        client: mockClient,
      );

      await api.replyToPermission(
        requestId: "perm-123",
        sessionId: "ses-456",
        reply: PermissionReply.once,
      );

      expect(capturedRequest.method, equals("POST"));
      expect(
        capturedRequest.url.toString(),
        equals("http://localhost:1234/permission/perm-123/reply"),
      );
      expect(jsonDecode(capturedBody), equals({"reply": "once"}));
      expect(capturedRequest.headers["authorization"], isNotNull);
      expect(capturedRequest.headers["content-type"], equals("application/json"));
    });

    test("throws OpenCodeApiException on server error", () async {
      final mockClient = MockClient((request) async {
        return http.Response("Internal Server Error", 500);
      });

      final api = OpenCodeApi(
        serverURL: "http://localhost:1234",
        password: "test-pass",
        client: mockClient,
      );

      expect(
        () => api.replyToPermission(
          requestId: "perm-123",
          sessionId: "ses-456",
          reply: PermissionReply.once,
        ),
        throwsA(isA<OpenCodeApiException>()),
      );
    });
  });
}
