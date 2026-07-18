import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/auth/bridge_registration_api.dart";
import "package:sesori_bridge/src/auth/bridge_registration_service.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/orchestrator.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/restart_test_support.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/routing_test_helpers.dart";

void main() {
  group("OrchestratorSession bridge registration", () {
    test("startup registration failure fails the run without connecting to the relay", () async {
      final repository = FakeBridgeRegistrationRepository()
        ..registerError = BridgeRegistrationException(statusCode: 500, body: "boom");
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      await expectLater(harness.runFuture, throwsA(isA<BridgeRegistrationException>()));

      expect(repository.registeredBridgeIds, equals([null]));
      expect(harness.relayServer.connectedClientCount, equals(0));
    });

    test("registers before the initial connect and sends the bridge id in the auth message", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final bridgeSocket = await harness.relayServer.nextClient();
      final authMessage = await _firstTextMessage(bridgeSocket);

      expect(repository.registeredBridgeIds, equals([null]));
      expect(harness.bridgeIdStorage.bridgeId, equals("br_first001"));
      expect(authMessage["type"], equals("auth"));
      expect(authMessage["role"], equals("bridge"));
      expect(authMessage["bridgeId"], equals("br_first001"));
    });

    test("normal disconnect reconnects without re-registering", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);
      await firstSocket.close();

      final secondSocket = await harness.relayServer.nextClient();
      final authMessage = await _firstTextMessage(secondSocket);

      expect(repository.registeredBridgeIds, equals([null]), reason: "registration is memoized per process");
      expect(authMessage["bridgeId"], equals("br_first001"));
    });

    test("close code 4006 clears the bridge id and re-registers fresh", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      repository.nextBridgeId = "br_second002";
      await firstSocket.close(RelayCloseCodes.bridgeRevoked);

      final secondSocket = await harness.relayServer.nextClient();
      final authMessage = await _firstTextMessage(secondSocket);

      expect(
        repository.registeredBridgeIds,
        equals([null, null]),
        reason: "the revoked bridge id must not be re-posted",
      );
      expect(harness.bridgeIdStorage.bridgeId, equals("br_second002"));
      expect(authMessage["bridgeId"], equals("br_second002"));
    });

    test("registration failure after 4006 retries the connect attempt on the existing backoff", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      repository
        ..nextBridgeId = "br_second002"
        ..registerError = BridgeRegistrationException(statusCode: 500, body: "boom");
      await firstSocket.close(RelayCloseCodes.bridgeRevoked);

      // First reconnect attempt fails on registration without touching the relay.
      await _waitFor(
        () => repository.registeredBridgeIds.length >= 2,
        reason: "first re-registration attempt",
      );
      expect(harness.relayServer.connectedClientCount, equals(1));

      // Once registration succeeds the next backoff attempt reconnects.
      repository.registerError = null;
      final secondSocket = await harness.relayServer.nextClient(timeout: const Duration(seconds: 10));
      final authMessage = await _firstTextMessage(secondSocket);

      expect(repository.registeredBridgeIds.length, greaterThanOrEqualTo(3));
      expect(authMessage["bridgeId"], equals("br_second002"));
    });
  });

  group("OrchestratorSession relay takeover (ADR A22)", () {
    test("a 4007 replaced-close does not reconnect within the war window", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // The relay displaces this bridge: another bridge for the account took
      // the slot. The displaced bridge must NOT tight-loop back — it uses a
      // long backoff, so no reconnect happens within the war window.
      await firstSocket.close(RelayCloseCodes.bridgeReplaced, "replaced");

      await expectLater(
        harness.relayServer.nextClient(timeout: const Duration(seconds: 3)),
        throwsA(isA<TimeoutException>()),
        reason: "displaced bridge must not reconnect on a tight loop",
      );
      expect(harness.relayServer.connectedClientCount, equals(1));
    });

    test("the 1000/replaced rollout fallback also holds off reconnect", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      await firstSocket.close(1000, "replaced");

      await expectLater(
        harness.relayServer.nextClient(timeout: const Duration(seconds: 3)),
        throwsA(isA<TimeoutException>()),
        reason: "the rollout fallback (1000/replaced) must be treated as a takeover",
      );
      expect(harness.relayServer.connectedClientCount, equals(1));
    });

    test("cancel wakes a long takeover backoff promptly (no shutdown stall)", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // Displace the bridge: it enters the minutes-order takeover backoff.
      await firstSocket.close(RelayCloseCodes.bridgeReplaced, "replaced");
      // Give the loop a moment to settle into the long Future.delayed wait.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // A SIGTERM-style cancel must wake the loop immediately, not wait out the
      // 2+ minute backoff. run() should return well within a few seconds.
      final sw = Stopwatch()..start();
      await harness.session.cancel();
      await harness.runFuture.timeout(const Duration(seconds: 10));
      sw.stop();

      expect(
        sw.elapsed,
        lessThan(const Duration(seconds: 10)),
        reason: "cancel must not block on the long takeover backoff",
      );
    });

    test("a plain normal drop (1000, no replaced reason) reconnects promptly", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // A vanilla close (network blip / relay restart) is not a takeover and
      // must reconnect on the ordinary 1s-reset backoff, unchanged by this PR.
      await firstSocket.close();

      final secondSocket = await harness.relayServer.nextClient(timeout: const Duration(seconds: 5));
      final authMessage = await _firstTextMessage(secondSocket);
      expect(authMessage["bridgeId"], equals("br_first001"));
    });
  });
}

