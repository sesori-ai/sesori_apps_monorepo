import "dart:async";
import "dart:io";

import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/codex_mcp_callback_api.dart";
import "package:codex_plugin/src/api/models/codex_mcp_oauth_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_mcp_authentication_repository.dart";
import "package:codex_plugin/src/repositories/codex_mcp_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_mcp_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_mcp_authentication_exception.dart";
import "package:codex_plugin/src/repositories/models/codex_mcp_login_challenge.dart";
import "package:codex_plugin/src/services/codex_mcp_authentication_service.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _target = PluginMcpServerTarget(
  scope: PluginMcpSessionScope(sessionId: "thread"),
  serverKey: "fixture",
);
const _callback = "http://127.0.0.1:43123/callback";
String _authorization({required String callback}) =>
    Uri.https("issuer.fixture", "/authorize", {"redirect_uri": callback, "state": "fixture-state"}).toString();

class _Transport() implements CodexAppServerTransport {
  final notices = StreamController<CodexServerNotification>.broadcast(sync: true);
  final calls = <({String method, Object? params})>[];
  Object? loginResponse = {"authorizationUrl": _authorization(callback: _callback)};
  String authStatus = "notLoggedIn";
  bool hasServer = true;
  void Function()? duringLogin;
  final loginCalled = Completer<void>();
  @override
  Stream<CodexServerNotification> get notifications => notices.stream;
  @override
  Future<Object?> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    calls.add((method: method, params: params));
    if (method == "mcpServerStatus/list") {
      return {
        "data": [
          if (hasServer) {"name": "fixture", "authStatus": authStatus, "tools": <String, Object?>{}},
        ],
      };
    }
    if (method != "mcpServer/oauth/login") throw StateError("Unexpected native mutation $method");
    if (!loginCalled.isCompleted) loginCalled.complete();
    duringLogin?.call();
    final response = loginResponse;
    if (response is Exception) throw response;
    return response;
  }

  void complete({
    required bool success,
    required String? error,
    String name = "fixture",
    String? threadId = "thread",
  }) => notices.add(
    CodexServerNotification(
      method: "mcpServer/oauthLogin/completed",
      params: {"name": name, "success": success, "error": error, "threadId": ?threadId},
    ),
  );
}

class _Harness({required final http.Client? callbackClient, required final String userAgent}) {
  final transport = _Transport();
  final callbacks = <http.Request>[];
  late final api = CodexAppServerApi(client: transport);
  late final inventory = CodexMcpRepository(
    appServerApi: api,
    mapper: CodexMcpMapper(userAgent: userAgent),
  );
  late final repository = CodexMcpAuthenticationRepository(
    appServerApi: api,
    callbackApi: CodexMcpCallbackApi(
      client:
          callbackClient ??
          MockClient((request) async {
            callbacks.add(request);
            return http.Response("fixture", 200);
          }),
      budget: const Duration(seconds: 1),
    ),
    timeoutSecs: 180,
  );
  late final service = CodexMcpAuthenticationService(repository: repository, inventory: inventory);
  Future<PluginMcpAuthenticationOperation> begin({PluginMcpServerTarget target = _target}) =>
      service.begin(target: target);
  Future<void> close() async {
    await service.dispose();
    await transport.notices.close();
  }
}

