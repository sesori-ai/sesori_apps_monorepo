import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Behaviour guards for the redesigned bridge-offline recovery view: the
// machine-name row fed from the account's registered bridges, the status line
// reporting how long that bridge has been gone, the start-the-bridge info
// popover, and the install-commands disclosure that closes the body.
//
// Pumps the real [ProjectListScreen] (its cubit is built from getIt, so every
// dependency is registered as a mock below) driven into the bridge-offline
// state through the connection status stream.
// ---------------------------------------------------------------------------

const _connectionConfig = ServerConnectionConfig(
  relayHost: "relay.example.com",
  authToken: "test-token",
);
const _health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
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
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  group("machine-name row", () {
    testWidgets("names the most recently seen registered bridge, above the status line", (tester) async {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [_bridge(id: "a", name: "Macbook-Pro.local", lastSeenAt: DateTime.utc(2026, 7, 1))],
      );

      await pumpScreen(tester);

      // Once in the body, once as the top bar's subtitle.
      expect(find.text("Macbook-Pro.local"), findsNWidgets(2));
      final bodyName = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.text("Macbook-Pro.local"),
      );
      final status = find.textContaining("Disconnected");
      expect(tester.getTopLeft(bodyName).dy, lessThan(tester.getTopLeft(status).dy));
    });

    testWidgets("is hidden when the registered bridges could not be fetched", (tester) async {
      await pumpScreen(tester);

      expect(find.byIcon(TablerRegular.device_laptop), findsNothing);
      // The recovery view itself still renders in full, and with no last-seen
      // time to report the status line falls back to the bare caption.
      expect(find.text("Disconnected"), findsOneWidget);
      expect(find.text("Install commands"), findsOneWidget);
    });

    testWidgets("is a static label: only the most recent machine, tapping does nothing", (tester) async {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [
          _bridge(id: "a", name: "Macbook-Pro.local", lastSeenAt: DateTime.utc(2026, 7, 1)),
          _bridge(id: "b", name: "work-desktop", platform: "linux"),
        ],
      );

      await pumpScreen(tester);

      // One bridge at a time: stale extra registrations are never listed.
      expect(find.text("work-desktop"), findsNothing);

      // Not tappable — no menu or sheet opens off the row.
      await tester.tap(find.text("Macbook-Pro.local").first);
      await tester.pumpAndSettle();
      expect(find.text("work-desktop"), findsNothing);
    });
  });

  testWidgets("the status line reports how long the bridge has been gone", (tester) async {
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
    expect(find.text("Disconnected · 5h ago"), findsOneWidget);
  });

  testWidgets("the start-the-bridge info icon opens its explainer popover", (tester) async {
    await pumpScreen(tester);

    // The "Make sure the Bridge is running" label owns the only info trigger
    // on this view.
    await tester.tap(find.bySemanticsLabel("More information"));
    await tester.pumpAndSettle();

    expect(
      find.text("Leave it running while you use Sesori from your phone."),
      findsOneWidget,
    );
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
