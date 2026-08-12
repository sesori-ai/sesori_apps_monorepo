import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _HangingClient() extends http.BaseClient {
  bool aborted = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final response = Completer<http.StreamedResponse>();
    if (request case http.Abortable(:final abortTrigger?)) {
      abortTrigger.whenComplete(() {
        aborted = true;
        response.completeError(http.RequestAbortedException(request.url));
      });
    }
    return response.future;
  }
}

void main() {
  test("the deadline aborts a remote image request", () {
    fakeAsync((async) {
      final client = _HangingClient();
      MessageImageApiResult? result;

      unawaited(
        MessageImageApi(client: client)
            .fetch(
              url: Uri.parse("https://files.example.com/image.png"),
              maxBytes: 1024,
              timeout: const Duration(seconds: 1),
            )
            .then((value) => result = value),
      );
      async.elapse(const Duration(seconds: 1));

      expect(client.aborted, isTrue);
      expect(result, isA<MessageImageApiNetworkFailure>());
    });
  });
}
