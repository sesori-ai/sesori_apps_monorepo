import "dart:async";
import "dart:collection";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:sesori_dart_core/src/foundation/io/plugin_authentication_loopback_server.dart";
import "package:sesori_dart_core/src/foundation/platform/plugin_authentication_browser.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_management_result.dart";
import "package:sesori_dart_core/src/services/plugin_authentication_browser_service.dart";
import "package:test/test.dart";

typedef _BrowserAction = Future<PluginAuthenticationBrowserResult> Function({
  required Uri authorizationUri,
  required String callbackScheme,
});

class _FakeLoopbackSession() implements PluginAuthenticationLoopbackSession {
  final Completer<Uri?> callbackCompleter = Completer();
  int closes = 0;

  @override
  Uri? get bounceUri => null;

  @override
  Future<Uri?> get callback => callbackCompleter.future;

  @override
  Uri get expectedCallbackUri => Uri.parse("http://127.0.0.1:43120/callback");

  @override
  Future<void> close() async {
    closes++;
    if (!callbackCompleter.isCompleted) callbackCompleter.complete();
  }
}

class _DelayedLoopbackServer() extends PluginAuthenticationLoopbackServer {
  final Completer<PluginAuthenticationLoopbackSession> binding = Completer();

  @override
  Future<PluginAuthenticationLoopbackSession> bind({required Uri expectedCallbackUri, required Uri? bounceUri}) =>
      binding.future;
}

class _ImmediateLoopbackServer({required final PluginAuthenticationLoopbackSession session})
    extends PluginAuthenticationLoopbackServer {
  @override
  Future<PluginAuthenticationLoopbackSession> bind({required Uri expectedCallbackUri, required Uri? bounceUri}) async =>
      session;
}

class _FakeBrowser({@override required final bool returnsToApp}) implements PluginAuthenticationBrowser {
  final Queue<_BrowserAction> actions = Queue();
  int opens = 0;

  @override
  Future<PluginAuthenticationBrowserResult> open({
    required Uri authorizationUri,
    required String callbackScheme,
  }) {
    opens++;
    return actions.removeFirst()(authorizationUri: authorizationUri, callbackScheme: callbackScheme);
  }
}

Future<int> _unusedLoopbackPort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

_BrowserAction _completeCallback({required Uri callbackUri}) =>
    ({
      required Uri authorizationUri,
      required String callbackScheme,
    }) async {
      final client = HttpClient();
      try {
        final request =
            await client.getUrl(
                callbackUri.replace(queryParameters: const {"state": "synthetic-state", "code": "synthetic-code"}),
              )
              ..followRedirects = false;
        final response = await request.close();
        final location = response.headers.value(HttpHeaders.locationHeader);
        return PluginAuthenticationBrowserReturned(callbackUri: Uri.parse(location!));
      } finally {
        client.close();
      }
    };

