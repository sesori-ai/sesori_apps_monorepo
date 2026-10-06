import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BridgeKindCubit", () {
    const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
    const desktopHealth = HealthResponse(
      healthy: true,
      version: "1.9.1",
      filesystemAccessDegraded: false,
      bridgeKind: BridgeKind.desktop,
    );

    late MockConnectionService connectionService;
    late BehaviorSubject<ConnectionStatus> statuses;

    setUp(() {
      connectionService = MockConnectionService();
      statuses = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
      when(() => connectionService.status).thenAnswer((_) => statuses.stream);
      when(() => connectionService.currentStatus).thenAnswer((_) => statuses.value);
    });

    tearDown(() => statuses.close());

    test("is unknown until a bridge connects", () async {
      final cubit = BridgeKindCubit(connectionService: connectionService);
      addTearDown(cubit.close);

      expect(cubit.state, isNull);
    });

    test("reports the kind the connected bridge sent, keeps it while offline, and forgets it on disconnect", () async {
      statuses.add(const ConnectionStatus.connected(config: config, health: desktopHealth));
      final cubit = BridgeKindCubit(connectionService: connectionService);
      addTearDown(cubit.close);

      expect(cubit.state, BridgeKind.desktop);

      statuses.add(const ConnectionStatus.bridgeOffline(config: config, health: desktopHealth));
      await pumpEventQueue();

      expect(cubit.state, BridgeKind.desktop);

      statuses.add(const ConnectionStatus.disconnected());
      await pumpEventQueue();

      expect(cubit.state, isNull);

      statuses.add(ConnectionStatus.connected(config: config, health: testHealthResponse()));
      await pumpEventQueue();

      expect(cubit.state, BridgeKind.cli);
    });
  });
}
