import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/mcp/mcp_authentication_cubit.dart";
import "package:sesori_dart_core/src/foundation/platform/active_bridge_locality.dart";
import "package:sesori_dart_core/src/repositories/mcp_repository.dart";
import "package:sesori_dart_core/src/repositories/models/mcp_authentication_response.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_management_result.dart";
import "package:sesori_dart_core/src/services/mcp_authentication_service.dart";
import "package:sesori_dart_core/src/services/models/mcp_authentication_client_state.dart";
import "package:sesori_dart_core/src/services/plugin_authentication_browser_service.dart";
import "package:sesori_dart_core/src/services/plugin_management_service.dart" show PluginManagementService;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _Repository() extends Mock implements McpRepository;
class _Management() extends Mock implements PluginManagementService;
class _Browser() extends Mock implements PluginAuthenticationBrowserService;
class _Connection() extends Mock implements ConnectionService;

class _Locality({required bool local}) implements ActiveBridgeLocality {
  bool local = local;
  @override
  bool isLocalBridge({required String bridgeId}) => local;
}

const _config = ServerConnectionConfig(relayHost: "wss://fixture.test", authToken: "fixture");
const _connected = ConnectionConnected(
  config: _config,
  health: HealthResponse(healthy: true, version: "1.9.1", filesystemAccessDegraded: false),
);
const _target = McpServerTarget(
  scope: McpSessionScope(sessionId: "session"),
  serverKey: "server",
);
const _attempt = McpAuthenticationAttempt(
  attemptId: "attempt",
  pluginId: "fixture",
  target: _target,
  cancellation: McpAuthenticationCancellation.cancelable,
);
const _challenge = McpAuthenticationCallbackChallenge(
  attempt: _attempt,
  authorizationUrl: "https://fixture.example/authorize",
  expectedCallbackUrl: "http://127.0.0.1:43120/callback",
);
const _start = McpAuthenticationStartRequest(pluginId: "fixture", target: _target);

PluginManagementLoadResult _management({required String bridgeId}) => PluginManagementLoadResult.supported(
  response: PluginManagementResponse(
    snapshotToken: "snapshot",
    bridgeId: bridgeId,
    defaultPluginId: "fixture",
    defaultIdleTimeoutMins: 10,
    plugins: const [],
  ),
  refreshError: null,
);
McpAuthenticationReceived _native({required McpAuthenticationState state}) =>
    McpAuthenticationReceived(result: McpAuthenticationStateResult(state: state));
