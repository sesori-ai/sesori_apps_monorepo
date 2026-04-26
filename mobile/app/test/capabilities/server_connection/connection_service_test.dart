import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/subjects.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";

import "../../helpers/test_helpers.dart";

class MockAuthTokenProvider extends Mock implements AuthTokenProvider {}

class MockAuthSession extends Mock implements AuthSession {}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockRelayCryptoService cryptoService;
  late MockRoomKeyStorage roomKeyStorage;
  late MockAuthTokenProvider authTokenProvider;
  late MockAuthSession authSession;
  late MockLifecycleSource lifecycleSource;
  late MockFailureReporter failureReporter;
  late BehaviorSubject<AuthState> authStateController;
  late ConnectionService service;

  setUp(() {
    cryptoService = MockRelayCryptoService();
    roomKeyStorage = MockRoomKeyStorage();
    authTokenProvider = MockAuthTokenProvider();
    authSession = MockAuthSession();
    lifecycleSource = MockLifecycleSource();
    failureReporter = MockFailureReporter();
    authStateController = BehaviorSubject<AuthState>.seeded(const AuthState.initial());

    when(() => authSession.authStateStream).thenAnswer((_) => authStateController.stream);
    when(() => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl"))).thenAnswer((_) async => null);
    when(roomKeyStorage.clearRoomKey).thenAnswer((_) async {});

    service = ConnectionService(
      cryptoService,
      roomKeyStorage,
      authTokenProvider,
      authSession,
      lifecycleSource,
      failureReporter,
    );
  });

  tearDown(() async {
    service.dispose();
    await authStateController.close();
  });

  group("ConnectionService", () {
    // ------------------------------------------------------------------
    // 1. Initial status
    // ------------------------------------------------------------------

    test("initial status is disconnected", () {
      expect(service.currentStatus, isA<ConnectionDisconnected>());
    });

    // ------------------------------------------------------------------
    // 2. currentStatus synchronous access
    // ------------------------------------------------------------------

    test("currentStatus returns synchronous value matching status stream", () {
      expect(service.currentStatus, equals(service.status.value));
    });

    // ------------------------------------------------------------------
    // 3. disconnect
    // ------------------------------------------------------------------

    test("disconnect: status emits disconnected and activeConfig becomes null", () {
      service.disconnect();

      expect(service.currentStatus, isA<ConnectionDisconnected>());
      expect(service.activeConfig, isNull);
    });

    // ------------------------------------------------------------------
    // 4. setActiveDirectory
    // ------------------------------------------------------------------

    test("setActiveDirectory: sets and retrieves activeDirectory", () {
      const directory = "/home/user/my-project";

      expect(service.activeDirectory, isNull);

      service.setActiveDirectory(directory);

      expect(service.activeDirectory, equals(directory));
    });

    // ------------------------------------------------------------------
    // 5. status stream immediate seed
    // ------------------------------------------------------------------

    test("status stream immediately emits disconnected seed value", () async {
      final statuses = <ConnectionStatus>[];
      final subscription = service.status.listen(statuses.add);

      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(statuses, [isA<ConnectionDisconnected>()]);
    });

    // ------------------------------------------------------------------
    // 6. Lifecycle stream integration
    // ------------------------------------------------------------------

    test("LifecycleState.paused triggers backgrounding (idempotent)", () async {
      lifecycleSource.emitState(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      // Second emission is a no-op — should not throw.
      lifecycleSource.emitState(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
    });

    test("LifecycleState.resumed is a no-op when already in foreground", () async {
      // Already resumed (seeded state) — should not throw.
      lifecycleSource.emitState(LifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
    });

    test("paused then resumed: round-trip completes without error", () async {
      lifecycleSource.emitState(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      lifecycleSource.emitState(LifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
    });

    test("resumed is idempotent after round-trip", () async {
      lifecycleSource.emitState(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      lifecycleSource.emitState(LifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      // Already foregrounded — should not throw.
      lifecycleSource.emitState(LifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
    });

    test("inactive and hidden states do not throw", () async {
      lifecycleSource.emitState(LifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      lifecycleSource.emitState(LifecycleState.hidden);
      await Future<void>.delayed(Duration.zero);
    });

    test("AuthUnauthenticated triggers disconnect and room key clear", () async {
      final statuses = <ConnectionStatus>[];
      final subscription = service.status.listen(statuses.add);

      authStateController.add(const AuthState.unauthenticated());
      await Future<void>.delayed(Duration.zero);

      final disconnectedStatuses = statuses.whereType<ConnectionDisconnected>().length;
      expect(disconnectedStatuses, greaterThanOrEqualTo(2));
      expect(service.currentStatus, isA<ConnectionDisconnected>());
      verify(roomKeyStorage.clearRoomKey).called(1);

      await subscription.cancel();
    });
  });
}
