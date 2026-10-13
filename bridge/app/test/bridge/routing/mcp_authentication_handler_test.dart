import "dart:async";
import "dart:convert";

import "package:drift/drift.dart" hide isNull;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/mcp_repository.dart";
import "package:sesori_bridge/src/repositories/models/mcp_authentication_update.dart";
import "package:sesori_bridge/src/routing/get_mcp_authentication_handler.dart";
import "package:sesori_bridge/src/routing/post_mcp_authentication_continue_handler.dart";
import "package:sesori_bridge/src/routing/post_mcp_authentication_handler.dart";
import "package:sesori_bridge/src/services/mcp_authentication_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fakes/fake_derived_bridge_plugin.dart";
import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

const _request = McpAuthenticationStartRequest(
  pluginId: "fixture",
  target: McpServerTarget(
    scope: McpSessionScope(sessionId: "bridge-session"),
    serverKey: "opaque-server",
  ),
);

void main() {
  late AppDatabase db;
  late _AuthenticationPlugin plugin;
  late TestPluginRuntime runtime;
  late McpAuthenticationService service;
  late PostMcpAuthenticationHandler startHandler;
  late PostMcpAuthenticationContinueHandler continueHandler;
  final changes = <Object?>[];
  final inventoryChanges = <McpInventoryRequest>[];

  setUp(() async {
    db = createTestDatabase();
    plugin = _AuthenticationPlugin();
    runtime = createTestPluginRuntime(plugins: [plugin]);
    service = McpAuthenticationService(
      repository: McpRepository(runtime: runtime, sessionDao: db.sessionDao, projectsDao: db.projectsDao),
    );
    startHandler = PostMcpAuthenticationHandler(service: service);
    continueHandler = PostMcpAuthenticationContinueHandler(service: service);
    changes.clear();
    inventoryChanges.clear();
    service.changes.listen(changes.add);
    service.inventoryChanges.listen(inventoryChanges.add);
    await recordSessionBinding(
      database: db,
      sessionId: "bridge-session",
      backendSessionId: "native-session",
      pluginId: "fixture",
      projectId: "opaque-project",
      parentSessionId: null,
    );
  });
  tearDown(() async {
    await service.dispose();
    if (!plugin.wasListened) unawaited(plugin.authEvents.stream.drain<void>());
    await plugin.authEvents.close();
    await runtime.dispose();
    await db.close();
  });

  McpAuthenticationState state() => (service.current as McpAuthenticationStateResult).state;
  Future<void> challenge({required String destination}) async {
    plugin.authEvents.add(
      PluginMcpAuthenticationChallenge(
        authorizationUri: Uri.parse(destination),
        expectedCallbackUri: Uri.parse("http://localhost:19000/oauth/callback?state=fixture-private"),
      ),
    );
    await _pump();
  }

  Future<void> complete() async {
    plugin.authEvents.add(const PluginMcpAuthenticationCompleted());
    await plugin.authEvents.close();
    await _pump();
  }

  Future<RelayResponse> start({required McpAuthenticationStartRequest request}) =>
      startHandler.routeForTest(makeRequest("POST", "/mcp/authentication", body: jsonEncode(request)));
  Future<RelayResponse> submit({required String attemptId, required String callbackUrl}) =>
      continueHandler.routeForTest(
        makeRequest(
          "POST",
          "/mcp/authentication/continue",
          body: jsonEncode(McpAuthenticationContinueRequest(attemptId: attemptId, callbackUrl: callbackUrl)),
        ),
      );

  test("exact target binding, request-only challenge recovery and authoritative completion", () async {
    expect((await start(request: _request)).status, 200);
    final starting = state() as McpAuthenticationStarting;
    expect(starting.attempt.cancellation, McpAuthenticationCancellation.cancelable);
    expect((plugin.targets.single.scope as PluginMcpSessionScope).sessionId, "native-session");
    expect(plugin.targets.single.serverKey, "opaque-server");
    await challenge(destination: "https://provider.test/auth?state=fixture-private");
    final response = await GetMcpAuthenticationHandler(service: service)
        .routeForTest(makeRequest("GET", "/mcp/authentication"));
    expect(response.body, contains("fixture-private"));
    expect(changes, everyElement(isNull));
    plugin.authEvents.add(const PluginMcpAuthenticationCompleted());
    await _pump();
    expect(state(), isA<McpAuthenticationCallbackChallenge>());
    expect(inventoryChanges, isEmpty);
    await plugin.authEvents.close();
    await _pump();
    expect(state(), isA<McpAuthenticationCompleted>());
    expect(jsonEncode(service.current), isNot(contains("fixture-private")));
    expect(inventoryChanges.single.scope, const McpHarnessScope());
  });

  test("competing starts are busy during native preparation without replacing the target", () async {
    plugin.beginGate = Completer<void>();
    final first = service.start(request: _request);
    await _pump();
    expect(await service.start(request: _request), isA<McpAuthenticationBusy>());
    expect(plugin.targets, hasLength(1));
    plugin.beginGate!.complete();
    expect(await first, isA<McpAuthenticationStateResult>());
  });

  test("callback is bound to the active attempt and rejected callbacks retain the challenge", () async {
    await service.start(request: _request);
    await challenge(destination: "https://provider.test/auth");
    final attempt = (state() as McpAuthenticationCallbackChallenge).attempt;
    expect(
      (await submit(attemptId: "stale", callbackUrl: "http://localhost/?code=private")).body,
      contains("attemptNotFound"),
    );
    expect(plugin.callbacks, isEmpty);
    plugin.rejectCallback = true;
    final rejected = await submit(attemptId: attempt.attemptId, callbackUrl: "http://localhost/?code=private");
    expect(rejected.body, contains("callbackRejected"));
    expect(rejected.body, isNot(contains("private")));
    expect(state(), isA<McpAuthenticationCallbackChallenge>());
    plugin.rejectCallback = false;
    await submit(attemptId: attempt.attemptId, callbackUrl: "http://localhost/?code=private");
    expect(state(), isA<McpAuthenticationSettling>());
    await complete();
    expect(state(), isA<McpAuthenticationCompleted>());
  });

  test("cancel waits for native resources and settlement", () async {
    await service.start(request: _request);
    final attempt = (state() as McpAuthenticationStarting).attempt;
    plugin.cancelGate = Completer<void>();
    final result = service.cancel(request: McpAuthenticationCancelRequest(attemptId: attempt.attemptId));
    await _pump();
    expect(state(), isA<McpAuthenticationSettling>());
    expect(await service.start(request: _request), isA<McpAuthenticationBusy>());
    plugin.cancelGate!.complete();
    expect((await result as McpAuthenticationStateResult).state, isA<McpAuthenticationCancelled>());
    expect(plugin.cancelCount, 1);
  });

  test("cancellation failure does not report a successful cancellation", () async {
    await service.start(request: _request);
    final attempt = (state() as McpAuthenticationStarting).attempt;
    plugin.cancelError = StateError("fixture-private");
    await expectLater(
      service.cancel(request: McpAuthenticationCancelRequest(attemptId: attempt.attemptId)),
      throwsA(
        isA<McpAuthenticationCancellationException>().having(
          (error) => error.innerError,
          "retained cause",
          same(plugin.cancelError),
        ),
      ),
    );
    await _pump();
    expect((state() as McpAuthenticationFailed).reason, McpAuthenticationFailureReason.nativeFailure);
    expect(jsonEncode(service.current), isNot(contains("fixture-private")));
  });

  test("invalid callback body returns a private decoding error", () async {
    final response = await continueHandler.routeForTest(
      makeRequest(
        "POST",
        "/mcp/authentication/continue",
        body: jsonEncode({
          'attemptId': 'fixture',
          'callbackUrl': {'code': 'fixture-private'},
        }),
      ),
    );
    expect(response.status, 400);
    expect(response.body, isNot(contains("fixture-private")));
    expect(plugin.targets, isEmpty);
  });

  test("native settlement without cancellation remains owned until completion", () async {
    plugin.cancelable = false;
    await service.start(request: _request);
    final attempt = (state() as McpAuthenticationStarting).attempt;
    expect(attempt.cancellation, McpAuthenticationCancellation.nativeSettlement);
    final result = await service.cancel(request: McpAuthenticationCancelRequest(attemptId: attempt.attemptId));
    expect(
      (result as McpAuthenticationUnavailable).reason,
      McpAuthenticationUnavailableReason.nativeCancellationUnavailable,
    );
    expect(await service.start(request: _request), isA<McpAuthenticationBusy>());
    expect(plugin.cancelCount, 0);
    await complete();
    expect(state(), isA<McpAuthenticationCompleted>());
  });

  test("missing, mismatched and archived targets reject before native mutation", () async {
    for (final request in [
      McpAuthenticationStartRequest(pluginId: "other", target: _request.target),
      const McpAuthenticationStartRequest(
        pluginId: "fixture",
        target: McpServerTarget(
          scope: McpSessionScope(sessionId: "missing"),
          serverKey: "opaque-server",
        ),
      ),
    ]) {
      final response = await start(request: request);
      expect(response.status, anyOf(400, 404));
      await _pump();
    }
    await (db.update(
      db.sessionTable,
    )..where((row) => row.sessionId.equals("bridge-session"))).write(const SessionTableCompanion(archivedAt: Value(1)));
    final response = await start(request: _request);
    expect(response.status, 409);
    expect(
      SessionArchivedRejection.fromJson(jsonDecode(response.body!) as Map<String, dynamic>).reason,
      SessionArchivedReason.archivedReadOnly,
    );
    expect(plugin.targets, isEmpty);
  });

  test("archiving an active target rejects callback forwarding while cancellation remains available", () async {
    await service.start(request: _request);
    await challenge(destination: "https://provider.test/auth");
    final attempt = (state() as McpAuthenticationCallbackChallenge).attempt;
    await (db.update(
      db.sessionTable,
    )..where((row) => row.sessionId.equals("bridge-session"))).write(const SessionTableCompanion(archivedAt: Value(1)));
    expect((await submit(attemptId: attempt.attemptId, callbackUrl: "http://localhost/?code=private")).status, 409);
    expect(plugin.callbacks, isEmpty);
    expect(
      (await service.cancel(
        request: McpAuthenticationCancelRequest(attemptId: attempt.attemptId),
      ) as McpAuthenticationStateResult).state,
      isA<McpAuthenticationCancelled>(),
    );
  });

  test("inactive plugin does not start authentication", () async {
    runtime.stoppedPluginIds.add("fixture");
    final result = await service.start(request: _request);
    expect((result as McpAuthenticationUnavailable).reason, McpAuthenticationUnavailableReason.pluginInactive);
    expect(plugin.targets, isEmpty);
  });

  for (final destination in [
    "http://provider.test/auth",
    "file:///private/auth",
    "data:text/plain,private",
    "javascript:private()",
    "custom://provider.test/auth",
    "/relative/private",
    "https://user:private@provider.test/auth",
  ]) {
    test("rejects authorization destination $destination before exposing it", () async {
      await service.start(request: _request);
      await challenge(destination: destination);
      await _pump();
      expect(state(), isA<McpAuthenticationFailed>());
      expect(jsonEncode(service.current), isNot(contains(destination)));
      expect(plugin.cancelCount, 1);
      expect(inventoryChanges, isEmpty);
    });
  }

  test("native failure preserves its bounded reason without exporting diagnostic text", () async {
    await service.start(request: _request);
    plugin.authEvents.add(
      PluginMcpAuthenticationFailed(
        reason: PluginMcpAuthenticationFailureReason.declined,
        cause: Exception("fixture-private"),
        causeStackTrace: StackTrace.current,
      ),
    );
    await plugin.authEvents.close();
    await _pump();
    expect((state() as McpAuthenticationFailed).reason, McpAuthenticationFailureReason.declined);
    expect(jsonEncode(service.current), isNot(contains("fixture-private")));
  });

  test("shutdown cancels owned native resources and blocks a new start", () async {
    await service.start(request: _request);
    await service.dispose();
    expect(plugin.cancelCount, 1);
    expect(
      (await service.start(request: _request) as McpAuthenticationUnavailable).reason,
      McpAuthenticationUnavailableReason.pluginInactive,
    );
  });
}

