import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/session_detail/session_detail_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class _MockDeviceCanvasService() extends Mock implements DeviceCanvasService;

class _RecordingRouteDispatcher() implements RouteDispatcher {
  final List<RouteStack> replacedStacks = [];

  @override
  void replaceStack({required RouteStack stack}) => replacedStacks.add(stack);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConnectionService connectionService;
  late MockRegisteredBridgesService registeredBridgesService;
  late _MockDeviceCanvasService deviceCanvasService;
  late _RecordingRouteDispatcher routeDispatcher;
  late BehaviorSubject<ConnectionStatus> connectionStatuses;

  setUp(() async {
    await getIt.reset();
    connectionService = MockConnectionService();
    registeredBridgesService = MockRegisteredBridgesService();
    deviceCanvasService = _MockDeviceCanvasService();
    routeDispatcher = _RecordingRouteDispatcher();
    connectionStatuses = BehaviorSubject<ConnectionStatus>.seeded(
      ConnectionStatus.connected(
        config: const ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
        health: testHealthResponse(),
      ),
    );

    when(() => connectionService.status).thenAnswer((_) => connectionStatuses.stream);
    when(() => connectionService.events).thenAnswer((_) => const Stream.empty());
    when(() => registeredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
    when(() => deviceCanvasService.getSessionStatus(sessionId: "session-1")).thenAnswer(
      (_) async => const DeviceCanvasStatusSupported(
        status: DeviceCanvasSessionStatusResponse(
          bridgeId: "bridge-1",
          sessionId: "session-1",
          sessionAvailable: true,
          projectId: "project-1",
          connection: DeviceCanvasClientConnectionStatus.connected,
        ),
      ),
    );

    getIt.registerSingleton<ConnectionService>(connectionService);
    getIt.registerSingleton<RegisteredBridgesService>(registeredBridgesService);
    getIt.registerSingleton<DeviceCanvasService>(deviceCanvasService);
    getIt.registerSingleton<RouteDispatcher>(routeDispatcher);
  });

  tearDown(() async {
    await getIt.reset();
    await connectionStatuses.close();
  });

  testWidgets("normalizes a verified projectless link to the canonical project stack", (tester) async {
    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>(
        create: (_) => StubConnectionOverlayCubit(),
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DeviceCanvasSessionDetailScreen(
            sessionId: "session-1",
            readOnly: false,
            bridgeId: "bridge-1",
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(routeDispatcher.replacedStacks, hasLength(1));
    expect(
      routeDispatcher.replacedStacks.single.paths,
      [
        const AppRoute.projects().buildPath(),
        const AppRoute.sessions(projectId: "project-1", projectName: null).buildPath(),
        const AppRoute.sessionDetail(
          projectId: "project-1",
          projectName: null,
          sessionId: "session-1",
          sessionTitle: null,
          readOnly: false,
          bridgeId: "bridge-1",
        ).buildPath(),
      ],
    );
  });
}
