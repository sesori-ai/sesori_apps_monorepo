import "dart:io";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_auth/src/client/api_response.dart";
import "package:sesori_auth/src/client/http_api_client.dart";
import "package:test/test.dart";

final _url = Uri.parse("https://api.example.invalid/auth/bridges/fixture-id");

void main() {
  for (final (status, body) in [(200, '{"ok":true}'), (204, "")]) {
    test("bodyless DELETE omits implicit JSON content type and accepts $status", () async {
      final transport = MockClient((request) async {
        expect(request.method, "DELETE");
        expect(request.url, _url);
        expect(request.body, isEmpty);
        expect(request.headers[HttpHeaders.contentTypeHeader], isNull);
        expect(request.headers[HttpHeaders.authorizationHeader], "Bearer fixture-token");
        expect(request.headers["X-Request-Source"], "logout");
        return http.Response(body, status);
      });
      final client = HttpApiClient(transport);
      final response = await client.delete<void>(
        _url,
        fromJson: (json) {
          if (status == 204) expect(json, isNull);
        },
        headers: {
          HttpHeaders.authorizationHeader: "Bearer fixture-token",
          "X-Request-Source": "logout",
        },
      );
      expect(response, isA<SuccessResponse<void>>());
    });
  }

  test("bodyless DELETE preserves an explicitly requested content type", () async {
    final transport = MockClient((request) async {
      expect(request.method, "DELETE");
      expect(request.body, isEmpty);
      expect(request.headers[HttpHeaders.contentTypeHeader], ContentType.text.toString());
      return http.Response("", 204);
    });
    final response = await HttpApiClient(transport).delete<void>(
      _url,
      fromJson: (_) {},
      contentType: ContentType.text,
    );
    expect(response, isA<SuccessResponse<void>>());
  });
}
