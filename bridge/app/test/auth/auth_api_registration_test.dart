import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/auth_api.dart";
import "package:sesori_bridge/src/foundation/abortable_request.dart";
import "package:test/test.dart";

void main() {
  group("AuthApi.registerBridge", () {
    test("posts name, platform and bridgeId with bearer token and parses a 200 response", () async {
      final server = await _BridgesTestServer.start(statusCode: 200);
      addTearDown(server.close);

      final api = _createApi(server);
      final summary = await api.registerBridge(
        name: "dev-laptop",
        platform: "macos",
        bridgeId: "br_existing01",
        accessToken: "access-token",
      );

      expect(summary.id, equals("br_server001"));
      expect(summary.name, equals("dev-laptop"));
      expect(summary.platform, equals("macos"));
      final request = server.requests.single;
      expect(request.method, equals("POST"));
      expect(request.path, equals("/auth/bridges"));
      expect(request.authorization, equals("Bearer access-token"));
      expect(
        jsonDecode(request.body),
        equals({"name": "dev-laptop", "platform": "macos", "bridgeId": "br_existing01"}),
      );
    });

    test("omits bridgeId from the body when null and accepts a 201 response", () async {
      final server = await _BridgesTestServer.start(statusCode: 201);
      addTearDown(server.close);

      final api = _createApi(server);
      final summary = await api.registerBridge(
        name: "dev-laptop",
        platform: "linux",
        bridgeId: null,
        accessToken: "access-token",
      );

      expect(summary.id, equals("br_server001"));
      expect(jsonDecode(server.requests.single.body), equals({"name": "dev-laptop", "platform": "linux"}));
    });

    test("throws BridgeRegistrationException carrying the status code on failure", () async {
      final server = await _BridgesTestServer.start(statusCode: 500);
      addTearDown(server.close);

      final api = _createApi(server);

      await expectLater(
        api.registerBridge(name: "dev-laptop", platform: "macos", bridgeId: null, accessToken: "access-token"),
        throwsA(isA<BridgeRegistrationException>().having((e) => e.statusCode, "statusCode", 500)),
      );
    });
  });

  group("AuthApi.deleteBridge", () {
    test("deletes /auth/bridges/:bridgeId with bearer token", () async {
      final server = await _BridgesTestServer.start(statusCode: 200);
      addTearDown(server.close);

      final api = _createApi(server);
      await api.deleteBridge(bridgeId: "br_existing01", accessToken: "access-token");

      final request = server.requests.single;
      expect(request.method, equals("DELETE"));
      expect(request.path, equals("/auth/bridges/br_existing01"));
      expect(request.authorization, equals("Bearer access-token"));
    });

    test("URL-encodes a bridgeId that is not URL-safe (corrupt token file)", () async {
      final server = await _BridgesTestServer.start(statusCode: 200);
      addTearDown(server.close);

      final api = _createApi(server);
      await api.deleteBridge(bridgeId: "br weird/../id?x=1", accessToken: "access-token");

      final request = server.requests.single;
      expect(request.method, equals("DELETE"));
      expect(request.path, equals("/auth/bridges/br%20weird%2F..%2Fid%3Fx%3D1"));
    });

    test("throws BridgeRegistrationException with status 404 for unknown bridges", () async {
      final server = await _BridgesTestServer.start(statusCode: 404);
      addTearDown(server.close);

      final api = _createApi(server);

      await expectLater(
        api.deleteBridge(bridgeId: "br_unknown01", accessToken: "access-token"),
        throwsA(isA<BridgeRegistrationException>().having((e) => e.statusCode, "statusCode", 404)),
      );
    });
  });
}

AuthApi _createApi(_BridgesTestServer server) {
  final client = http.Client();
  addTearDown(client.close);
  return AuthApi(
    authBackendUrl: server.baseUrl,
    client: client,
    requestDeadline: AuthApi.defaultRequestDeadline,
    sendRequest: sendRequestWithDeadline,
  );
}

class const _RecordedRequest({
  required final String method,
  required final String path,
  required final String? authorization,
  required final String body,
});

class _BridgesTestServer._(final HttpServer _server, final int _statusCode) {
  final List<_RecordedRequest> requests = [];

  static Future<_BridgesTestServer> start({required int statusCode}) async {
    final server = await HttpServer.bind("127.0.0.1", 0);
    final testServer = _BridgesTestServer._(server, statusCode);
    server.listen(testServer._handle);
    return testServer;
  }

  String get baseUrl => "http://${_server.address.host}:${_server.port}";

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    requests.add(
      _RecordedRequest(
        method: request.method,
        path: request.uri.path,
        authorization: request.headers.value(HttpHeaders.authorizationHeader),
        body: body,
      ),
    );

    request.response.statusCode = _statusCode;
    request.response.headers.contentType = ContentType.json;
    if (_statusCode != 200 && _statusCode != 201) {
      request.response.write(jsonEncode({"error": "request failed"}));
    } else if (request.method == "DELETE") {
      request.response.write(jsonEncode({"ok": true}));
    } else {
      final requested = jsonDecode(body) as Map<String, dynamic>;
      request.response.write(
        jsonEncode({
          "id": "br_server001",
          "name": requested["name"],
          "platform": requested["platform"],
          "addedAt": "2026-06-01T00:00:00.000Z",
          "lastSeenAt": null,
        }),
      );
    }
    await request.response.close();
  }
}
