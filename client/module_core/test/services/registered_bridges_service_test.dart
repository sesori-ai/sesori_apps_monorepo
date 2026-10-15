import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/services/registered_bridges_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

class _MockAuthSession() extends Mock implements AuthSession;

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token", bridgeId: null);
const _health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);
const _bridgeOffline = ConnectionStatus.bridgeOffline(config: _config, health: _health);

/// Lets the service's async constructor work (seed + stream listeners) settle.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late MockBridgeRepository bridgeRepository;
  late MockProductAnalyticsService analytics;
  late MockRegisteredBridgesStore store;
  late MockConnectionService connectionService;
  late _MockAuthSession authSession;
  late BehaviorSubject<ConnectionStatus> statusSubject;
  late BehaviorSubject<AuthState> authSubject;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    bridgeRepository = MockBridgeRepository();
    analytics = stubbedProductAnalyticsService();
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
      productAnalyticsService: analytics,
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

    test("returns an immutable cached bridge list", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary()]),
      );
      final service = build();

      await service.getRegisteredBridges();
      final cached = await service.getRegisteredBridges();

      expect(cached.clear, throwsUnsupportedError);
    });

    test("a live bridge connection invalidates the cached bridge list", () async {
      final oldBridge = testBridgeSummary(id: "old", name: "old-macbook");
      final newBridge = testBridgeSummary(id: "new", name: "new-macbook");
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([oldBridge]),
      );
      final service = build();

      expect((await service.getRegisteredBridges()).map((b) => b.id), ["old"]);
      statusSubject.add(_connected);
      await _settle();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([newBridge]),
      );

      expect((await service.getRegisteredBridges()).map((b) => b.id), ["new"]);
      verify(() => bridgeRepository.getRegisteredBridges()).called(2);
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

  group("bridges stream", () {
    test("starts empty and emits each fetched list in display order", () async {
      final older = testBridgeSummary(id: "a", lastSeenAt: DateTime.utc(2026, 6, 1));
      final newer = testBridgeSummary(id: "b", lastSeenAt: DateTime.utc(2026, 7, 1));
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([older, newer]),
      );
      final service = build();
      expect(service.bridges.value, isEmpty);

      await service.getRegisteredBridges();

      expect(service.bridges.value.map((b) => b.id), ["b", "a"]);
    });

    test("a live connection keeps the list until the next fetch replaces it", () async {
      final oldBridge = testBridgeSummary(id: "old");
      final newBridge = testBridgeSummary(id: "new", status: BridgeRegistrationStatus.inactive);
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([oldBridge]),
      );
      final service = build();
      await service.getRegisteredBridges();
      final emissions = <List<BridgeSummary>>[];
      final sub = service.bridges.skip(1).listen(emissions.add);

      statusSubject.add(_connected);
      await _settle();
      expect(service.bridges.value, [oldBridge], reason: "marked stale without emitting");

      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([newBridge]),
      );
      await service.getRegisteredBridges();
      await _settle();

      expect(emissions, [
        [newBridge],
      ]);
      await sub.cancel();
    });

    test("a fetch that finds no bridges emits an empty list", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary()]),
      );
      final service = build();
      await service.getRegisteredBridges();
      statusSubject.add(_connected);
      await _settle();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success(const <BridgeSummary>[]),
      );

      await service.getRegisteredBridges();

      expect(service.bridges.value, isEmpty);
    });

    test("a failed fetch keeps the last list", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary(id: "kept")]),
      );
      final service = build();
      await service.getRegisteredBridges();
      statusSubject.add(_connected);
      await _settle();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.error(ApiError.generic()),
      );

      await service.getRegisteredBridges();

      expect(service.bridges.value.map((b) => b.id), ["kept"]);
    });

    test("logout empties the list", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary()]),
      );
      final service = build();
      await service.getRegisteredBridges();

      authSubject.add(const AuthState.unauthenticated());
      await _settle();

      expect(service.bridges.value, isEmpty);
    });
  });

  group("presence notices", () {
    BridgeRegistrationStatus statusOf({required RegisteredBridgesService service, required String id}) =>
        service.bridges.value.singleWhere((bridge) => bridge.id == id).status;

    test("update a listed computer's status in place without fetching", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary(id: "a"), testBridgeSummary(id: "b")]),
      );
      final service = build();
      await service.getRegisteredBridges();

      connectionService.emitBridgePresence(bridgeId: "b", online: false);
      await _settle();

      expect(statusOf(service: service, id: "b"), BridgeRegistrationStatus.inactive);
      expect(statusOf(service: service, id: "a"), BridgeRegistrationStatus.active);
      verify(() => bridgeRepository.getRegisteredBridges()).called(1);
    });

    test("refetch the list for a computer it does not know", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary(id: "a")]),
      );
      final service = build();
      await service.getRegisteredBridges();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([
          testBridgeSummary(id: "a"),
          testBridgeSummary(id: "new", status: BridgeRegistrationStatus.inactive),
        ]),
      );

      connectionService.emitBridgePresence(bridgeId: "new", online: true);
      await _settle();

      expect(service.bridges.value.map((bridge) => bridge.id), containsAll(["a", "new"]));
      // The auth server has not recorded the relay's report yet; the notice wins.
      expect(statusOf(service: service, id: "new"), BridgeRegistrationStatus.active);
    });

    test("refetch after a running fetch that may predate the link", () async {
      final fetch = Completer<ApiResponse<List<BridgeSummary>>>();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer((_) => fetch.future);
      final service = build();
      final pending = service.getRegisteredBridges();

      connectionService.emitBridgePresence(bridgeId: "new", online: true);
      await _settle();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary(id: "a"), testBridgeSummary(id: "new")]),
      );
      fetch.complete(ApiResponse.success([testBridgeSummary(id: "a")]));
      await pending;
      await _settle();

      expect(service.bridges.value.map((bridge) => bridge.id), containsAll(["a", "new"]));
    });

    test("win over a fetch that started before them", () async {
      final fetch = Completer<ApiResponse<List<BridgeSummary>>>();
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer((_) => fetch.future);
      final service = build();
      final pending = service.getRegisteredBridges();

      connectionService.emitBridgePresence(bridgeId: "a", online: false);
      await _settle();
      fetch.complete(ApiResponse.success([testBridgeSummary(id: "a")]));
      final bridges = await pending;

      expect(bridges.single.status, BridgeRegistrationStatus.inactive);
      expect(statusOf(service: service, id: "a"), BridgeRegistrationStatus.inactive);
    });

    test("are forgotten when the connection drops, so the next fetch decides", () async {
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success([testBridgeSummary(id: "a")]),
      );
      final service = build();
      statusSubject.add(_connected);
      await service.getRegisteredBridges();
      connectionService.emitBridgePresence(bridgeId: "a", online: false);
      await _settle();

      statusSubject.add(const ConnectionStatus.reconnecting(config: _config));
      statusSubject.add(_connected);
      await _settle();
      await service.getRegisteredBridges();

      expect(statusOf(service: service, id: "a"), BridgeRegistrationStatus.active);
    });
  });

  group("rename and remove", () {
    final laptop = testBridgeSummary(id: "a", name: "laptop", hostname: "laptop");
    final desktop = testBridgeSummary(id: "b", name: "desktop", hostname: "desktop");

    Future<RegisteredBridgesService> buildListed() async {
      when(() => bridgeRepository.getRegisteredBridges())
          .thenAnswer((_) async => ApiResponse.success([laptop, desktop]));
      final service = build();
      await service.getRegisteredBridges();
      return service;
    }

    List<Object?> reportedEvents() => verify(
      () => analytics.logEvent(
        event: captureAny(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).captured;

    test("rename replaces the entry with the returned summary and reports it", () async {
      final renamed = testBridgeSummary(id: "a", name: "Studio", hostname: "laptop");
      when(
        () => bridgeRepository.renameBridge(bridgeId: "a", nickname: "Studio"),
      ).thenAnswer((_) async => ApiResponse.success(renamed));
      final service = await buildListed();

      final response = await service.rename(bridgeId: "a", nickname: "Studio");

      expect(response, isA<SuccessResponse<BridgeSummary>>());
      expect(service.bridges.value, [renamed, desktop]);
      expect(reportedEvents(), [const ProductAnalyticsEvent.computerManaged(action: ComputerManageAction.renamed)]);
    });

    test("rename keeps a presence notice over the returned status", () async {
      when(
        () => bridgeRepository.renameBridge(bridgeId: "a", nickname: null),
      ).thenAnswer((_) async => ApiResponse.success(laptop));
      final service = await buildListed();
      connectionService.emitBridgePresence(bridgeId: "a", online: false);
      await _settle();

      await service.rename(bridgeId: "a", nickname: null);

      expect(service.bridges.value.first.status, BridgeRegistrationStatus.inactive);
    });

    test("remove drops the entry and reports it", () async {
      when(() => bridgeRepository.deleteBridge(bridgeId: "a")).thenAnswer((_) async => ApiResponse.success(null));
      final service = await buildListed();

      final response = await service.remove(bridgeId: "a");

      expect(response, isA<SuccessResponse<void>>());
      expect(service.bridges.value, [desktop]);
      expect(reportedEvents(), [const ProductAnalyticsEvent.computerManaged(action: ComputerManageAction.removed)]);
    });

    test("a logout during a removal discards its result", () async {
      final gate = Completer<ApiResponse<void>>();
      when(() => bridgeRepository.deleteBridge(bridgeId: "a")).thenAnswer((_) => gate.future);
      final service = await buildListed();

      final pending = service.remove(bridgeId: "a");
      authSubject.add(const AuthState.unauthenticated());
      await _settle();
      gate.complete(ApiResponse.success(null));
      await pending;

      expect(service.bridges.value, isEmpty);
      verifyNever(
        () => analytics.logEvent(
          event: any(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });

    test("a fetch that started before a removal cannot bring the computer back", () async {
      final service = await buildListed();
      clearInteractions(bridgeRepository);
      final staleFetch = Completer<ApiResponse<List<BridgeSummary>>>();
      final responses = [
        staleFetch.future,
        Future.value(ApiResponse.success([desktop])),
      ];
      when(() => bridgeRepository.getRegisteredBridges()).thenAnswer((_) => responses.removeAt(0));
      when(() => bridgeRepository.deleteBridge(bridgeId: "a")).thenAnswer((_) async => ApiResponse.success(null));
      // An unknown computer's notice starts a fetch that reads the list before the removal.
      connectionService.emitBridgePresence(bridgeId: "c", online: true);
      await _settle();

      await service.remove(bridgeId: "a");
      final published = <List<BridgeSummary>>[];
      final subscription = service.bridges.skip(1).listen(published.add);
      addTearDown(subscription.cancel);
      // A second unknown notice queues behind the same stale fetch and shares its refetch.
      connectionService.emitBridgePresence(bridgeId: "d", online: true);
      staleFetch.complete(ApiResponse.success([laptop, desktop]));
      await _settle();

      expect(service.bridges.value, [desktop]);
      // The stale snapshot is never published, so the removed row does not flash back.
      expect(published, everyElement(isNot(contains(laptop))));
      expect(responses, isEmpty);
      verify(() => bridgeRepository.getRegisteredBridges()).called(2);
    });

    test("removing the last computer makes the next read ask the server", () async {
      final service = await buildListed();
      when(() => bridgeRepository.deleteBridge(bridgeId: any(named: "bridgeId")))
          .thenAnswer((_) async => ApiResponse.success(null));
      await service.remove(bridgeId: "a");
      await service.remove(bridgeId: "b");
      clearInteractions(bridgeRepository);

      await service.getRegisteredBridges();

      verify(() => bridgeRepository.getRegisteredBridges()).called(1);
    });

    test("a failure leaves the list unchanged, is returned, and reports nothing", () async {
      final failure = ApiError.nonSuccessCode(errorCode: 503, rawErrorString: "offline");
      when(
        () => bridgeRepository.renameBridge(bridgeId: "a", nickname: "Studio"),
      ).thenAnswer((_) async => ApiResponse.error(failure));
      when(() => bridgeRepository.deleteBridge(bridgeId: "a")).thenAnswer((_) async => ApiResponse.error(failure));
      final service = await buildListed();

      final renameResponse = await service.rename(bridgeId: "a", nickname: "Studio");
      final removeResponse = await service.remove(bridgeId: "a");

      expect(renameResponse, isA<ErrorResponse<BridgeSummary>>());
      expect(removeResponse, isA<ErrorResponse<void>>());
      expect(service.bridges.value, [laptop, desktop]);
      verifyNever(
        () => analytics.logEvent(
          event: any(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
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

    test("a logout while the startup store seed is in flight discards the stale latch", () async {
      final seedGate = Completer<bool>();
      when(() => store.hasRegisteredBridges()).thenAnswer((_) => seedGate.future);
      final service = build();
      await _settle();

      authSubject.add(const AuthState.unauthenticated());
      await _settle();
      seedGate.complete(true);
      await _settle();

      expect(service.isRegistered.value, isFalse);
    });

    test("a logout while store resolution is in flight discards the stale latch", () async {
      final service = build();
      await _settle();
      final resolutionGate = Completer<bool>();
      when(() => store.hasRegisteredBridges()).thenAnswer((_) => resolutionGate.future);

      final pending = service.hasRegisteredBridges();
      await _settle();
      authSubject.add(const AuthState.unauthenticated());
      await _settle();
      resolutionGate.complete(true);

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
