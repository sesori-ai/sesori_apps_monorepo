import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/connection_overlay/connection_overlay_cubit.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

void main() {
  group("ConnectionOverlayCubit", () {
    late MockConnectionService mockConnectionService;
    late MockAuthSession mockAuthSession;
    late BehaviorSubject<ConnectionStatus> statusStream;

    setUpAll(registerAllFallbackValues);

    setUp(() {
      mockConnectionService = MockConnectionService();
      mockAuthSession = MockAuthSession();
      statusStream = BehaviorSubject<ConnectionStatus>.seeded(
        const ConnectionStatus.disconnected(),
      );

      // Mock the status stream getter
      when(() => mockConnectionService.status).thenAnswer((_) => statusStream.stream);

      // Mock currentStatus getter
      when(() => mockConnectionService.currentStatus).thenReturn(
        const ConnectionStatus.disconnected(),
      );
      when(() => mockAuthSession.logoutCurrentDevice()).thenAnswer((_) async {
        return;
      });
    });

    tearDown(() async {
      await statusStream.close();
    });

    blocTest<ConnectionOverlayCubit, ConnectionStatus>(
      "initial state matches connectionService.currentStatus",
      build: () => ConnectionOverlayCubit(mockConnectionService, mockAuthSession),
      verify: (cubit) {
        expect(cubit.state, const ConnectionStatus.disconnected());
      },
    );

    blocTest<ConnectionOverlayCubit, ConnectionStatus>(
      "forwards status stream emissions to cubit state",
      build: () => ConnectionOverlayCubit(mockConnectionService, mockAuthSession),
      act: (cubit) async {
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(
          healthy: true,
          version: "0.1.200",
        );

        statusStream.add(
          const ConnectionStatus.connected(config: config, health: health),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        statusStream.add(
          const ConnectionStatus.reconnecting(config: config),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      expect: () => [
        isA<ConnectionDisconnected>(),
        isA<ConnectionConnected>(),
        isA<ConnectionReconnecting>(),
      ],
    );

    blocTest<ConnectionOverlayCubit, ConnectionStatus>(
      "reconnect() delegates to connectionService.reconnect()",
      build: () => ConnectionOverlayCubit(mockConnectionService, mockAuthSession),
      act: (cubit) {
        cubit.reconnect();
      },
      verify: (_) {
        verify(() => mockConnectionService.reconnect()).called(1);
      },
    );

    blocTest<ConnectionOverlayCubit, ConnectionStatus>(
      "disconnect() delegates to connectionService.disconnect()",
      build: () => ConnectionOverlayCubit(mockConnectionService, mockAuthSession),
      act: (cubit) async {
        await cubit.disconnect();
      },
      verify: (_) {
        verify(() => mockAuthSession.logoutCurrentDevice()).called(1);
        verify(() => mockConnectionService.disconnect()).called(1);
      },
    );

    blocTest<ConnectionOverlayCubit, ConnectionStatus>(
      "closes subscription when cubit is closed",
      build: () => ConnectionOverlayCubit(mockConnectionService, mockAuthSession),
      act: (cubit) async {
        await cubit.close();
      },
      verify: (_) {
        expect(statusStream.hasListener, false);
      },
    );
  });
}