void main() {
  test("binds before native open and captures callback while bounce carries nonce only", () async {
    final port = await _unusedLoopbackPort();
    final callbackUri = Uri.parse("http://127.0.0.1:$port/callback");
    final browser = _FakeBrowser(returnsToApp: true)..actions.add(_completeCallback(callbackUri: callbackUri));
    final service = PluginAuthenticationBrowserService(
      loopbackServer: PluginAuthenticationLoopbackServer(),
      browser: browser,
    );
    addTearDown(service.cancelActive);
    final phases = <PluginAuthenticationBrowserPhase>[];

    final result = await service.authenticate(
      challenge: PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse("https://provider.example/authorize"),
        expectedCallbackUri: callbackUri,
      ),
      isLocalBridge: false,
      reuseActiveListener: false,
      onPhase: phases.add,
      onDetachedFailure: (_) {},
    );

    expect(result, isA<PluginAuthenticationBrowserCaptured>());
    final captured = (result as PluginAuthenticationBrowserCaptured).callbackUri;
    expect(captured.queryParameters, const {"state": "synthetic-state", "code": "synthetic-code"});
    expect(phases, [PluginAuthenticationBrowserPhase.opening, PluginAuthenticationBrowserPhase.waiting]);
  });

  test("verified local flow opens directly without binding the bridge-owned callback port", () async {
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);
    final browser = _FakeBrowser(returnsToApp: false)
      ..actions.add(
        ({
          required Uri authorizationUri,
          required String callbackScheme,
        }) async => const PluginAuthenticationBrowserOpened(),
      );
    final service = PluginAuthenticationBrowserService(
      loopbackServer: PluginAuthenticationLoopbackServer(),
      browser: browser,
    );

    expect(
      await service.authenticate(
        challenge: PluginAuthenticationBrowserChallenge(
          authorizationUri: Uri.parse("https://provider.example/authorize"),
          expectedCallbackUri: Uri.parse("http://127.0.0.1:${occupied.port}/callback"),
        ),
        isLocalBridge: true,
        reuseActiveListener: false,
        onPhase: (_) {},
        onDetachedFailure: (_) {},
      ),
      isA<PluginAuthenticationBrowserDirect>(),
    );
    expect(browser.opens, 1);
  });

  test("bind failure fails closed before browser open", () async {
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);
    final browser = _FakeBrowser(returnsToApp: true);
    final service = PluginAuthenticationBrowserService(
      loopbackServer: PluginAuthenticationLoopbackServer(),
      browser: browser,
    );
    addTearDown(service.cancelActive);

    final result = await service.authenticate(
      challenge: PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse("https://provider.example/authorize"),
        expectedCallbackUri: Uri.parse("http://127.0.0.1:${occupied.port}/callback"),
      ),
      isLocalBridge: false,
      reuseActiveListener: false,
      onPhase: (_) {},
      onDetachedFailure: (_) {},
    );

    expect(result, isA<PluginAuthenticationBrowserFlowFailed>());
    expect(browser.opens, isZero);
  });

  test("native cancellation closes listener and remains distinct from success", () async {
    final port = await _unusedLoopbackPort();
    final browser = _FakeBrowser(returnsToApp: true)
      ..actions.add(
        ({
          required Uri authorizationUri,
          required String callbackScheme,
        }) async => const PluginAuthenticationBrowserCancelled(),
      );
    final service = PluginAuthenticationBrowserService(
      loopbackServer: PluginAuthenticationLoopbackServer(),
      browser: browser,
    );

    expect(
      await service.authenticate(
        challenge: PluginAuthenticationBrowserChallenge(
          authorizationUri: Uri.parse("https://provider.example/authorize"),
          expectedCallbackUri: Uri.parse("http://127.0.0.1:$port/callback"),
        ),
        isLocalBridge: false,
        reuseActiveListener: false,
        onPhase: (_) {},
        onDetachedFailure: (_) {},
      ),
      isA<PluginAuthenticationBrowserFlowCancelled>(),
    );
    final rebound = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await rebound.close();
  });

  test("cancellation fences a pending bind, closes its late session, and never opens browser", () async {
    final loopback = _DelayedLoopbackServer();
    final session = _FakeLoopbackSession();
    final browser = _FakeBrowser(returnsToApp: true);
    final service = PluginAuthenticationBrowserService(loopbackServer: loopback, browser: browser);
    final challenge = PluginAuthenticationBrowserChallenge(
      authorizationUri: Uri.parse("https://provider.example/authorize"),
      expectedCallbackUri: Uri.parse("http://127.0.0.1:43120/callback"),
    );

    final authentication = service.authenticate(
      challenge: challenge,
      isLocalBridge: false,
      reuseActiveListener: false,
      onPhase: (_) {},
      onDetachedFailure: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(await service.cancelActive(), isNull);
    loopback.binding.complete(session);

    expect(await authentication, isA<PluginAuthenticationBrowserFlowCancelled>());
    await Future<void>.delayed(Duration.zero);
    expect(session.closes, 1);
    expect(browser.opens, isZero);
  });

  test("launch failure retains listener so retry uses the same challenge without rebinding", () async {
    final port = await _unusedLoopbackPort();
    final callbackUri = Uri.parse("http://127.0.0.1:$port/callback");
    final browser = _FakeBrowser(returnsToApp: true)
      ..actions.add(
        ({
          required Uri authorizationUri,
          required String callbackScheme,
        }) async => PluginAuthenticationBrowserFailed(
          innerError: StateError("synthetic launch failure"),
          stackTrace: StackTrace.current,
        ),
      )
      ..actions.add(_completeCallback(callbackUri: callbackUri));
    final service = PluginAuthenticationBrowserService(
      loopbackServer: PluginAuthenticationLoopbackServer(),
      browser: browser,
    );
    addTearDown(service.cancelActive);
    final challenge = PluginAuthenticationBrowserChallenge(
      authorizationUri: Uri.parse("https://provider.example/authorize"),
      expectedCallbackUri: callbackUri,
    );

    expect(
      await service.authenticate(
        challenge: challenge,
        isLocalBridge: false,
        reuseActiveListener: false,
        onPhase: (_) {},
        onDetachedFailure: (_) {},
      ),
      isA<PluginAuthenticationBrowserFlowFailed>(),
    );
    expect(
      await service.authenticate(
        challenge: challenge,
        isLocalBridge: false,
        reuseActiveListener: true,
        onPhase: (_) {},
        onDetachedFailure: (_) {},
      ),
      isA<PluginAuthenticationBrowserCaptured>(),
    );
    expect(browser.opens, 2);
  });

  test("invalid native bounce is fatal and cannot rebind the issued challenge", () async {
    final port = await _unusedLoopbackPort();
    final callbackUri = Uri.parse("http://127.0.0.1:$port/callback");
    final browser = _FakeBrowser(returnsToApp: true)
      ..actions.add(
        ({required Uri authorizationUri, required String callbackScheme}) async =>
            PluginAuthenticationBrowserReturned(callbackUri: Uri.parse("com.sesori.auth://complete/wrong-nonce")),
      );
    final service = PluginAuthenticationBrowserService(
      loopbackServer: PluginAuthenticationLoopbackServer(),
      browser: browser,
    );
    final challenge = PluginAuthenticationBrowserChallenge(
      authorizationUri: Uri.parse("https://provider.example/authorize"),
      expectedCallbackUri: callbackUri,
    );

    final first = await service.authenticate(
      challenge: challenge,
      isLocalBridge: false,
      reuseActiveListener: false,
      onPhase: (_) {},
      onDetachedFailure: (_) {},
    );
    final retry = await service.authenticate(
      challenge: challenge,
      isLocalBridge: false,
      reuseActiveListener: true,
      onPhase: (_) {},
      onDetachedFailure: (_) {},
    );

    expect(first, isA<PluginAuthenticationBrowserFlowFailed>());
    expect((first as PluginAuthenticationBrowserFlowFailed).retryableWithActiveListener, isFalse);
    expect(retry, isA<PluginAuthenticationBrowserFlowFailed>());
    expect((retry as PluginAuthenticationBrowserFlowFailed).retryableWithActiveListener, isFalse);
    expect(browser.opens, 1);
    final rebound = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await rebound.close();
  });

  test("explicit cancellation closes listener while native browser remains pending", () async {
    final session = _FakeLoopbackSession();
    final browserResult = Completer<PluginAuthenticationBrowserResult>();
    final browser = _FakeBrowser(returnsToApp: true)
      ..actions.add(
        ({required Uri authorizationUri, required String callbackScheme}) => browserResult.future,
      );
    final service = PluginAuthenticationBrowserService(
      loopbackServer: _ImmediateLoopbackServer(session: session),
      browser: browser,
    );
    final authentication = service.authenticate(
      challenge: PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse("https://provider.example/authorize"),
        expectedCallbackUri: Uri.parse("http://127.0.0.1:43120/callback"),
      ),
      isLocalBridge: false,
      reuseActiveListener: false,
      onPhase: (_) {},
      onDetachedFailure: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(browser.opens, 1);

    expect(await service.cancelActive(), isNull);
    expect(await authentication, isA<PluginAuthenticationBrowserFlowCancelled>());
    expect(session.closes, 1);
    browserResult.complete(const PluginAuthenticationBrowserCancelled());
  });

  test("single lifetime deadline closes listener while native browser remains pending", () {
    fakeAsync((async) {
      final session = _FakeLoopbackSession();
      final browserResult = Completer<PluginAuthenticationBrowserResult>();
      final browser = _FakeBrowser(returnsToApp: true)
        ..actions.add(
          ({required Uri authorizationUri, required String callbackScheme}) => browserResult.future,
        );
      final service = PluginAuthenticationBrowserService(
        loopbackServer: _ImmediateLoopbackServer(session: session),
        browser: browser,
      );
      PluginAuthenticationBrowserFlowResult? result;

      service
          .authenticate(
            challenge: PluginAuthenticationBrowserChallenge(
              authorizationUri: Uri.parse("https://provider.example/authorize"),
              expectedCallbackUri: Uri.parse("http://127.0.0.1:43120/callback"),
            ),
            isLocalBridge: false,
            reuseActiveListener: false,
            onPhase: (_) {},
            onDetachedFailure: (_) {},
          )
          .then((value) => result = value);
      async.flushMicrotasks();
      expect(browser.opens, 1);
      expect(result, isNull);

      async.elapse(const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(result, isA<PluginAuthenticationBrowserFlowFailed>());
      expect((result! as PluginAuthenticationBrowserFlowFailed).retryableWithActiveListener, isFalse);
      expect(session.closes, 1);
    });
  });

  test("retryable launch failure expires against original deadline and cannot rebind", () {
    fakeAsync((async) {
      final session = _FakeLoopbackSession();
      final browser = _FakeBrowser(returnsToApp: true)
        ..actions.add(
          ({required Uri authorizationUri, required String callbackScheme}) async => PluginAuthenticationBrowserFailed(
            innerError: StateError("synthetic launch failure"),
            stackTrace: StackTrace.current,
          ),
        );
      final service = PluginAuthenticationBrowserService(
        loopbackServer: _ImmediateLoopbackServer(session: session),
        browser: browser,
      );
      final challenge = PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse("https://provider.example/authorize"),
        expectedCallbackUri: Uri.parse("http://127.0.0.1:43120/callback"),
      );
      PluginAuthenticationBrowserFlowResult? first;
      final detachedFailures = <PluginAuthenticationBrowserFlowFailed>[];

      service
          .authenticate(
            challenge: challenge,
            isLocalBridge: false,
            reuseActiveListener: false,
            onPhase: (_) {},
            onDetachedFailure: detachedFailures.add,
          )
          .then((value) => first = value);
      async.flushMicrotasks();
      expect(first, isA<PluginAuthenticationBrowserFlowFailed>());
      expect((first! as PluginAuthenticationBrowserFlowFailed).retryableWithActiveListener, isTrue);
      expect(session.closes, isZero);

      async.elapse(const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(detachedFailures.single.retryableWithActiveListener, isFalse);
      expect(session.closes, 1);

      PluginAuthenticationBrowserFlowResult? retry;
      service
          .authenticate(
            challenge: challenge,
            isLocalBridge: false,
            reuseActiveListener: true,
            onPhase: (_) {},
            onDetachedFailure: detachedFailures.add,
          )
          .then((value) => retry = value);
      async.flushMicrotasks();
      expect(retry, isA<PluginAuthenticationBrowserFlowFailed>());
      expect(browser.opens, 1);
    });
  });
}
