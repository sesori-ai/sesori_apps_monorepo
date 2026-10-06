import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BridgeKindCubit", () {
    const desktopHealth = HealthResponse(
      healthy: true,
      version: "1.9.1",
      filesystemAccessDegraded: false,
      bridgeKind: BridgeKind.desktop,
    );

    late MockConnectionService connectionService;
    late BehaviorSubject<HealthResponse?> lastHealth;

    setUp(() {
      connectionService = MockConnectionService();
      lastHealth = BehaviorSubject<HealthResponse?>.seeded(null);
      when(() => connectionService.lastHealth).thenAnswer((_) => lastHealth.stream);
    });

    tearDown(() => lastHealth.close());

    test("is unknown until a bridge reports its health", () async {
      final cubit = BridgeKindCubit(connectionService: connectionService);
      addTearDown(cubit.close);

      expect(cubit.state, isNull);
    });

    test("starts from the cached health, e.g. when created mid-reconnect", () async {
      lastHealth.add(desktopHealth);
      final cubit = BridgeKindCubit(connectionService: connectionService);
      addTearDown(cubit.close);

      expect(cubit.state, BridgeKind.desktop);
    });

    test("follows the reported health and clears with it", () async {
      final cubit = BridgeKindCubit(connectionService: connectionService);
      addTearDown(cubit.close);

      lastHealth.add(desktopHealth);
      await pumpEventQueue();
      expect(cubit.state, BridgeKind.desktop);

      lastHealth.add(null);
      await pumpEventQueue();
      expect(cubit.state, isNull);

      lastHealth.add(testHealthResponse());
      await pumpEventQueue();
      expect(cubit.state, BridgeKind.cli);
    });
  });
}
