import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeApi.replyToPermission", () {
    test("sends POST to /session/{sessionId}/permissions/{requestId} with response body", () async {
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
        response: "once",
      );

      expect(capturedRequest.method, equals("POST"));
      expect(
        capturedRequest.url.toString(),
        equals("http://localhost:1234/session/ses-456/permissions/perm-123"),
      );
      expect(jsonDecode(capturedBody), equals({"response": "once"}));
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
          response: "once",
        ),
        throwsA(isA<OpenCodeApiException>()),
      );
    });
  });
}