Future<void> _pump() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _AuthenticationPlugin() extends FakeDerivedBridgePlugin implements McpAuthenticationPluginApi {
  this : super(id: "fixture", launchDirectory: "/fixture", allSessions: const []);
  late final StreamController<PluginMcpAuthenticationEvent> authEvents = StreamController(
    onListen: () {
      wasListened = true;
    },
  );
  bool wasListened = false;
  final List<PluginMcpServerTarget> targets = [];
  final List<Uri> callbacks = [];
  Object? cancelError;
  bool cancelable = true;
  bool rejectCallback = false;
  int cancelCount = 0;
  Completer<void>? beginGate;
  Completer<void>? cancelGate;
  @override
  Future<PluginMcpAuthenticationOperation> beginMcpAuthentication({required PluginMcpServerTarget target}) async {
    targets.add(target);
    await beginGate?.future;
    Future<void> submit({required Uri callbackUri}) async {
      if (rejectCallback) {
        throw const PluginMcpAuthenticationCallbackRejectedException(innerError: FormatException("fixture-private"));
      }
      callbacks.add(callbackUri);
    }

    return cancelable
        ? PluginMcpCancelableAuthentication(
            effectScope: PluginMcpActionEffectScope.harness,
            events: authEvents.stream,
            submitCallback: submit,
            cancel: () async {
              cancelCount++;
              await cancelGate?.future;
              unawaited(authEvents.close());
              if (cancelError case final error?) throw error;
            },
          )
        : PluginMcpNativeSettlementAuthentication(
            effectScope: PluginMcpActionEffectScope.harness,
            events: authEvents.stream,
            submitCallback: submit,
          );
  }

  @override
  Future<void> forgetMcpAuthentication({required PluginMcpServerTarget target}) => throw UnimplementedError();
}