Future<Map<String, dynamic>> _firstTextMessage(WebSocket socket) async {
  final message = await socket.firstWhere((dynamic data) => data is String).timeout(const Duration(seconds: 5));
  return jsonDecodeMap(message as String);
}

Future<void> _waitFor(bool Function() condition, {required String reason}) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(timeoutAt)) {
      fail("Timed out waiting for: $reason");
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class _RegistrationHarness {
  final FakeBridgePlugin plugin;
  final FakeBridgeIdStorage bridgeIdStorage;
  final OrchestratorSession session;
  final Future<void> runFuture;
  final _CountingRelayServer relayServer;
  final AppDatabase database;
  final PluginLifecycleService lifecycleService;
  final http.Client httpClient;

  _RegistrationHarness._({
    required this.plugin,
    required this.bridgeIdStorage,
    required this.session,
    required this.runFuture,
    required this.relayServer,
    required this.database,
    required this.lifecycleService,
    required this.httpClient,
  });

  static Future<_RegistrationHarness> start({
    required FakeBridgeRegistrationRepository repository,
  }) async {
    final relayServer = await _CountingRelayServer.start();
    final database = createTestDatabase();
    final plugin = FakeBridgePlugin();
    final bridgeIdStorage = FakeBridgeIdStorage();
    final registrationService = BridgeRegistrationService(
      repository: repository,
      tokenRefresher: FakeTokenRefresher(),
      bridgeIdStorage: bridgeIdStorage,
      hostName: "test-host",
      platform: "macos",
    );
    final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
    final httpClient = http.Client();

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: RelayClient(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        accessTokenProvider: FakeAccessTokenProvider(),
        bridgeIdProvider: registrationService,
      ),
      legacyMissingPluginId: plugin.id,
      pluginLifecycleService: lifecycleService,
      database: database,
      httpClient: httpClient,
      processRunner: ProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: FakeTokenRefresher(),
      bridgeRegistrationService: registrationService,
      failureReporter: FakeFailureReporter(),
      restartService: buildTestRestartService(),
      filesystemAccessOk: true,
      statusNotifier: null,
    );

    final session = orchestrator.create().session;
    // Surface run() failures through [runFuture] without triggering an
    // unhandled async error when a test only awaits it via expectLater later.
    final runFuture = session.run();
    unawaited(runFuture.catchError((_) {}));

    return _RegistrationHarness._(
      plugin: plugin,
      bridgeIdStorage: bridgeIdStorage,
      session: session,
      runFuture: runFuture,
      relayServer: relayServer,
      database: database,
      lifecycleService: lifecycleService,
      httpClient: httpClient,
    );
  }

  Future<void> close() async {
    await session.cancel();
    try {
      await runFuture.timeout(const Duration(seconds: 10));
    } on Object {
      // run() may have already completed with the error under test.
    }
    await lifecycleService.dispose();
    httpClient.close();
    await database.close();
    await relayServer.close();
  }
}

/// A [TestRelayServer] that also counts how many clients ever connected.
class _CountingRelayServer {
  final TestRelayServer _inner;
  int connectedClientCount = 0;

  _CountingRelayServer._(this._inner);

  static Future<_CountingRelayServer> start() async {
    return _CountingRelayServer._(await TestRelayServer.start());
  }

  int get port => _inner.port;

  Future<WebSocket> nextClient({Duration timeout = const Duration(seconds: 5)}) async {
    final socket = await _inner.nextClient().timeout(timeout);
    connectedClientCount += 1;
    return socket;
  }

  Future<void> close() => _inner.close();
}
