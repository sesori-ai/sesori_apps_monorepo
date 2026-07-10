import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/analytics/analytics_reporter.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/core/widgets/connection_graphic.dart";
import "package:sesori_mobile/features/project_list/add_project_dialog.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Guards the connected-but-empty Projects body: the "on" connection graphic
// with its "Connected" caption up top, and the bottom-anchored no-projects
// message with the add-project call to action that opens the Add Project
// sheet. Pumps the real [ProjectListScreen] driven into the loaded-empty
// state through getIt-registered mocks.
// ---------------------------------------------------------------------------

const _connectionConfig = ServerConnectionConfig(
  relayHost: "relay.example.com",
  authToken: "test-token",
);
const _health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
const _connectedStatus = ConnectionStatus.connected(config: _connectionConfig, health: _health);

BridgeSummary _bridge({required String name, DateTime? lastSeenAt}) {
  return BridgeSummary(
    id: "bridge-1",
    name: name,
    platform: "macos",
    addedAt: DateTime.utc(2026, 1, 1),
    lastSeenAt: lastSeenAt,
  );
}

void main() {
  late MockProjectService mockProjectService;
  late MockConnectionService mockConnectionService;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late MockAnalyticsReporter mockAnalyticsReporter;
  late StubConnectionOverlayCubit overlayCubit;
  late BehaviorSubject<ConnectionStatus> statusController;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockProjectService = MockProjectService();
    mockConnectionService = MockConnectionService();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    mockAnalyticsReporter = MockAnalyticsReporter();
    overlayCubit = StubConnectionOverlayCubit();
    statusController = BehaviorSubject<ConnectionStatus>.seeded(_connectedStatus);

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockProjectService.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(const Projects(data: [])),
    );
    // Default: the machine-identity fetch resolves empty (the fail-soft error
    // shape), hiding the machine row; tests that show it override this.
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
    when(
      () => mockAnalyticsReporter.logEvent(event: any(named: "event")),
    ).thenAnswer((_) async {});

    getIt.registerLazySingleton<ProjectService>(() => mockProjectService);
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    getIt.registerLazySingleton<SseEventRepository>(MockSseEventRepository.new);
    getIt.registerLazySingleton<RouteSource>(MockRouteSource.new);
    getIt.registerLazySingleton<SessionUnseenTracker>(FakeSessionUnseenTracker.new);
    getIt.registerLazySingleton<RegisteredBridgesService>(() => mockRegisteredBridgesService);
    getIt.registerLazySingleton<FailureReporter>(MockFailureReporter.new);
    getIt.registerLazySingleton<AnalyticsReporter>(() => mockAnalyticsReporter);
  });

  tearDown(() async {
    await overlayCubit.close();
    await statusController.close();
    await getIt.reset();
  });

  /// Pumps the screen connected with zero projects and settles. Unmounting at
  /// the end of the test disposes the screen's minute ticker, which would
  /// otherwise linger as a pending timer.
  Future<void> pumpConnectedEmpty(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>.value(
        value: overlayCubit,
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProjectListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets("shows the on-graphic, Connected caption, message and add-project CTA", (tester) async {
    await pumpConnectedEmpty(tester);

    expect(find.byType(ConnectionGraphic), findsOneWidget);
    // Text.rich caption ("Connected" + inline check icon), so match by
    // substring rather than the exact plain text.
    expect(find.textContaining("Connected"), findsOneWidget);
    expect(find.text("You don't have any projects created or opened yet."), findsOneWidget);
    expect(find.text("Add a new project to get started"), findsOneWidget);
  });

  testWidgets("hosts no Need-help pill or install commands on this surface", (tester) async {
    await pumpConnectedEmpty(tester);

    expect(find.text("Need help?"), findsNothing);
    expect(find.bySemanticsLabel("Copy command"), findsNothing);
    expect(find.text("Why is this needed?"), findsNothing);
  });

  group("machine-name row", () {
    testWidgets("names the most recently seen registered bridge under the caption", (tester) async {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [_bridge(name: "Macbook-Pro.local", lastSeenAt: DateTime.utc(2026, 7, 1))],
      );

      await pumpConnectedEmpty(tester);

      expect(find.text("Macbook-Pro.local"), findsOneWidget);
      expect(find.byIcon(TablerRegular.device_laptop), findsOneWidget);
    });

    testWidgets("is hidden when the registered bridges could not be fetched", (tester) async {
      await pumpConnectedEmpty(tester);

      expect(find.byIcon(TablerRegular.device_laptop), findsNothing);
      // The empty state itself still renders in full.
      expect(find.textContaining("Connected"), findsOneWidget);
      expect(find.text("Add a new project to get started"), findsOneWidget);
    });
  });

  testWidgets("tapping the CTA opens the Add Project sheet", (tester) async {
    when(() => mockProjectService.getFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer(
      (_) async => ApiResponse.success(const FilesystemSuggestions(data: [])),
    );
    await pumpConnectedEmpty(tester);

    await tester.tap(find.text("Add a new project to get started"));
    await tester.pumpAndSettle();

    expect(find.byType(AddProjectDialog), findsOneWidget);
    expect(find.text("Add Project"), findsOneWidget);
  });
}