Future<void> _pump() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Repository repository;
  late _Browser browser;
  late _Locality locality;
  late _Management manager;
  late McpAuthenticationService service;
  late BehaviorSubject<ConnectionStatus> statuses;
  late BehaviorSubject<PluginManagementLoadResult> management;
  late StreamController<SseEvent> events;
  late StreamController<void> stale;
  late List<Completer<McpAuthenticationResponse>> reads;
  late Completer<McpAuthenticationResponse> start;
  late Completer<McpAuthenticationResponse> cancellation;
  late Completer<McpAuthenticationResponse> continuation;
  late List<PluginAuthenticationBrowserOwner> owners;
  late List<PluginAuthenticationBrowserChallenge> challenges;
  late List<bool> reuse;
  late PluginAuthenticationBrowserFlowResult browserResult;
  late Future<PluginAuthenticationBrowserFlowResult>? browserPending;

  setUpAll(() {
    registerFallbackValue(_start);
    registerFallbackValue(_challenge);
    registerFallbackValue(const McpAuthenticationCancelRequest(attemptId: "attempt"));
    registerFallbackValue(const McpAuthenticationContinueRequest(attemptId: "attempt", callbackUrl: "fixture"));
    registerFallbackValue(
      PluginAuthenticationBrowserOwner(
        bridgeId: "fixture",
        connectionEpoch: 0,
        purpose: PluginAuthenticationBrowserPurpose.mcp,
      ),
    );
    registerFallbackValue(
      PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse(_challenge.authorizationUrl),
        expectedCallbackUri: Uri.parse(_challenge.expectedCallbackUrl),
      ),
    );
  });
  setUp(() async {
    locality = _Locality(local: true);
    repository = _Repository();
    browser = _Browser();
    final connection = _Connection();
    manager = _Management();
    statuses = BehaviorSubject.seeded(_connected);
    management = BehaviorSubject.seeded(_management(bridgeId: "bridge-a"));
    events = StreamController.broadcast();
    stale = StreamController.broadcast();
    reads = [];
    start = Completer();
    cancellation = Completer();
    continuation = Completer();
    owners = [];
    challenges = [];
    reuse = [];
    browserResult = const PluginAuthenticationBrowserDirect();
    browserPending = null;
    when(() => connection.currentStatus).thenAnswer((_) => statuses.value);
    when(() => connection.status).thenAnswer((_) => statuses.stream);
    when(() => connection.events).thenAnswer((_) => events.stream);
    when(() => connection.dataMayBeStale).thenAnswer((_) => stale.stream);
    when(() => manager.snapshots).thenAnswer((_) => management.stream);
    when(manager.refresh).thenAnswer((_) async {});
    when(repository.getAuthentication).thenAnswer((_) {
      final read = Completer<McpAuthenticationResponse>();
      reads.add(read);
      return read.future;
    });
    when(() => repository.startAuthentication(request: any(named: "request"))).thenAnswer((_) => start.future);
    when(() => repository.cancelAuthentication(request: any(named: "request"))).thenAnswer((_) => cancellation.future);
    when(() => repository.continueAuthentication(request: any(named: "request")))
        .thenAnswer((_) => continuation.future);
    when(() => repository.browserChallenge(state: any(named: "state"))).thenAnswer((invocation) {
      final state = invocation.namedArguments[#state]! as McpAuthenticationCallbackChallenge;
      return PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse(state.authorizationUrl),
        expectedCallbackUri: Uri.parse(state.expectedCallbackUrl),
      );
    });
    when(() => browser.cancel(owner: any(named: "owner"))).thenAnswer((_) async => null);
    when(
      () => browser.authenticate(
        owner: any(named: "owner"),
        challenge: any(named: "challenge"),
        isLocalBridge: any(named: "isLocalBridge"),
        reuseActiveListener: any(named: "reuseActiveListener"),
        onPhase: any(named: "onPhase"),
        onDetachedFailure: any(named: "onDetachedFailure"),
      ),
    ).thenAnswer((invocation) {
      owners.add(invocation.namedArguments[#owner]! as PluginAuthenticationBrowserOwner);
      challenges.add(invocation.namedArguments[#challenge]! as PluginAuthenticationBrowserChallenge);
      reuse.add(invocation.namedArguments[#reuseActiveListener]! as bool);
      if (browserResult is! PluginAuthenticationBrowserBusy) {
        (invocation.namedArguments[#onPhase]! as void Function(PluginAuthenticationBrowserPhase))(
          PluginAuthenticationBrowserPhase.opening,
        );
      }
      return browserPending ?? Future.value(browserResult);
    });
    service = McpAuthenticationService(
      repository: repository,
      connectionService: connection,
      managementService: manager,
      browserService: browser,
      locality: locality,
    );
    await _pump();
    reads.single.complete(_native(state: const McpAuthenticationIdle()));
    await _pump();
  });
  tearDown(() async {
    await service.onDispose();
    await statuses.close();
    await management.close();
    await events.close();
    await stale.close();
  });
  Future<void> observe({required McpAuthenticationState state}) async {
    final refreshing = service.refresh();
    reads.last.complete(_native(state: state));
    await refreshing;
    await _pump();
  }

  test("GET recovery and cancellation work while the original start POST waits", () async {
    const preparing = McpAuthenticationAttempt(
      attemptId: "attempt",
      pluginId: "fixture",
      target: _target,
      cancellation: McpAuthenticationCancellation.unknown,
    );
    final starting = service.start(request: _start);
    events.add(SseEvent(data: const SesoriMcpAuthenticationChanged()));
    await _pump();
    reads.last.complete(_native(state: const McpAuthenticationStarting(attempt: preparing)));
    await _pump();
    final cancelling = service.cancel();
    await _pump();
    verify(() => repository.cancelAuthentication(request: any(named: "request"))).called(1);
    cancellation.complete(_native(state: const McpAuthenticationCancelled(attempt: _attempt)));
    await cancelling;
    start.complete(_native(state: const McpAuthenticationStarting(attempt: preparing)));
    await starting;
    expect((service.currentState.observation as McpAuthenticationObserved).state, isA<McpAuthenticationCancelled>());
  });
  test("overlapping starts share identity refresh but issue only one native start", () async {
    statuses.add(const ConnectionLost(config: _config));
    await _pump();
    statuses.add(_connected);
    await _pump();
    final identity = Completer<void>();
    when(manager.refresh).thenAnswer((_) => identity.future);
    final first = service.start(request: _start);
    final second = service.start(request: _start);
    management.add(_management(bridgeId: "bridge-a"));
    await _pump();
    identity.complete();
    await _pump();
    try {
      verify(() => repository.startAuthentication(request: any(named: "request"))).called(1);
    } finally {
      start.complete(_native(state: _challenge));
      await Future.wait([first, second]);
    }
  });
  test("native-settlement-only mode does not post a cancellation or release its browser", () async {
    const attempt = McpAuthenticationAttempt(
      attemptId: "native-only",
      pluginId: "fixture",
      target: _target,
      cancellation: McpAuthenticationCancellation.nativeSettlement,
    );
    await observe(
      state: const McpAuthenticationCallbackChallenge(
        attempt: attempt,
        authorizationUrl: "https://fixture.example/authorize",
        expectedCallbackUrl: "http://127.0.0.1:43120/callback",
      ),
    );
    await service.openBrowser();
    final cancelling = service.cancel();
    await _pump();
    try {
      verifyNever(() => repository.cancelAuthentication(request: any(named: "request")));
      verifyNever(() => browser.cancel(owner: any(named: "owner")));
    } finally {
      cancellation.complete(_native(state: const McpAuthenticationSettling(attempt: attempt)));
      await cancelling;
    }
  });
  test("a GET begun before a mutation cannot overwrite the mutation response", () async {
    final reading = service.refresh();
    final oldRead = reads.last;
    final starting = service.start(request: _start);
    start.complete(_native(state: _challenge));
    await starting;
    oldRead.complete(_native(state: const McpAuthenticationIdle()));
    await reading;
    expect((service.currentState.observation as McpAuthenticationObserved).state, same(_challenge));
    reads.last.complete(_native(state: _challenge));
    await _pump();
  });
  test("a late start response cannot overwrite newer terminal GET truth", () async {
    final starting = service.start(request: _start);
    await observe(state: const McpAuthenticationCompleted(attempt: _attempt));
    start.complete(_native(state: _challenge));
    await starting;
    expect((service.currentState.observation as McpAuthenticationObserved).state, isA<McpAuthenticationCompleted>());
  });
  test("uncertain mutation retains its typed cause and triggers recovery", () async {
    final cause = ApiError.generic();
    final starting = service.start(request: _start);
    start.complete(McpAuthenticationRequestFailed(cause: cause));
    await starting;
    expect((service.currentState.request as McpAuthenticationRequestUncertain).cause, same(cause));
    reads.last.complete(_native(state: _challenge));
    await _pump();
    expect((service.currentState.observation as McpAuthenticationObserved).state, same(_challenge));
    expect(owners, isEmpty);
  });
  test("browser busy retains the challenge and cleanup never cancels a foreign owner", () async {
    await observe(state: _challenge);
    browserResult = const PluginAuthenticationBrowserBusy();
    await service.openBrowser();
    expect(service.currentState.browser, isA<McpAuthenticationBrowserBlocked>());
    expect((service.currentState.observation as McpAuthenticationObserved).state, same(_challenge));
    verifyNever(() => browser.cancel(owner: any(named: "owner")));
    browserResult = const PluginAuthenticationBrowserDirect();
    await service.openBrowser();
    expect(reuse, [false, false]);
    expect(owners.last.bridgeId, "bridge-a");
    expect(owners.last.purpose, PluginAuthenticationBrowserPurpose.mcp);
    await observe(state: const McpAuthenticationCompleted(attempt: _attempt));
    verify(() => browser.cancel(owner: owners.last)).called(1);
    expect(service.currentState.browser, isA<McpAuthenticationBrowserIdle>());
  });
  test("listener retry reuses the exact accepted handle and challenge", () async {
    locality.local = false;
    await observe(state: _challenge);
    browserResult = PluginAuthenticationBrowserFlowFailed(
      innerError: StateError("fixture"),
      stackTrace: StackTrace.current,
      retryableWithActiveListener: true,
    );
    await service.openBrowser();
    await service.openBrowser();
    expect(reuse, [false, true]);
    expect(owners.last, same(owners.first));
    expect(challenges.last, same(challenges.first));
  });
  test("captured callback is sent only to its native attempt", () async {
    locality.local = false;
    await observe(state: _challenge);
    browserResult = PluginAuthenticationBrowserCaptured(
      callbackUri: Uri.parse("http://127.0.0.1:43120/callback?code=fixture"),
    );
    final opening = service.openBrowser();
    await _pump();
    final Object? request = verify(() => repository.continueAuthentication(request: captureAny(named: "request")))
        .captured
        .single;
    expect(request, isA<McpAuthenticationContinueRequest>());
    if (request case McpAuthenticationContinueRequest(:final attemptId, :final callbackUrl)) {
      expect(attemptId, "attempt");
      expect(callbackUrl, contains("code=fixture"));
    }
    continuation.complete(_native(state: const McpAuthenticationSettling(attempt: _attempt)));
    await opening;
    expect((service.currentState.observation as McpAuthenticationObserved).state, isA<McpAuthenticationSettling>());
  });
  test("disconnect fences a pending callback; reconnect recovery launches nothing", () async {
    locality.local = false;
    await observe(state: _challenge);
    final returned = Completer<PluginAuthenticationBrowserFlowResult>();
    browserPending = returned.future;
    final opening = service.openBrowser();
    await _pump();
    statuses.add(const ConnectionLost(config: _config));
    await _pump();
    statuses.add(_connected);
    await _pump();
    management.add(_management(bridgeId: "bridge-b"));
    await _pump();
    reads.last.complete(_native(state: _challenge));
    await _pump();
    returned.complete(
      PluginAuthenticationBrowserCaptured(callbackUri: Uri.parse("http://127.0.0.1:43120/callback?code=old")),
    );
    await opening;
    verifyNever(() => repository.continueAuthentication(request: any(named: "request")));
    expect(owners, hasLength(1));
    verify(() => browser.cancel(owner: owners.single)).called(1);
  });
  test("read failure retains the challenge and its original transport cause", () async {
    await observe(state: _challenge);
    final cause = ApiError.generic();
    final reading = service.refresh();
    reads.last.complete(McpAuthenticationRequestFailed(cause: cause));
    await reading;
    final observed = service.currentState.observation as McpAuthenticationObserved;
    expect(observed.state, same(_challenge));
    expect(observed.refreshFailure, isA<McpAuthenticationRequestFailed>());
    if (observed.refreshFailure case McpAuthenticationRequestFailed(cause: final error)) {
      expect(error, same(cause));
    }
  });
  test("closing one of two Cubits does not cancel the shared native or browser owner", () async {
    await observe(state: _challenge);
    final first = McpAuthenticationCubit(service: service);
    final second = McpAuthenticationCubit(service: service);
    await first.openBrowser();
    await first.close();
    verifyNever(() => browser.cancel(owner: any(named: "owner")));
    verifyNever(() => repository.cancelAuthentication(request: any(named: "request")));
    expect(second.state.browser, isA<McpAuthenticationBrowserWaiting>());
    await second.close();
  });
  test("connection replacement during browser cleanup cannot cancel on the new bridge", () async {
    await observe(state: _challenge);
    await service.openBrowser();
    final cleanup = Completer<PluginAuthenticationBrowserFlowFailed?>();
    when(() => browser.cancel(owner: any(named: "owner"))).thenAnswer((_) => cleanup.future);
    final cancelling = service.cancel();
    await _pump();
    statuses.add(const ConnectionLost(config: _config));
    await _pump();
    statuses.add(_connected);
    await _pump();
    management.add(_management(bridgeId: "bridge-b"));
    await _pump();
    cleanup.complete(null);
    await cancelling;
    verifyNever(() => repository.cancelAuthentication(request: any(named: "request")));
  });
  test("missing bridge identity is an explicit limitation while the relay is connected", () async {
    statuses.add(const ConnectionLost(config: _config));
    await _pump();
    statuses.add(_connected);
    await _pump();
    management.add(const PluginManagementLoadResult.unsupported());
    await _pump();
    expect(service.currentState.observation, isA<McpAuthenticationIdentityUnavailable>());
    await service.start(request: _start);
    verifyNever(() => repository.startAuthentication(request: any(named: "request")));
    expect(reads, hasLength(1));
  });
  test("service disposal waits for owned cleanup already started by disconnect", () async {
    await observe(state: _challenge);
    await service.openBrowser();
    final cleanup = Completer<PluginAuthenticationBrowserFlowFailed?>();
    when(() => browser.cancel(owner: any(named: "owner"))).thenAnswer((_) => cleanup.future);
    statuses.add(const ConnectionLost(config: _config));
    await _pump();
    var disposed = false;
    final disposal = service.onDispose().then((_) => disposed = true);
    await _pump();
    try {
      expect(disposed, isFalse);
    } finally {
      cleanup.complete(null);
      await disposal;
    }
    verifyNever(() => repository.cancelAuthentication(request: any(named: "request")));
  });
}
