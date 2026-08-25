import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/session_diffs/session_diffs_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class _MockDeviceCanvasService() extends Mock implements DeviceCanvasService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConnectionService connectionService;
  late MockRegisteredBridgesService registeredBridgesService;
  late _MockDeviceCanvasService deviceCanvasService;
  late BehaviorSubject<ConnectionStatus> connectionStatuses;

  setUp(() async {
    await getIt.reset();
    connectionService = MockConnectionService();
    registeredBridgesService = MockRegisteredBridgesService();
    deviceCanvasService = _MockDeviceCanvasService();
    connectionStatuses = BehaviorSubject<ConnectionStatus>.seeded(
      ConnectionStatus.connected(
        config: const ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
        health: testHealthResponse(),
      ),
    );

    when(() => connectionService.status).thenAnswer((_) => connectionStatuses.stream);
    when(() => connectionService.events).thenAnswer((_) => const Stream.empty());
    when(() => deviceCanvasService.getSessionStatus(sessionId: "session-1")).thenAnswer(
      (_) async => const DeviceCanvasStatusSupported(
        status: DeviceCanvasSessionStatusResponse(
          bridgeId: "bridge-2",
          sessionId: "session-1",
          sessionAvailable: true,
          projectId: "project-1",
          connection: DeviceCanvasClientConnectionStatus.connected,
        ),
      ),
    );
    when(() => registeredBridgesService.getRegisteredBridges()).thenAnswer(
      (_) async => [
        BridgeSummary(
          id: "bridge-1",
          name: "Target Mac",
          platform: "macos",
          addedAt: DateTime.fromMillisecondsSinceEpoch(1),
          lastSeenAt: DateTime.fromMillisecondsSinceEpoch(2),
        ),
      ],
    );

    getIt.registerSingleton<ConnectionService>(connectionService);
    getIt.registerSingleton<RegisteredBridgesService>(registeredBridgesService);
    getIt.registerSingleton<DeviceCanvasService>(deviceCanvasService);
  });

  tearDown(() async {
    await getIt.reset();
    await connectionStatuses.close();
  });

  testWidgets("does not load diffs while another bridge is active", (tester) async {
    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>(
        create: (_) => StubConnectionOverlayCubit(),
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SessionDiffsScreen(
            projectId: "project-1",
            sessionId: "session-1",
            bridgeId: "bridge-1",
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text("Waiting for the expected Sesori bridge..."), findsOneWidget);
    expect(getIt.isRegistered<SessionRepository>(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
