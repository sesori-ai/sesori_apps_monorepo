import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayCryptoService extends Mock implements RelayCryptoService {}

class MockRoomKeyStorage extends Mock implements RoomKeyStorage {}

class MockAuthTokenProvider extends Mock implements AuthTokenProvider {}

class MockAuthSession extends Mock implements AuthSession {}

class MockLifecycleSource extends Mock implements LifecycleSource {}

class MockFailureReporter extends Mock implements FailureReporter {}

class _TestClockProvider extends ClockProvider {
  final DateTime Function() _now;
  _TestClockProvider(this._now);

  @override
  DateTime call() => _now();
}

void main() {
  group("ConnectionService stale reconnect", () {
    late MockRelayCryptoService cryptoService;
    late MockRoomKeyStorage roomKeyStorage;
    late MockAuthTokenProvider authTokenProvider;
    late MockAuthSession authSession;
    late MockLifecycleSource lifecycleSource;
    late BehaviorSubject<LifecycleState> lifecycleController;
    late BehaviorSubject<AuthState> authStateController;
    late DateTime now;
    late ConnectionService service;

    const config = ServerConnectionConfig(
      relayHost: "relay.example.com",
      authToken: "token",
    );

    const health = HealthResponse(healthy: true, version: "0.1.200", serverManaged: false, serverState: null);

    Future<void> flush() => Future<void>.delayed(Duration.zero);

    setUp(() {
      cryptoService = MockRelayCryptoService();
      roomKeyStorage = MockRoomKeyStorage();
      authTokenProvider = MockAuthTokenProvider();
      authSession = MockAuthSession();
      lifecycleSource = MockLifecycleSource();
      lifecycleController = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
      authStateController = BehaviorSubject<AuthState>.seeded(const AuthState.initial());
      now = DateTime(2025, 1, 1, 12, 0, 0);

      when(() => lifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleController.stream);
      when(() => authSession.authStateStream).thenAnswer((_) => authStateController.stream);

      service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        MockFailureReporter(),
        clock: _TestClockProvider(() => now),
      );
    });

    tearDown(() async {
      service.dispose();
      await lifecycleController.close();
      await authStateController.close();
    });

    test("dataMayBeStale emits when app resumes after >= 5 minutes pause", () async {
      service.emitStatusForTesting(const ConnectionStatus.connected(config: config, health: health));

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 5));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 1);
      await sub.cancel();
    });

    test("dataMayBeStale does NOT emit when app resumes after < staleThreshold pause", () async {
      service.emitStatusForTesting(const ConnectionStatus.connected(config: config, health: health));

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      // 4 minutes is safely under the 4:30 stale threshold (90% of 5 min)
      now = now.add(const Duration(minutes: 4));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 0);
      await sub.cancel();
    });

    test("dataMayBeStale emits when connection was dropped AND pause >= 5 minutes", () async {
      service.emitStatusForTesting(const ConnectionStatus.connectionLost(config: config));

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 6));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 1);
      await sub.cancel();
    });

    test("dataMayBeStale does NOT emit when app was never connected (disconnected status)", () async {
      service.emitStatusForTesting(const ConnectionStatus.disconnected());

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 6));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 0);
      await sub.cancel();
    });

    test("backgroundedAt is reset on each new background entry", () async {
      service.emitStatusForTesting(const ConnectionStatus.connected(config: config, health: health));

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 2));
      lifecycleController.add(LifecycleState.resumed);
      await flush();
      expect(staleEmissions, 0);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 6));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 1);
      await sub.cancel();
    });

    test("dataMayBeStale does NOT emit on repeated resume without intervening background", () async {
      service.emitStatusForTesting(const ConnectionStatus.connected(config: config, health: health));

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 6));
      lifecycleController.add(LifecycleState.resumed);
      await flush();
      expect(staleEmissions, 1);

      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 1);
      await sub.cancel();
    });
  });
}
