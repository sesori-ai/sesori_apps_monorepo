import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/foundation/abortable_request_client.dart";
import "package:test/test.dart";

void main() {
  const requestClient = AbortableRequestClient();
  final url = Uri.parse("https://auth.example.test/request");

  test("an already-aborted signal prevents the request from starting", () async {
    final client = _ImmediateClient();
    final abortSignal = AbortSignal()..abort();

    await expectLater(
      requestClient.send(
        client: client,
        method: "POST",
        url: url,
        headers: const {"Authorization": "Bearer token"},
        body: "payload",
        deadline: const Duration(seconds: 1),
        abortSignal: abortSignal,
      ),
      throwsA(isA<http.RequestAbortedException>()),
    );

    expect(client.sendCount, 0);
  });

  test("deadline remains active while the response body is consumed", () async {
    final client = _BodyStallClient();

    await expectLater(
      requestClient.send(
        client: client,
        method: "GET",
        url: url,
        headers: null,
        body: null,
        deadline: Duration.zero,
        abortSignal: null,
      ),
      throwsA(isA<http.RequestAbortedException>()),
    );

    expect(client.abortObserved, isTrue);
  });

  test("completed responses detach abort and deadline listeners", () async {
    final client = _ImmediateClient();
    final abortSignal = AbortSignal();

    final response = await requestClient.send(
      client: client,
      method: "POST",
      url: url,
      headers: const {"Content-Type": "text/plain"},
      body: "payload",
      deadline: const Duration(milliseconds: 5),
      abortSignal: abortSignal,
    );
    abortSignal.abort();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(response.body, "ok");
    expect(client.abortObserved, isFalse);
    expect(client.request?.headers["Content-Type"], startsWith("text/plain"));
    expect(client.request?.finalize().bytesToString(), completion("payload"));
  });
}

final class _ImmediateClient() extends http.BaseClient {
  int sendCount = 0;
  bool abortObserved = false;
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCount++;
    this.request = request;
    final abortable = request as http.Abortable;
    unawaited(abortable.abortTrigger?.then((_) => abortObserved = true));
    return http.StreamedResponse(Stream.value(utf8.encode("ok")), 200, request: request);
  }
}

final class _BodyStallClient() extends http.BaseClient {
  bool abortObserved = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final controller = StreamController<List<int>>();
    final abortable = request as http.Abortable;
    unawaited(
      abortable.abortTrigger?.then((_) async {
        abortObserved = true;
        controller.addError(http.RequestAbortedException(request.url));
        await controller.close();
      }),
    );
    return http.StreamedResponse(controller.stream, 200, request: request);
  }
}
