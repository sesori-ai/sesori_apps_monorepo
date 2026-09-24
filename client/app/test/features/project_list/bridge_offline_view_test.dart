import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Behaviour guards for the bridge-offline recovery view: the computer named
// once, in the bar's bridge line; the "Bridge offline" heading with how long
// the bridge has been gone; a single info control; and the install-commands
// disclosure that closes the body.
//
// Pumps the real [ProjectListScreen] (its cubit is built from getIt, so every
// dependency is registered as a mock below) driven into the bridge-offline
// state through the connection status stream.
// ---------------------------------------------------------------------------

const _connectionConfig = ServerConnectionConfig(
  relayHost: "relay.example.com",
  authToken: "test-token",
);
const _health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false);
const _bridgeOfflineStatus = ConnectionStatus.bridgeOffline(
  config: _connectionConfig,
  health: _health,
);

BridgeSummary _bridge({
  required String id,
  required String name,
  String platform = "macos",
  DateTime? lastSeenAt,
}) {
  return BridgeSummary(
    id: id,
    name: name,
    platform: platform,
    addedAt: DateTime.utc(2026, 1, 1),
    lastSeenAt: lastSeenAt,
  );
}

void main() {
  late MockProjectRepository mockProjectRepository;
  late MockConnectionService mockConnectionService;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late StubConnectionOverlayCubit overlayCubit;
  late BehaviorSubject<ConnectionStatus> statusController;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockProjectRepository = MockProjectRepository();
    mockConnectionService = MockConnectionService();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    overlayCubit = StubConnectionOverlayCubit();
    statusController = BehaviorSubject<ConnectionStatus>.seeded(_bridgeOfflineStatus);

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);

    getIt.registerLazySingleton<ProjectRepository>(() => mockProjectRepository);
    registerListServices(
      projectRepository: mockProjectRepository,
    );
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    getIt.registerLazySingleton<SseEventTracker>(MockSseEventTracker.new);
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

  /// Pumps the screen and settles. The tall viewport keeps the whole offline
  /// body on-stage so taps land without scrolling; unmounting at the end of
  /// the test disposes the screen's minute ticker, which would otherwise
  /// linger as a pending timer.
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 1500);
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
    expect(find.text("Make sure the Bridge is running"), findsOneWidget);
    expect(find.text("Start the bridge"), findsNothing);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  group("the computer's name", () {
    testWidgets("appears once, in the bridge line, above the Bridge offline heading", (tester) async {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [_bridge(id: "a", name: "Macbook-Pro.local", lastSeenAt: DateTime.utc(2026, 7, 1))],
      );

      await pumpScreen(tester);

      expect(find.text("Macbook-Pro.local"), findsOneWidget);
      expect(
        tester.getTopLeft(find.text("Macbook-Pro.local")).dy,
        lessThan(tester.getTopLeft(find.text("Bridge offline")).dy),
      );
    });

    testWidgets("only the most recent machine is named", (tester) async {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [
          _bridge(id: "a", name: "Macbook-Pro.local", lastSeenAt: DateTime.utc(2026, 7, 1)),
          _bridge(id: "b", name: "work-desktop", platform: "linux"),
        ],
      );

      await pumpScreen(tester);

      // One bridge at a time: stale extra registrations are never listed.
      expect(find.text("work-desktop"), findsNothing);
    });
  });

  testWidgets("the heading stands alone when the bridges could not be fetched", (tester) async {
    await pumpScreen(tester);

    expect(find.text("Bridge offline"), findsOneWidget);
    expect(find.textContaining("Last seen"), findsNothing);
    expect(find.text("Install commands"), findsOneWidget);
  });

  testWidgets("a quiet line reports how long the bridge has been gone", (tester) async {
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
      (_) async => [
        _bridge(
          id: "a",
          name: "Macbook-Pro.local",
          lastSeenAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ],
    );

    await pumpScreen(tester);

    // Relative wording follows the app's shared timestamp vocabulary ("5h
    // ago"), the same one the project tiles use.
    expect(find.text("Last seen 5h ago"), findsOneWidget);
  });

  testWidgets("Why is this needed? is the only info control", (tester) async {
    await pumpScreen(tester);

    expect(find.bySemanticsLabel("More information"), findsNothing);
    expect(find.text("Why is this needed?"), findsOneWidget);
  });

  testWidgets("the install-commands disclosure closes the body and expands in place", (tester) async {
    await pumpScreen(tester);

    // End-of-body ordering: run box → explainer → disclosure. No reconnect
    // button: the page reconnects on its own and on pull-to-refresh.
    expect(find.text("Reconnect"), findsNothing);
    final runBoxY = tester.getTopLeft(find.text("Make sure the Bridge is running")).dy;
    final whyY = tester.getTopLeft(find.text("Why is this needed?")).dy;
    final disclosureY = tester.getTopLeft(find.text("Install commands")).dy;
    expect(runBoxY, lessThan(whyY));
    expect(whyY, lessThan(disclosureY));

    // Collapsed: no install command boxes on stage.
    expect(find.text("macOS, Linux, WSL"), findsNothing);

    await tester.tap(find.text("Install commands"));
    await tester.pumpAndSettle();

    // Expanded: the install boxes unfold below the disclosure button. The
    // centred body shifts up as it grows, so re-measure the button.
    final expandedDisclosureY = tester.getTopLeft(find.text("Install commands")).dy;
    final installBoxY = tester.getTopLeft(find.text("macOS, Linux, WSL")).dy;
    expect(installBoxY, greaterThan(expandedDisclosureY));
  });
}
