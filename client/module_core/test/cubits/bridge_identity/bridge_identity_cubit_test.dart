import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/bridge_identity/bridge_identity_cubit.dart";
import "package:sesori_dart_core/src/cubits/bridge_identity/bridge_identity_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Guards the machine identity the Projects bar names: it resolves to exactly
// one terminal answer (named or unnamed) so a consumer's placeholder is always
// released, it costs no bridge-list fetch for a bridge-less account, and it
// retries on reconnect.
// ---------------------------------------------------------------------------

const _connectionConfig = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
const _health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
const _connectedStatus = ConnectionStatus.connected(config: _connectionConfig, health: _health);
const _bridgeOfflineStatus = ConnectionStatus.bridgeOffline(config: _connectionConfig, health: _health);

void main() {
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late MockConnectionService mockConnectionService;
  late BehaviorSubject<ConnectionStatus> statusController;

  setUp(() {
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    mockConnectionService = MockConnectionService();
    statusController = BehaviorSubject<ConnectionStatus>.seeded(_bridgeOfflineStatus);

    // Must be stubbed before any cubit is built — the constructor subscribes
    // and starts its lookup immediately.
    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    await statusController.close();
  });

  BridgeIdentityCubit buildCubit() => BridgeIdentityCubit(
    registeredBridgesService: mockRegisteredBridgesService,
    connectionService: mockConnectionService,
  );

  test("starts pending: the lookup is a round trip, so nothing can be named yet", () {
    final cubit = buildCubit();
    addTearDown(cubit.close);
    expect(cubit.state, const BridgeIdentityState.pending());
  });

  blocTest<BridgeIdentityCubit, BridgeIdentityState>(
    "names the most recently seen registered bridge",
    build: () {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [
          testBridgeSummary(id: "a", name: "Macbook-Pro.local"),
          testBridgeSummary(id: "b", name: "work-desktop"),
        ],
      );
      return buildCubit();
    },
    expect: () => [
      isA<BridgeIdentityNamed>().having((s) => s.bridge.name, "named machine", "Macbook-Pro.local"),
    ],
  );

  blocTest<BridgeIdentityCubit, BridgeIdentityState>(
    "a bridge-less account resolves to unnamed without spending a bridge-list fetch",
    build: () {
      when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => false);
      return buildCubit();
    },
    // The Projects onboarding reports what it is waiting for instead of naming
    // a machine, so the row is dropped rather than left waiting.
    expect: () => [const BridgeIdentityState.unnamed()],
    verify: (_) => verifyNever(() => mockRegisteredBridgesService.getRegisteredBridges()),
  );

  blocTest<BridgeIdentityCubit, BridgeIdentityState>(
    "a fail-soft empty fetch resolves to unnamed rather than staying pending",
    // The setUp default fetch answers empty — the service's fail-soft error
    // shape. Leaving the state pending would shimmer a placeholder forever.
    build: buildCubit,
    expect: () => [const BridgeIdentityState.unnamed()],
  );

  blocTest<BridgeIdentityCubit, BridgeIdentityState>(
    "a reconnect retries a lookup that came back empty",
    build: buildCubit,
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero); // the first lookup lands unnamed
      // The phone was offline for the first attempt; the bridge is reachable now
      // and the service has dropped its cached list.
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [testBridgeSummary(name: "Macbook-Pro.local")],
      );
      statusController.add(_connectedStatus);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const BridgeIdentityState.unnamed(),
      isA<BridgeIdentityNamed>().having((s) => s.bridge.name, "named machine", "Macbook-Pro.local"),
    ],
  );

  blocTest<BridgeIdentityCubit, BridgeIdentityState>(
    "parking offline retries a lookup that came back empty",
    build: buildCubit,
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero); // the first lookup lands unnamed
      // The phone had no network for the first attempt. It is back now, but the
      // bridge is still off — so the relay parks instead of connecting, and this
      // is exactly the surface that has to name the machine to start.
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [testBridgeSummary(name: "Macbook-Pro.local")],
      );
      statusController.add(_bridgeOfflineStatus);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const BridgeIdentityState.unnamed(),
      isA<BridgeIdentityNamed>().having((s) => s.bridge.name, "named machine", "Macbook-Pro.local"),
    ],
  );

  blocTest<BridgeIdentityCubit, BridgeIdentityState>(
    "a bridge going offline keeps the machine it named",
    build: () {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [testBridgeSummary(name: "Macbook-Pro.local")],
      );
      return buildCubit();
    },
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      // The park re-resolves, but which machine is registered hasn't changed, so
      // the recovery view keeps naming the same one without a second emit.
      statusController.add(_bridgeOfflineStatus);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      isA<BridgeIdentityNamed>().having((s) => s.bridge.name, "named machine", "Macbook-Pro.local"),
    ],
  );
}
