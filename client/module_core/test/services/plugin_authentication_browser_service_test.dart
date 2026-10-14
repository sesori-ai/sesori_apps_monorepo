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

class _ClosingLoopbackSession() extends _FakeLoopbackSession {
  final Completer<void> closeGate = Completer();
  @override
  Future<void> close() async {
    await super.close();
    await closeGate.future;
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

final _owner = PluginAuthenticationBrowserOwner(
  bridgeId: "fixture",
  connectionEpoch: 1,
  purpose: PluginAuthenticationBrowserPurpose.provider,
);
final _mcpOwner = PluginAuthenticationBrowserOwner(
  bridgeId: "fixture",
  connectionEpoch: 1,
  purpose: PluginAuthenticationBrowserPurpose.mcp,
);

void main() {
  for (final (firstOwner, secondOwner) in [(_owner, _mcpOwner), (_mcpOwner, _owner)]) {
    test("${firstOwner.purpose.name} then ${secondOwner.purpose.name} preserves the first callback", () async {
      final session = _FakeLoopbackSession();
      final browser = _FakeBrowser(returnsToApp: false)
        ..actions.add(
          ({required authorizationUri, required callbackScheme}) async => const PluginAuthenticationBrowserOpened(),
        )
        ..actions.add(
          ({required authorizationUri, required callbackScheme}) async => const PluginAuthenticationBrowserOpened(),
        );
      final service = PluginAuthenticationBrowserService(
        loopbackServer: _ImmediateLoopbackServer(session: session),
        browser: browser,
      );
      final challenge = PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse("https://provider.example/authorize"),
        expectedCallbackUri: session.expectedCallbackUri,
      );
      final first = service.authenticate(
        owner: firstOwner,
        challenge: challenge,
        isLocalBridge: false,
        reuseActiveListener: false,
        onPhase: (_) {},
        onDetachedFailure: (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      final second = service.authenticate(
        owner: secondOwner,
        challenge: challenge,
        isLocalBridge: false,
        reuseActiveListener: false,
        onPhase: (_) {},
        onDetachedFailure: (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      try {
        expect(session.closes, 0);
        expect(browser.opens, 1);
        expect(await second, isA<PluginAuthenticationBrowserBusy>());
        expect(await service.cancel(owner: secondOwner), isNull);
        expect(session.closes, 0);
        expect(
          await service.authenticate(
            owner: secondOwner,
            challenge: challenge,
            isLocalBridge: false,
            reuseActiveListener: true,
            onPhase: (_) => fail("Foreign retry emitted a phase"),
            onDetachedFailure: (_) {},
          ),
          isA<PluginAuthenticationBrowserBusy>(),
        );
        final callback = session.expectedCallbackUri.replace(queryParameters: {"code": "fixture", "state": "fixture"});
        session.callbackCompleter.complete(callback);
        expect((await first as PluginAuthenticationBrowserCaptured).callbackUri, callback);
      } finally {
        await service.cancel(owner: firstOwner);
        await first;
        await second;
      }
    });
  }
  test("local browser remains owned until native settlement releases it", () async {
    final browser = _FakeBrowser(returnsToApp: false)
      ..actions.add(
        ({required authorizationUri, required callbackScheme}) async => const PluginAuthenticationBrowserOpened(),
      );
    final service = PluginAuthenticationBrowserService(loopbackServer: _DelayedLoopbackServer(), browser: browser);
    final challenge = PluginAuthenticationBrowserChallenge(
      authorizationUri: Uri.parse("https://fixture.example/authorize"),
      expectedCallbackUri: Uri.parse("http://127.0.0.1:43120/callback"),
    );
    addTearDown(() => service.cancel(owner: _owner));
    expect(
      await service.authenticate(
        owner: _owner,
        challenge: challenge,
        isLocalBridge: true,
        reuseActiveListener: false,
        onPhase: (_) {},
        onDetachedFailure: (_) {},
      ),
      isA<PluginAuthenticationBrowserDirect>(),
    );
    expect(
      await service.authenticate(
        owner: _mcpOwner,
        challenge: challenge,
        isLocalBridge: false,
        reuseActiveListener: false,
        onPhase: (_) => fail("Busy start emitted a phase"),
        onDetachedFailure: (_) {},
      ),
      isA<PluginAuthenticationBrowserBusy>(),
    );
    expect(browser.opens, 1);
    expect(await service.cancel(owner: _mcpOwner), isNull);
    expect(await service.cancel(owner: _owner), isNull);
  });

  test("listener cleanup retains ownership until its close completes", () async {
    final session = _ClosingLoopbackSession();
    final browser = _FakeBrowser(returnsToApp: false)
      ..actions.add(
        ({required authorizationUri, required callbackScheme}) async => const PluginAuthenticationBrowserOpened(),
      );
    final service = PluginAuthenticationBrowserService(
      loopbackServer: _ImmediateLoopbackServer(session: session),
      browser: browser,
    );
    final challenge = PluginAuthenticationBrowserChallenge(
      authorizationUri: Uri.parse("https://fixture.example/authorize"),
      expectedCallbackUri: session.expectedCallbackUri,
    );
    final first = service.authenticate(
      owner: _owner,
      challenge: challenge,
      isLocalBridge: false,
      reuseActiveListener: false,
      onPhase: (_) {},
      onDetachedFailure: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    final cancelling = service.cancel(owner: _owner);
    try {
      expect(
        await service.authenticate(
          owner: _mcpOwner,
          challenge: challenge,
          isLocalBridge: false,
          reuseActiveListener: false,
          onPhase: (_) {},
          onDetachedFailure: (_) {},
        ),
        isA<PluginAuthenticationBrowserBusy>(),
      );
      expect(session.closes, 1);
    } finally {
      session.closeGate.complete();
      await cancelling;
      expect(await first, isA<PluginAuthenticationBrowserFlowCancelled>());
    }
  });

  test("binds before native open and captures callback while bounce carries nonce only", () async {
    final port = await _unusedLoopbackPort();
    final callbackUri = Uri.parse("http://127.0.0.1:$port/callback");
    final browser = _FakeBrowser(returnsToApp: true)..actions.add(_completeCallback(callbackUri: callbackUri));
    final service = PluginAuthenticationBrowserService(
      loopbackServer: PluginAuthenticationLoopbackServer(),
      browser: browser,
    );
    addTearDown(() => service.cancel(owner: _owner));
    final phases = <PluginAuthenticationBrowserPhase>[];

    final result = await service.authenticate(
      owner: _owner,
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
        owner: _owner,
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
    addTearDown(() => service.cancel(owner: _owner));

    final result = await service.authenticate(
      owner: _owner,
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
        owner: _owner,
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
      owner: _owner,
      challenge: challenge,
      isLocalBridge: false,
      reuseActiveListener: false,
      onPhase: (_) {},
      onDetachedFailure: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(await service.cancel(owner: _owner), isNull);
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
    addTearDown(() => service.cancel(owner: _owner));
    final challenge = PluginAuthenticationBrowserChallenge(
      authorizationUri: Uri.parse("https://provider.example/authorize"),
      expectedCallbackUri: callbackUri,
    );

    expect(
      await service.authenticate(
        owner: _owner,
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
        owner: _owner,
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
      owner: _owner,
      challenge: challenge,
      isLocalBridge: false,
      reuseActiveListener: false,
      onPhase: (_) {},
      onDetachedFailure: (_) {},
    );
    final retry = await service.authenticate(
      owner: _owner,
      challenge: challenge,
      isLocalBridge: false,
      reuseActiveListener: true,
      onPhase: (_) {},
      onDetachedFailure: (_) {},
    );

    expect(first, isA<PluginAuthenticationBrowserFlowFailed>());
    final firstFailure = first as PluginAuthenticationBrowserFlowFailed;
    expect(firstFailure.innerError, PluginAuthenticationBrowserFailureReason.invalidNativeReturn);
    expect(firstFailure.retryableWithActiveListener, isFalse);
    expect(retry, isA<PluginAuthenticationBrowserFlowFailed>());
    final retryFailure = retry as PluginAuthenticationBrowserFlowFailed;
    expect(retryFailure.innerError, PluginAuthenticationBrowserFailureReason.callbackListenerInactive);
    expect(retryFailure.retryableWithActiveListener, isFalse);
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
      owner: _owner,
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

    expect(await service.cancel(owner: _owner), isNull);
    expect(await authentication, isA<PluginAuthenticationBrowserFlowCancelled>());
    expect(session.closes, 1);
    browserResult.complete(const PluginAuthenticationBrowserCancelled());
  });

  test("local direct ownership expires and reports its detached failure", () {
    fakeAsync((async) {
      final browser = _FakeBrowser(returnsToApp: false)
        ..actions.add(
          ({required Uri authorizationUri, required String callbackScheme}) async =>
              const PluginAuthenticationBrowserOpened(),
        );
      final service = PluginAuthenticationBrowserService(loopbackServer: _DelayedLoopbackServer(), browser: browser);
      final failures = <PluginAuthenticationBrowserFlowFailed>[];
      PluginAuthenticationBrowserFlowResult? result;
      service
          .authenticate(
            owner: _owner,
            challenge: PluginAuthenticationBrowserChallenge(
              authorizationUri: Uri.parse("https://fixture.example/authorize"),
              expectedCallbackUri: Uri.parse("http://127.0.0.1:43120/callback"),
            ),
            isLocalBridge: true,
            reuseActiveListener: false,
            onPhase: (_) {},
            onDetachedFailure: failures.add,
          )
          .then((value) => result = value);
      async.flushMicrotasks();
      expect(result, isA<PluginAuthenticationBrowserDirect>());
      expect(failures, isEmpty);
      async.elapse(const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(failures.single.innerError, isA<TimeoutException>());
      expect(failures.single.retryableWithActiveListener, isFalse);
      expect(async.pendingTimers, isEmpty);
    });
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
            owner: _owner,
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
            owner: _owner,
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
            owner: _owner,
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
