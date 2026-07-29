import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:sesori_auth/src/client/api_error.dart";
import "package:sesori_auth/src/client/api_response.dart";
import "package:sesori_auth/src/client/http_api_client.dart";
import "package:test/test.dart";

final _url = Uri.parse("https://api.example.com/preferences");

class _RecordingClient extends http.BaseClient {
  _RecordingClient({required this.statusCode, required this.responseBody});

  final int statusCode;
  final String responseBody;

  http.BaseRequest? request;
  String? requestBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    requestBody = (request as http.Request).body;
    return http.StreamedResponse(Stream.value(utf8.encode(responseBody)), statusCode);
  }
}

void main() {
  group("put", () {
    test("sends a JSON PUT with headers and parses a success response", () async {
      final transport = _RecordingClient(
        statusCode: 200,
        responseBody: '{"status":"updated"}',
      );
      final client = HttpApiClient(transport);

      final response = await client.put<String>(
        url: _url,
        fromJson: (json) => (json as Map<String, dynamic>)["status"] as String,
        headers: {"X-Request-Source": "settings"},
        body: {"enabled": true},
        contentType: null,
        logBody: false,
      );

      expect(transport.request?.method, "PUT");
      expect(transport.request?.url, _url);
      expect(transport.request?.headers["X-Request-Source"], "settings");
      expect(
        transport.request?.headers[HttpHeaders.contentTypeHeader],
        ContentType.json.toString(),
      );
      expect(jsonDecode(transport.requestBody!), {"enabled": true});
      expect(response, isA<SuccessResponse<String>>());
      expect((response as SuccessResponse<String>).data, "updated");
    });

    test("returns status and body for a non-success response", () async {
      final client = HttpApiClient(
        _RecordingClient(
          statusCode: 422,
          responseBody: '{"error":"invalid preference"}',
        ),
      );

      final response = await client.put<String>(
        url: _url,
        fromJson: (_) => throw StateError("non-success body must not be parsed"),
        headers: null,
        body: {"enabled": true},
        contentType: null,
        logBody: false,
      );

      final error = (response as ErrorResponse<String>).error as NonSuccessCodeError;
      expect(error.errorCode, 422);
      expect(error.rawErrorString, '{"error":"invalid preference"}');
    });

    test("returns a parsing error for malformed success JSON", () async {
      final client = HttpApiClient(
        _RecordingClient(statusCode: 200, responseBody: "not-json"),
      );

      final response = await client.put<String>(
        url: _url,
        fromJson: (json) => json as String,
        headers: null,
        body: {"enabled": true},
        contentType: null,
        logBody: false,
      );

      final error = (response as ErrorResponse<String>).error as JsonParsingError;
      expect(error.jsonString, "not-json");
    });
  });
}
