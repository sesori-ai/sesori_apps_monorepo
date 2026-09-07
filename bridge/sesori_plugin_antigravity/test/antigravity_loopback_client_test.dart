import "dart:async";
import "dart:io";

import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class _Response({@override required final int statusCode}) extends Stream<List<int>> implements HttpClientResponse {
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<List<int>>.empty().listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request() implements HttpClientRequest {
  @override
  bool followRedirects = true;
  bool sent = false;
  int status = 200;
  @override
  Future<HttpClientResponse> close() async {
    sent = true;
    return _Response(statusCode: status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Http() implements HttpClient {
  @override
  String Function(Uri)? findProxy;
  final request = _Request();
  final opened = Completer<void>();
  Completer<void>? gate;
  Uri? uri;
  bool closed = false;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    uri = url;
    opened.complete();
    await gate?.future;
    return request;
  }

  @override
  void close({bool force = false}) {
    expect(force, isTrue);
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final callback = Uri.parse("http://127.0.0.1:8765/?state=synthetic-state&code=synthetic-code");
  test("sends exact GET directly without proxy, redirects, or response logging", () async {
    final http = _Http()..request.status = 302;
    final client = AntigravityLoopbackClient(client: http);
    expect(http.findProxy!(callback), "DIRECT");
    final status = await client.forward(
      callbackUri: callback,
      budget: AntigravityAuthenticationBudget(timeout: const Duration(seconds: 2), abortSignal: StartAbortSignal.never),
    );
    expect(status, 302);
    expect(http.uri, callback);
    expect(http.request.followRedirects, isFalse);
    expect(http.closed, isTrue);
  });

  test("timeout or abort closes stalled connection and rejects late request before send", () async {
    for (final aborting in [false, true]) {
      final abort = StartAbortController();
      final http = _Http()..gate = Completer<void>();
      final client = AntigravityLoopbackClient(client: http);
      final forwarding = client.forward(
        callbackUri: callback,
        budget: AntigravityAuthenticationBudget(
          timeout: aborting ? const Duration(seconds: 2) : const Duration(milliseconds: 20),
          abortSignal: abort.signal,
        ),
      );
      final assertion = expectLater(
        forwarding,
        throwsA(aborting ? isA<PluginStartAbortedException>() : isA<TimeoutException>()),
      );
      await http.opened.future;
      if (aborting) abort.abort();
      await assertion;
      expect(http.closed, isTrue);
      http.gate!.complete();
      await Future<void>(() {});
      expect(http.request.sent, isFalse);
    }
  });
}
