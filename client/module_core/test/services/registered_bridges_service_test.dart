import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/services/registered_bridges_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

class _MockAuthSession extends Mock implements AuthSession {}

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
const _health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
const _connected = ConnectionStatus.connected(config: _config, health: _health);
const _bridgeOffline = ConnectionStatus.bridgeOffline(config: _config, health: _health);

/// Lets the service's async constructor work (seed + stream listeners) settle.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late MockBridgeRepository bridgeRepository;
  late MockRegisteredBridgesStore store;
  late MockConnectionService connectionService;
  late _MockAuthSession authSession;
  late BehaviorSubject<ConnectionStatus> statusSubject;
  late BehaviorSubject<AuthState> authSubject;

  setUp(() {
    bridgeRepository = MockBridgeRepository();
    store = MockRegisteredBridgesStore();
    connectionService = MockConnectionService();
    authSession = _MockAuthSession();
    statusSubject = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
    authSubject = BehaviorSubject<AuthState>.seeded(const AuthState.initial());

    // Stubs must be set before building — the constructor subscribes immediately.
    when(() => connectionService.status).thenAnswer((_) => statusSubject.stream);
    when(() => authSession.authStateStream).thenAnswer((_) => authSubject.stream);
    // Defaults: nothing latched, the auth server reports no registered bridges.
    when(() => store.hasRegisteredBridges()).thenAnswer((_) async => false);
    when(() => store.markRegistered()).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});
    when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
      (_) async => ApiResponse.success(const <BridgeSummary>[]),
    );
  });

  tearDown(() async {
    await statusSubject.close();
    await authSubject.close();
  });

  RegisteredBridgesService build() {
    final service = RegisteredBridgesService(
      bridgeRepository: bridgeRepository,
      registeredBridgesStore: store,
      connectionService: connectionService,
      authSession: authSession,
    );
    addTearDown(service.dispose);
    return service;
  }

  group("hasRegisteredBridges resolution", () {
    test("a fresh account (store empty, auth server empty) resolves false and does not latch", () async {
      final service = build();

      expect(await service.hasRegisteredBridges(), isFalse);
      expect(service.isRegistered.value, isFalse);
      verifyNever(() => store.markRegistered());
    });

    test("a non-empty auth-server result resolves true, latches the store, and emits true", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary()]),
      );
      final service = build();

      expect(await service.hasRegisteredBridges(), isTrue);
      expect(service.isRegistered.value, isTrue);
      verify(() => store.markRegistered()).called(1);
    });

    test("a store-latched account resolves true without touching the network", () async {
      when(() => store.hasRegisteredBridges()).thenAnswer((_) async => true);
      final service = build();

      expect(await service.hasRegisteredBridges(), isTrue);
      verifyNever(() => bridgeRepository.getRegisteredBridges());
      verifyNever(() => store.markRegistered());
    });

    test("an auth-server error fails soft to false and does not latch", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.error(ApiError.generic()),
      );
      final service = build();

      expect(await service.hasRegisteredBridges(), isFalse);
      verifyNever(() => store.markRegistered());
    });

    test("an unexpected throw from the repository is caught and resolves false", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => throw Exception("network blew up"),
      );
      final service = build();

      expect(await service.hasRegisteredBridges(), isFalse);
    });

    test("concurrent callers are coalesced into a single network lookup", () async {
      final gate = Completer<ApiResponse<List<BridgeSummary>>>();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer((_) => gate.future);
      final service = build();

      final a = service.hasRegisteredBridges();
      final b = service.hasRegisteredBridges();
      gate.complete(ApiResponse.success([testBridgeSummary()]));

      expect(await Future.wait([a, b]), [isTrue, isTrue]);
      verify(() => bridgeRepository.getRegisteredBridges()).called(1);
    });
  });

  group("getRegisteredBridges", () {
    test("returns the fetched bridges most recently seen first and latches the store", () async {
      final seenEarlier = testBridgeSummary(id: "a", name: "old-laptop", lastSeenAt: DateTime.utc(2026, 6, 1));
      final seenLatest = testBridgeSummary(id: "b", name: "new-laptop", lastSeenAt: DateTime.utc(2026, 7, 1));
      final seenSameTimeNewer = testBridgeSummary(
        id: "e",
        name: "newest-tied-laptop",
        addedAt: DateTime.utc(2026, 5, 3),
        lastSeenAt: DateTime.utc(2026, 6, 1),
      );
      final neverSeenNewer = testBridgeSummary(id: "c", name: "fresh-desktop", addedAt: DateTime.utc(2026, 5, 2));
      final neverSeenOlder = testBridgeSummary(id: "d", name: "stale-desktop", addedAt: DateTime.utc(2026, 5, 1));
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([neverSeenOlder, seenEarlier, seenSameTimeNewer, neverSeenNewer, seenLatest]),
      );
      final service = build();

      final bridges = await service.getRegisteredBridges();

      expect(bridges.map((b) => b.id), ["b", "e", "a", "c", "d"]);
      expect(service.isRegistered.value, isTrue);
      verify(() => store.markRegistered()).called(1);
    });

    test("reuses a bridge list fetched while resolving the registered latch", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary()]),
      );
      final service = build();

      expect(await service.hasRegisteredBridges(), isTrue);
      final bridges = await service.getRegisteredBridges();

      expect(bridges, hasLength(1));
      verify(() => bridgeRepository.getRegisteredBridges()).called(1);
    });

    test("logout clears the cached bridge list", () async {
      final oldBridge = testBridgeSummary(id: "old", name: "old-macbook");
      final newBridge = testBridgeSummary(id: "new", name: "new-macbook");
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([oldBridge]),
      );
      final service = build();

      expect((await service.getRegisteredBridges()).map((b) => b.id), ["old"]);
      authSubject.add(const AuthState.unauthenticated());
      await _settle();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([newBridge]),
      );

      expect((await service.getRegisteredBridges()).map((b) => b.id), ["new"]);
      verify(() => bridgeRepository.getRegisteredBridges()).called(2);
    });

    test("an empty result returns an empty list without latching", () async {
      final service = build();

      expect(await service.getRegisteredBridges(), isEmpty);
      expect(service.isRegistered.value, isFalse);
      verifyNever(() => store.markRegistered());
    });

    test("an error response fails soft to an empty list", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.error(ApiError.generic()),
      );
      final service = build();

      expect(await service.getRegisteredBridges(), isEmpty);
      verifyNever(() => store.markRegistered());
    });

    test("an unexpected throw fails soft to an empty list", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => throw Exception("network blew up"),
      );
      final service = build();

      expect(await service.getRegisteredBridges(), isEmpty);
    });

    test("concurrent callers are coalesced into a single network fetch", () async {
      final gate = Completer<ApiResponse<List<BridgeSummary>>>();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer((_) => gate.future);
      final service = build();

      final a = service.getRegisteredBridges();
      final b = service.getRegisteredBridges();
      gate.complete(ApiResponse.success([testBridgeSummary()]));

      final results = await Future.wait([a, b]);
      expect(results[0], hasLength(1));
      expect(results[1], hasLength(1));
      verify(() => bridgeRepository.getRegisteredBridges()).called(1);
    });

    test("a logout during the fetch retires the result instead of leaking it", () async {
      final gate = Completer<ApiResponse<List<BridgeSummary>>>();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer((_) => gate.future);
      final service = build();
      await _settle();

      final pending = service.getRegisteredBridges();
      await _settle();
      authSubject.add(const AuthState.unauthenticated());
      await _settle();
      gate.complete(ApiResponse.success([testBridgeSummary()]));

      expect(await pending, isEmpty);
      expect(service.isRegistered.value, isFalse);
      verifyNever(() => store.markRegistered());
    });
  });

  group("reactive latch", () {
    test("seeds the stream from a persisted store latch at construction (no network)", () async {
      when(() => store.hasRegisteredBridges()).thenAnswer((_) async => true);
      final service = build();

      await _settle();

      expect(service.isRegistered.value, isTrue);
      verifyNever(() => bridgeRepository.getRegisteredBridges());
    });

    test("a successful E2E connection latches the signal without a lookup", () async {
      final service = build();
      await _settle();
      expect(service.isRegistered.value, isFalse);

      statusSubject.add(_connected);
      await _settle();

      expect(service.isRegistered.value, isTrue);
      verify(() => store.markRegistered()).called(1);
      verifyNever(() => bridgeRepository.getRegisteredBridges());
    });

    test("a bridge-offline park resolves the signal so stream-only consumers see it", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary()]),
      );
      final service = build();
      await _settle();
      expect(service.isRegistered.value, isFalse);

      statusSubject.add(_bridgeOffline);
      await _settle();

      expect(service.isRegistered.value, isTrue);
      verify(() => bridgeRepository.getRegisteredBridges()).called(1);
    });

    test("a no-bridge account parking offline keeps the signal false (the onboarding case)", () async {
      final service = build();
      await _settle();

      statusSubject.add(_bridgeOffline);
      await _settle();

      expect(service.isRegistered.value, isFalse);
    });

    test("logout resets the latch so a different account does not inherit it", () async {
      final service = build();
      statusSubject.add(_connected);
      await _settle();
      expect(service.isRegistered.value, isTrue);

      final emissions = <bool>[];
      final sub = service.isRegistered.listen(emissions.add);
      authSubject.add(const AuthState.unauthenticated());
      await _settle();

      expect(service.isRegistered.value, isFalse);
      expect(emissions, [isTrue, isFalse], reason: "current value replayed, then reset to false");
      await sub.cancel();
    });

    test("non-logout auth states leave the latch untouched", () async {
      final service = build();
      statusSubject.add(_connected);
      await _settle();
      expect(service.isRegistered.value, isTrue);

      authSubject
        ..add(const AuthState.authenticating())
        ..add(const AuthState.failed(error: "boom"));
      await _settle();

      expect(service.isRegistered.value, isTrue);
    });
  });

  group("logout invalidates in-flight writes", () {
    test("a logout while a network lookup is in flight discards the result", () async {
      final gate = Completer<ApiResponse<List<BridgeSummary>>>();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer((_) => gate.future);
      final service = build();
      await _settle();

      // Park offline to drive a network lookup, then log out before the auth
      // server answers.
      statusSubject.add(_bridgeOffline);
      await _settle();
      authSubject.add(const AuthState.unauthenticated());
      await _settle();

      // The lookup now resolves — too late. A non-empty result for the
      // signed-out account must not latch onto the device.
      gate.complete(ApiResponse.success([testBridgeSummary()]));
      await _settle();

      expect(service.isRegistered.value, isFalse);
      verifyNever(() => store.markRegistered());
    });

    test("a logout while a connection-driven latch is persisting undoes it", () async {
      final gate = Completer<void>();
      when(() => store.markRegistered()).thenAnswer((_) => gate.future);
      final service = build();
      await _settle();

      // A live connection drives a latch; log out while markRegistered is still
      // in flight.
      statusSubject.add(_connected);
      await _settle();
      authSubject.add(const AuthState.unauthenticated());
      await _settle();

      // The persist lands after the logout — the service undoes it and never
      // emits true.
      gate.complete();
      await _settle();

      expect(service.isRegistered.value, isFalse);
      verify(() => store.clear()).called(1);
    });

    test("a logout while the lookup's latch is persisting resolves the caller false", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary()]),
      );
      final markGate = Completer<void>();
      when(() => store.markRegistered()).thenAnswer((_) => markGate.future);
      final service = build();
      await _settle();

      // Drive a network lookup that finds a bridge, then log out while the
      // positive answer is still being persisted.
      final pending = service.hasRegisteredBridges();
      await _settle();
      authSubject.add(const AuthState.unauthenticated());
      await _settle();

      // The persist lands after the logout: the latch is retired, so the caller
      // must see false rather than the signed-out account's stale success.
      markGate.complete();

      expect(await pending, isFalse);
      expect(service.isRegistered.value, isFalse);
    });

    test("a stale latch completing after a new account latched does not wipe the new latch", () async {
      var markCalls = 0;
      final firstMarkGate = Completer<void>();
      when(() => store.markRegistered()).thenAnswer((_) async {
        markCalls++;
        if (markCalls == 1) await firstMarkGate.future;
      });
      final service = build();
      await _settle();

      // Old account: a live connection drives a latch whose persist stalls.
      statusSubject.add(_connected);
      await _settle();

      // Log out, then a new account signs in and latches its own answer.
      authSubject.add(const AuthState.unauthenticated());
      await _settle();
      statusSubject.add(_connected);
      await _settle();
      expect(service.isRegistered.value, isTrue, reason: "new account latched");

      // The old account's stalled persist finally lands. Its undo must not wipe
      // the valid latch the new account just wrote.
      firstMarkGate.complete();
      await _settle();

      expect(service.isRegistered.value, isTrue);
      verifyNever(() => store.clear());
    });
  });
}
