import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/core/widgets/connection_banner.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// The project list owns dedicated full-screen bridge-offline designs, so the
/// top-nav connection banner must stay suppressed there — except when a loaded
/// list is retained across an outage: a non-empty list across a bridge outage,
/// or an empty onboarding list across a terminal connection loss (which has no
/// other recovery surface). In those cases the banner is the only recovery.
void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
  const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
  const connected = ConnectionStatus.connected(config: config, health: health);
  const bridgeOffline = ConnectionStatus.bridgeOffline(config: config, health: health);
  const connectionLost = ConnectionStatus.connectionLost(config: config);

  late BehaviorSubject<ConnectionStatus> statusController;
  late MockConnectionService mockConnectionService;
  late MockProjectService mockProjectService;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late _MutableConnectionOverlayCubit overlayCubit;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    statusController = BehaviorSubject<ConnectionStatus>.seeded(connected);
    mockConnectionService = MockConnectionService();
    mockProjectService = MockProjectService();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    overlayCubit = _MutableConnectionOverlayCubit();

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);

    getIt.registerLazySingleton<ProjectService>(() => mockProjectService);
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    getIt.registerLazySingleton<SseEventRepository>(MockSseEventRepository.new);
    getIt.registerLazySingleton<RouteSource>(MockRouteSource.new);
    getIt.registerLazySingleton<SessionUnseenTracker>(FakeSessionUnseenTracker.new);
    getIt.registerLazySingleton<RegisteredBridgesService>(() => mockRegisteredBridgesService);
    getIt.registerLazySingleton<FailureReporter>(MockFailureReporter.new);
  });

  tearDown(() async {
    await overlayCubit.close();
    await statusController.close();
    await getIt.reset();
  });

  Widget app() {
    return BlocProvider<ConnectionOverlayCubit>.value(
      value: overlayCubit,
      child: MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProjectListScreen(),
      ),
    );
  }

  testWidgets("full-screen bridge-offline design suppresses the nav banner", (tester) async {
    statusController.add(bridgeOffline);
    when(() => mockProjectService.listProjects()).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );

    await tester.pumpWidget(app());
    overlayCubit.setOverlayState(const ConnectionOverlayState.bridgeOffline());
    await tester.pumpAndSettle();

    // The dedicated "turn on your bridge" view owns the messaging …
    expect(find.text("Disconnected"), findsOneWidget);
    // … and the nav banner stays out of it.
    expect(find.byType(ConnectionBanner), findsNothing);
  });

  testWidgets("a retained loaded list shows the nav banner while the bridge is offline", (tester) async {
    when(() => mockProjectService.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(Projects(data: [testProject(name: "My Project")])),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionBanner), findsNothing);

    statusController.add(bridgeOffline);
    overlayCubit.setOverlayState(const ConnectionOverlayState.bridgeOffline());
    await tester.pumpAndSettle();

    // The loaded list stays on screen and the banner carries the messaging.
    expect(find.byType(ConnectionBanner), findsOneWidget);
    expect(find.text("Bridge disconnected"), findsOneWidget);
    expect(find.text("My Project"), findsOneWidget);
  });

  testWidgets("an empty onboarding list surfaces the reconnect banner when the connection is lost", (tester) async {
    when(() => mockProjectService.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(const Projects(data: [])),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    // Connected + empty → the onboarding checklist owns the screen; no banner.
    expect(find.byType(ConnectionBanner), findsNothing);

    // The relay drops all the way to the terminal ConnectionLost. The cubit
    // keeps the list loaded-empty (bridge-offline empties would instead move to
    // the full-screen offline flow), so the reconnect banner is the only
    // recovery affordance and must appear over the onboarding checklist.
    statusController.add(connectionLost);
    overlayCubit.setOverlayState(const ConnectionOverlayState.connectionLost());
    await tester.pumpAndSettle();

    expect(find.byType(ConnectionBanner), findsOneWidget);
    expect(find.text("Connection Lost"), findsOneWidget);
    expect(find.text("Reconnect"), findsOneWidget);
  });
}

class _MutableConnectionOverlayCubit extends StubConnectionOverlayCubit {
  void setOverlayState(ConnectionOverlayState next) => emit(next);
}