void main() {
  late _Harness harness;
  setUp(() {
    harness = _Harness(callbackClient: null, userAgent: "fixture/0.160.1 (fixture)");
  });
  tearDown(() => harness.close());

  for (final sendHeaders in [false, true]) {
    test("callback timeout aborts native HTTP work ${sendHeaders ? 'during body' : 'before headers'}", () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final peerClosed = Completer<void>();
      Socket? peer;
      final accepted = server.listen((socket) {
        peer = socket;
        socket.listen((_) {
          if (sendHeaders) {
            socket.write("HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nfixture");
          }
        }, onDone: peerClosed.complete);
      });
      final api = CodexMcpCallbackApi(client: http.Client(), budget: const Duration(milliseconds: 100));
      addTearDown(() async {
        api.close();
        peer?.destroy();
        await accepted.cancel();
        await server.close();
      });
      await expectLater(
        api.submit(callbackUri: Uri.parse("http://127.0.0.1:${server.port}/callback")),
        throwsA(isA<TimeoutException>()),
      );
      await peerClosed.future.timeout(const Duration(seconds: 2));
    });
  }

  test("preparation is read-only and discarded operations never start native authentication", () async {
    final operation = await harness.begin();
    expect(operation, isA<PluginMcpNativeSettlementAuthentication>());
    expect(operation.effectScope, PluginMcpActionEffectScope.harness);
    expect(harness.transport.calls.map((call) => call.method), ["mcpServerStatus/list"]);
  });

  test("unknown native authentication never enables a harness or session OAuth request", () async {
    harness.transport.authStatus = "future-auth";
    for (final target in [_target, const PluginMcpServerTarget(scope: PluginMcpHarnessScope(), serverKey: "fixture")]) {
      await expectLater(
        harness.begin(target: target),
        throwsA(
          isA<PluginMcpAuthenticationUnavailableException>().having(
            (error) => error.reason,
            "reason",
            PluginMcpAuthenticationUnavailableReason.notImplemented,
          ),
        ),
      );
    }
    expect(harness.transport.calls.map((call) => call.method), ["mcpServerStatus/list", "mcpServerStatus/list"]);
  });

  for (final threadId in [null, "thread"]) {
    test(
      "exact native request and callback forwarding with ${threadId == null ? 'harness' : 'session'} context",
      () async {
        final operation = await harness.begin(
          target: threadId == null
              ? const PluginMcpServerTarget(scope: PluginMcpHarnessScope(), serverKey: "fixture")
              : _target,
        );
        final iterator = StreamIterator(operation.events);
        addTearDown(iterator.cancel);
        expect(await iterator.moveNext(), isTrue);
        final challenge = iterator.current as PluginMcpAuthenticationChallenge;
        expect(challenge.expectedCallbackUri.toString(), _callback);
        expect(harness.transport.calls.last.params, {
          "name": "fixture",
          if (threadId != null) "threadId": "thread",
          "timeoutSecs": 180,
        });
        final callback = challenge.expectedCallbackUri.replace(
          queryParameters: {"state": "fixture-state", "code": "fixture-code"},
        );
        await operation.submitCallback(callbackUri: callback);
        expect(harness.callbacks.single.url, callback);
        expect(harness.callbacks.single.followRedirects, isFalse);
        harness.transport.complete(success: true, error: null, threadId: threadId);
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current, isA<PluginMcpAuthenticationCompleted>());
        expect(await iterator.moveNext(), isFalse);
        await expectLater(
          operation.submitCallback(callbackUri: callback),
          throwsA(isA<PluginMcpAuthenticationCallbackRejectedException>()),
        );
      },
    );
  }

  test("harness native request omits thread context", () async {
    final operation = await harness.begin(
      target: const PluginMcpServerTarget(scope: PluginMcpHarnessScope(), serverKey: "fixture"),
    );
    final iterator = StreamIterator(operation.events);
    addTearDown(iterator.cancel);
    await iterator.moveNext();
    expect(harness.transport.calls.last.params, {"name": "fixture", "timeoutSecs": 180});
    harness.transport.complete(success: true, error: null, threadId: null);
    await iterator.moveNext();
  });

  for (final userAgent in ["fixture/0.139.0 (fixture)", "unknown"]) {
    test("$userAgent refuses session login but retains harness authentication", () async {
      final legacy = _Harness(callbackClient: null, userAgent: userAgent);
      addTearDown(legacy.close);
      await expectLater(
        legacy.begin(),
        throwsA(
          isA<PluginMcpAuthenticationUnavailableException>().having(
            (value) => value.reason,
            "reason",
            PluginMcpAuthenticationUnavailableReason.nativeConfigurationRequired,
          ),
        ),
      );
      expect(legacy.transport.calls.map((call) => call.method), ["mcpServerStatus/list"]);
      final operation = await legacy.begin(
        target: const PluginMcpServerTarget(scope: PluginMcpHarnessScope(), serverKey: "fixture"),
      );
      final events = StreamIterator(operation.events);
      addTearDown(events.cancel);
      expect(await events.moveNext(), isTrue);
      expect(events.current, isA<PluginMcpAuthenticationChallenge>());
      expect(legacy.transport.calls.last.params, {"name": "fixture", "timeoutSecs": 180});
      legacy.transport.complete(success: true, error: null, threadId: null);
      expect(await events.moveNext(), isTrue);
      expect(events.current, isA<PluginMcpAuthenticationCompleted>());
    });
  }

  test("completion listener precedes login and suppresses a challenge after early settlement", () async {
    harness.transport.duringLogin = () => harness.transport.complete(success: true, error: null, threadId: "thread");
    final events = await (await harness.begin()).events.toList();
    expect(events, [isA<PluginMcpAuthenticationCompleted>()]);
  });

  test("foreign server/thread and unrelated notifications cannot settle this login", () async {
    final events = <PluginMcpAuthenticationEvent>[];
    final done = (await harness.begin()).events.toList().then((value) {
      events.addAll(value);
      return value;
    });
    await harness.transport.loginCalled.future;
    await pumpEventQueue();
    harness.transport.complete(success: true, error: null, name: "foreign");
    harness.transport.complete(success: true, error: null, threadId: "foreign");
    harness.transport.complete(success: true, error: null, threadId: null);
    harness.transport.notices.add(const CodexServerNotification(method: "unrelated", params: {}));
    await pumpEventQueue();
    expect(events, isEmpty);
    harness.transport.complete(success: true, error: null, threadId: "thread");
    expect((await done).last, isA<PluginMcpAuthenticationCompleted>());
  });

  for (final (error, reason) in [
    ("timed out waiting for OAuth callback", PluginMcpAuthenticationFailureReason.expired),
    ("OAuth provider returned `access_denied`", PluginMcpAuthenticationFailureReason.declined),
    ("unknown provider error", PluginMcpAuthenticationFailureReason.nativeFailure),
  ]) {
    test("native failure maps $reason without diagnostic URL disclosure", () async {
      final iterator = StreamIterator((await harness.begin()).events);
      addTearDown(iterator.cancel);
      await iterator.moveNext();
      harness.transport.complete(success: false, error: error);
      await iterator.moveNext();
      final failure = iterator.current as PluginMcpAuthenticationFailed;
      expect(failure.reason, reason);
      final cause = failure.cause as CodexMcpAuthenticationException;
      expect((cause.innerError as CodexMcpNativeOAuthException).message, error);
      expect(cause.toString(), isNot(contains(error)));
    });
  }

  test("known RPC rejection settles a typed failure retaining its cause", () async {
    final cause = CodexRpcException(method: "mcpServer/oauth/login", code: -32600, message: "fixture rejection");
    harness.transport.loginResponse = cause;
    final events = await (await harness.begin()).events.toList();
    final failure = events.single as PluginMcpAuthenticationFailed;
    expect(
      ((failure.cause as CodexMcpAuthenticationException).innerError as CodexMcpLoginRejectedException).innerError,
      same(cause),
    );
  });

  for (final response in [
    null,
    TimeoutException("fixture uncertainty"),
    {"authorizationUrl": "https://issuer.fixture/no-callback"},
  ]) {
    test("uncertain response ${response.runtimeType} retains ownership until native settlement", () async {
      harness.transport.loginResponse = response;
      final events = <PluginMcpAuthenticationEvent>[];
      final done = Completer<void>();
      (await harness.begin()).events.listen(events.add, onDone: done.complete);
      await harness.transport.loginCalled.future;
      await pumpEventQueue();
      expect(events, isEmpty);
      expect(done.isCompleted, isFalse);
      harness.transport.complete(success: false, error: "timed out waiting for OAuth callback");
      await done.future;
      expect(
        events.single,
        isA<PluginMcpAuthenticationFailed>().having(
          (event) => event.reason,
          "reason",
          PluginMcpAuthenticationFailureReason.expired,
        ),
      );
    });
  }

  test("malformed completion retains native ownership instead of freeing the lease", () async {
    final iterator = StreamIterator((await harness.begin()).events);
    addTearDown(iterator.cancel);
    await iterator.moveNext();
    harness.transport.notices.add(
      const CodexServerNotification(
        method: "mcpServer/oauthLogin/completed",
        params: {"name": "fixture", "success": "malformed"},
      ),
    );
    await pumpEventQueue();
    harness.transport.complete(success: true, error: null);
    await iterator.moveNext();
    expect(iterator.current, isA<PluginMcpAuthenticationCompleted>());
  });

  test("runtime teardown settles an active login and discarded preparation cannot restart it", () async {
    final prepared = await harness.begin();
    final iterator = StreamIterator((await harness.begin()).events);
    addTearDown(iterator.cancel);
    await iterator.moveNext();
    await harness.service.dispose();
    await iterator.moveNext();
    expect(iterator.current, isA<PluginMcpAuthenticationFailed>());
    final calls = harness.transport.calls.length;
    expect(await prepared.events.toList(), [isA<PluginMcpAuthenticationFailed>()]);
    expect(harness.transport.calls, hasLength(calls));
  });

  test("unsupported project, missing server and unsupported auth do no login RPC", () async {
    await expectLater(
      harness.begin(
        target: const PluginMcpServerTarget(
          scope: PluginMcpProjectScope(projectId: "project"),
          serverKey: "fixture",
        ),
      ),
      throwsA(isA<PluginMcpAuthenticationUnavailableException>()),
    );
    expect(harness.transport.calls, isEmpty);
    harness.transport.hasServer = false;
    await expectLater(
      harness.begin(),
      throwsA(
        isA<PluginMcpAuthenticationUnavailableException>().having(
          (error) => error.reason,
          "reason",
          PluginMcpAuthenticationUnavailableReason.targetNotFound,
        ),
      ),
    );
    harness.transport.hasServer = true;
    harness.transport.authStatus = "unsupported";
    await expectLater(
      harness.begin(),
      throwsA(
        isA<PluginMcpAuthenticationUnavailableException>().having(
          (error) => error.reason,
          "reason",
          PluginMcpAuthenticationUnavailableReason.notSupported,
        ),
      ),
    );
    expect(harness.transport.calls.every((call) => call.method == "mcpServerStatus/list"), isTrue);
  });

  test("callback mismatches are rejected before any HTTP delivery", () async {
    final operation = await harness.begin();
    final iterator = StreamIterator(operation.events);
    addTearDown(iterator.cancel);
    await iterator.moveNext();
    for (final callback in [
      "http://127.0.0.1:43123/callback?state=wrong&code=fixture",
      "http://127.0.0.1:43124/callback?state=fixture-state&code=fixture",
      "http://127.0.0.1:43123/another?state=fixture-state&code=fixture",
      "https://foreign.fixture/callback?state=fixture-state&code=fixture",
      "http://127.0.0.1:43123/callback?state=fixture-state&state=fixture-state&code=fixture",
      "http://127.0.0.1:43123/callback?state=fixture-state&code=one&code=two",
      "http://127.0.0.1:43123/callback?state=fixture-state&code=fixture&error=access_denied",
      "http://127.0.0.1:43123/callback?state=fixture-state",
      "http://user@127.0.0.1:43123/callback?state=fixture-state&code=fixture",
      "http://127.0.0.1:43123/callback?state=fixture-state&code=fixture#fragment",
    ]) {
      await expectLater(
        operation.submitCallback(callbackUri: Uri.parse(callback)),
        throwsA(isA<PluginMcpAuthenticationCallbackRejectedException>()),
      );
    }
    expect(harness.callbacks, isEmpty);
    harness.transport.complete(success: true, error: null);
    await iterator.moveNext();
  });

  test("native callback redirects are not followed and HTTP success is not auth success", () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    var redirected = false;
    server.listen((request) {
      if (request.uri.path == "/redirected") redirected = true;
      request.response.statusCode = 302;
      request.response.headers.set("location", "http://127.0.0.1:${server.port}/redirected");
      unawaited(request.response.close());
    });
    await harness.close();
    harness = _Harness(callbackClient: http.Client(), userAgent: "fixture/0.160.1 (fixture)");
    final callback = "http://127.0.0.1:${server.port}/callback";
    harness.transport.loginResponse = {"authorizationUrl": _authorization(callback: callback)};
    final operation = await harness.begin();
    final iterator = StreamIterator(operation.events);
    addTearDown(iterator.cancel);
    await iterator.moveNext();
    await expectLater(
      operation.submitCallback(
        callbackUri: Uri.parse(callback).replace(queryParameters: {"state": "fixture-state", "code": "fixture"}),
      ),
      throwsA(isA<CodexMcpAuthenticationException>()),
    );
    expect(redirected, isFalse);
    harness.transport.complete(success: false, error: "timed out waiting for OAuth callback");
    await iterator.moveNext();
    expect(iterator.current, isA<PluginMcpAuthenticationFailed>());
  });

  test("provider denial HTTP 400 is consumed while native notification owns outcome", () async {
    await harness.close();
    harness = _Harness(
      callbackClient: MockClient((_) async => http.Response("fixture denial", 400)),
      userAgent: "fixture/0.160.1 (fixture)",
    );
    final operation = await harness.begin();
    final iterator = StreamIterator(operation.events);
    addTearDown(iterator.cancel);
    await iterator.moveNext();
    await operation.submitCallback(
      callbackUri: Uri.parse(_callback).replace(queryParameters: {"state": "fixture-state", "error": "access_denied"}),
    );
    harness.transport.complete(success: false, error: "OAuth provider returned `access_denied`");
    await iterator.moveNext();
    expect((iterator.current as PluginMcpAuthenticationFailed).reason, PluginMcpAuthenticationFailureReason.declined);
  });

  test("challenge decoding rejects unsafe native callback origins and does not print URLs", () {
    for (final callback in [
      "https://127.0.0.1/callback",
      "http://foreign.fixture/callback",
      "http://user@localhost/callback",
      "http://localhost/callback#fragment",
    ]) {
      expect(() => CodexMcpLoginChallenge.parse(value: _authorization(callback: callback)), throwsFormatException);
    }
    final challenge = CodexMcpLoginChallenge.parse(value: _authorization(callback: _callback));
    expect(challenge.toString(), isNot(contains("fixture-state")));
    expect(CodexMcpOAuthLoginDto.fromJson({"authorizationUrl": "private"}).toString(), isNot(contains("private")));
  });
}
