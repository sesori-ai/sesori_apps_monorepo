import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/connection_overlay/connection_overlay_cubit.dart";
import "package:sesori_dart_core/src/cubits/connection_overlay/connection_overlay_state.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

void main() {
  group("ConnectionOverlayCubit", () {
    late MockConnectionService mockConnectionService;
    late MockAuthSession mockAuthSession;
    late MockRegisteredBridgesService mockRegisteredBridgesService;
    late BehaviorSubject<ConnectionStatus> statusStream;
    late BehaviorSubject<bool> registeredStream;

    const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
    const health = HealthResponse(healthy: true, version: "0.1.200");
    const connected = ConnectionStatus.connected(config: config, health: health);
    const reconnecting = ConnectionStatus.reconnecting(config: config);
    const connectionLost = ConnectionStatus.connectionLost(config: config);
    const bridgeOffline = ConnectionStatus.bridgeOffline(config: config, health: health);

    setUp(() {
      mockConnectionService = MockConnectionService();
      mockAuthSession = MockAuthSession();
      mockRegisteredBridgesService = MockRegisteredBridgesService();
      statusStream = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
      registeredStream = BehaviorSubject<bool>.seeded(false);

      when(() => mockConnectionService.status).thenAnswer((_) => statusStream.stream);
      when(() => mockConnectionService.currentStatus).thenReturn(const ConnectionStatus.disconnected());
      when(() => mockRegisteredBridgesService.isRegistered).thenAnswer((_) => registeredStream.stream);
      when(() => mockAuthSession.logoutCurrentDevice()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await statusStream.close();
      await registeredStream.close();
    });

    ConnectionOverlayCubit buildCubit() =>
        ConnectionOverlayCubit(mockConnectionService, mockAuthSession, mockRegisteredBridgesService);

    blocTest<ConnectionOverlayCubit, ConnectionOverlayState>(
      "starts hidden when disconnected and not registered",
      build: buildCubit,
      verify: (cubit) {
        expect(cubit.state, const ConnectionOverlayState.hidden());
      },
    );

    blocTest<ConnectionOverlayCubit, ConnectionOverlayState>(
      "maps connection statuses to overlay states",
      build: buildCubit,
      act: (_) async {
        statusStream.add(connectionLost);
        await Future<void>.delayed(Duration.zero);
        statusStream.add(reconnecting);
        await Future<void>.delayed(Duration.zero);
        statusStream.add(connected);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const [
        ConnectionOverlayState.connectionLost(),
        ConnectionOverlayState.reconnecting(),
        ConnectionOverlayState.hidden(),
      ],
    );

    blocTest<ConnectionOverlayCubit, ConnectionOverlayState>(
      "bridge offline with NO registered bridge stays hidden (onboarding must not show the banner)",
      build: buildCubit,
      act: (_) async {
        statusStream.add(bridgeOffline);
        await Future<void>.delayed(Duration.zero);
      },
      // bridgeOffline + unregistered derives hidden, which equals the initial
      // hidden state, so bloc dedupes it — the proof is the unchanged state.
      expect: () => const <ConnectionOverlayState>[],
      verify: (cubit) {
        expect(cubit.state, isA<ConnectionOverlayHidden>());
      },
    );

    blocTest<ConnectionOverlayCubit, ConnectionOverlayState>(
      "bridge offline with a registered bridge shows the banner",
      build: () {
        registeredStream.add(true);
        return buildCubit();
      },
      act: (_) async {
        statusStream.add(bridgeOffline);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const [ConnectionOverlayState.bridgeOffline()],
    );

    blocTest<ConnectionOverlayCubit, ConnectionOverlayState>(
      "banner appears reactively when registration resolves true while parked offline",
      build: buildCubit,
      act: (_) async {
        // Parked offline before the latch is known → still hidden (no emission).
        statusStream.add(bridgeOffline);
        await Future<void>.delayed(Duration.zero);
        // The registered-bridges latch resolves true → the banner appears.
        registeredStream.add(true);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const [ConnectionOverlayState.bridgeOffline()],
    );

    blocTest<ConnectionOverlayCubit, ConnectionOverlayState>(
      "reconnect() delegates to connectionService.reconnect()",
      build: buildCubit,
      act: (cubit) => cubit.reconnect(),
      verify: (_) {
        verify(() => mockConnectionService.reconnect()).called(1);
      },
    );

    blocTest<ConnectionOverlayCubit, ConnectionOverlayState>(
      "disconnect() logs out then disconnects",
      build: buildCubit,
      act: (cubit) => cubit.disconnect(),
      verify: (_) {
        verify(() => mockAuthSession.logoutCurrentDevice()).called(1);
        verify(() => mockConnectionService.disconnect()).called(1);
      },
    );

    blocTest<ConnectionOverlayCubit, ConnectionOverlayState>(
      "closing the cubit cancels its stream subscriptions",
      build: buildCubit,
      act: (cubit) => cubit.close(),
      verify: (_) {
        expect(statusStream.hasListener, isFalse);
        expect(registeredStream.hasListener, isFalse);
      },
    );
  });
}
