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
  final closeStarted = Completer<void>();
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
    if (!closeStarted.isCompleted) closeStarted.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Models a timer firing while the higher-precision deadline is still positive.
class _EarlyTimeoutBudget() extends AntigravityAuthenticationBudget {
  this : super(timeout: const Duration(seconds: 1), abortSignal: StartAbortSignal.never);

  @override
  Duration get remaining => const Duration(milliseconds: 1);
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

  test("real loopback request settles on cancellation after dispatch", () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = server.first;
    final abort = StartAbortController();
    final client = AntigravityLoopbackClient(client: HttpClient());
    try {
      final forwarding = client.forward(
        callbackUri: Uri.parse("http://127.0.0.1:${server.port}/?code=synthetic&state=synthetic"),
        budget: AntigravityAuthenticationBudget(timeout: const Duration(seconds: 2), abortSignal: abort.signal),
      );
      final assertion = expectLater(forwarding, throwsA(isA<PluginStartAbortedException>()));
      await received;
      // The server deliberately never responds. Forced client closure must
      // settle the already-dispatched request, not just abandon its future.
      abort.abort();
      await assertion;
    } finally {
      client.dispose();
      await server.close(force: true);
    }
  });

  test("selected timeout fences a late connection even while the budget remains positive", () async {
    final http = _Http()..gate = Completer<void>();
    final client = AntigravityLoopbackClient(client: http);
    final budget = _EarlyTimeoutBudget();
    final forwarding = client.forward(callbackUri: callback, budget: budget);
    var settled = false;
    final assertion = expectLater(forwarding, throwsA(isA<TimeoutException>())).then((_) => settled = true);
    await http.closeStarted.future;
    expect(budget.remaining, greaterThan(Duration.zero));
    expect(settled, isFalse);
    http.gate!.complete();
    await assertion;
    expect(http.request.sent, isFalse);
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
      var settled = false;
      final assertion = expectLater(
        forwarding,
        throwsA(aborting ? isA<PluginStartAbortedException>() : isA<TimeoutException>()),
      ).then((_) => settled = true);
      await http.opened.future;
      if (aborting) abort.abort();
      await http.closeStarted.future;
      expect(settled, isFalse);
      expect(http.closed, isTrue);
      http.gate!.complete();
      await assertion;
      expect(http.request.sent, isFalse);
    }
  });
}
