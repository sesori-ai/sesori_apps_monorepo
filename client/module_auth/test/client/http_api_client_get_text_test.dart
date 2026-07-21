import "dart:async";
import "dart:convert";

import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:sesori_auth/src/client/api_error.dart";
import "package:sesori_auth/src/client/api_response.dart";
import "package:sesori_auth/src/client/http_api_client.dart";
import "package:test/test.dart";

final _url = Uri.parse("https://api.example.com/terms");

/// Answers every request with a fixed status and body.
class _StubClient extends http.BaseClient {
  _StubClient({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);
  }
}

/// A server that never answers. Only the request's own abort trigger ends it —
/// the same way `IOClient` fails a request whose trigger fires.
class _HangingClient extends http.BaseClient {
  bool aborted = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final completer = Completer<http.StreamedResponse>();
    if (request case http.Abortable(:final abortTrigger?)) {
      abortTrigger.whenComplete(() {
        aborted = true;
        completer.completeError(http.RequestAbortedException(request.url));
      });
    }
    return completer.future;
  }
}

void main() {
  test("returns a text document's body verbatim", () async {
    final client = HttpApiClient(_StubClient(statusCode: 200, body: "# Terms\n\nBody."));

    final response = await client.getText(url: _url);

    expect(response, isA<SuccessResponse<String>>());
    expect((response as SuccessResponse<String>).data, "# Terms\n\nBody.");
  });

  test("reports a non-success status instead of its body", () async {
    final client = HttpApiClient(_StubClient(statusCode: 503, body: "unavailable"));

    final response = await client.getText(url: _url);

    expect((response as ErrorResponse<String>).error, isA<NonSuccessCodeError>());
  });

  test("the deadline aborts a request that never answers", () {
    fakeAsync((async) {
      final transport = _HangingClient();
      ApiResponse<String>? response;

      unawaited(HttpApiClient(transport).getText(url: _url).then((r) => response = r));
      async.elapse(const Duration(seconds: 20));

      // Abandoning the future alone would leave the connection open, so a
      // retry after a timeout would stack another hung request on top.
      expect(transport.aborted, isTrue);
      expect((response! as ErrorResponse<String>).error, isA<DartHttpClientError>());
    });
  });
}
