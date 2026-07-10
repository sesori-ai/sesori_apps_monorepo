import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/analytics/analytics_reporter.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Behaviour guards for the redesigned bridge-offline recovery view: the
// machine-name row fed from the account's registered bridges, the
// "Start your bridge" info popover, and the install-commands disclosure that
// now closes the body.
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
  late MockProjectService mockProjectService;
  late MockConnectionService mockConnectionService;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late StubConnectionOverlayCubit overlayCubit;
  late BehaviorSubject<ConnectionStatus> statusController;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockProjectService = MockProjectService();
    mockConnectionService = MockConnectionService();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    overlayCubit = StubConnectionOverlayCubit();
    statusController = BehaviorSubject<ConnectionStatus>.seeded(_bridgeOfflineStatus);

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockProjectService.listProjects()).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);

    getIt.registerLazySingleton<ProjectService>(() => mockProjectService);
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    getIt.registerLazySingleton<SseEventRepository>(MockSseEventRepository.new);
    getIt.registerLazySingleton<RouteSource>(MockRouteSource.new);
    getIt.registerLazySingleton<SessionUnseenTracker>(FakeSessionUnseenTracker.new);
    getIt.registerLazySingleton<RegisteredBridgesService>(() => mockRegisteredBridgesService);
    getIt.registerLazySingleton<FailureReporter>(MockFailureReporter.new);
    getIt.registerLazySingleton<AnalyticsReporter>(MockAnalyticsReporter.new);
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
    expect(find.text("Disconnected"), findsOneWidget);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  group("machine-name row", () {
    testWidgets("names the most recently seen registered bridge", (tester) async {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [_bridge(id: "a", name: "Macbook-Pro.local", lastSeenAt: DateTime.utc(2026, 7, 1))],
      );

      await pumpScreen(tester);

      expect(find.text("Macbook-Pro.local"), findsOneWidget);
      // A single machine is a plain label — no menu affordance.
      expect(find.bySemanticsLabel(RegExp("Show registered machines")), findsNothing);
    });

    testWidgets("is hidden when the registered bridges could not be fetched", (tester) async {
      await pumpScreen(tester);

      expect(find.byIcon(TablerRegular.device_laptop), findsNothing);
      // The recovery view itself still renders in full.
      expect(find.text("Reconnect"), findsOneWidget);
      expect(find.text("Start your bridge"), findsOneWidget);
    });

    testWidgets("with several machines, tapping the row lists them all", (tester) async {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [
          _bridge(id: "a", name: "Macbook-Pro.local", lastSeenAt: DateTime.utc(2026, 7, 1)),
          _bridge(id: "b", name: "work-desktop", platform: "linux"),
          _bridge(id: "c", name: "lab-box", platform: "freebsd"),
        ],
      );

      await pumpScreen(tester);

      // The row names the most recent machine and carries the menu affordance.
      expect(find.text("Macbook-Pro.local"), findsOneWidget);
      expect(find.text("work-desktop"), findsNothing);

      await tester.tap(find.bySemanticsLabel(RegExp("Show registered machines")));
      await tester.pumpAndSettle();

      // Menu open: every registered machine is listed with its platform —
      // known ids prettified, unknown ones (freebsd) shown raw.
      expect(find.text("Macbook-Pro.local"), findsNWidgets(2));
      expect(find.text("work-desktop"), findsOneWidget);
      expect(find.text("lab-box"), findsOneWidget);
      expect(find.text("macOS"), findsOneWidget);
      expect(find.text("Linux"), findsOneWidget);
      expect(find.text("freebsd"), findsOneWidget);

      // The selected marker sits on the machine the row names (the most
      // recently seen one), not on any other entry.
      final checkIcon = find.byIcon(Icons.check);
      expect(checkIcon, findsOneWidget);
      final markedTile = find.ancestor(of: checkIcon, matching: find.byType(InkWell)).first;
      expect(
        find.descendant(of: markedTile, matching: find.text("Macbook-Pro.local")),
        findsOneWidget,
      );
    });
  });

  testWidgets("the Start-your-bridge info icon opens its explainer popover", (tester) async {
    await pumpScreen(tester);

    // The "Start your bridge" label owns the only info trigger on this view.
    await tester.tap(find.bySemanticsLabel("More information"));
    await tester.pumpAndSettle();

    expect(
      find.text("Start the bridge\n\nLeave it running while you use Sesori from your phone."),
      findsOneWidget,
    );
  });

  testWidgets("the install-commands disclosure closes the body and expands in place", (tester) async {
    await pumpScreen(tester);

    // End-of-body ordering: Reconnect → run box → explainer → disclosure.
    final reconnectY = tester.getTopLeft(find.text("Reconnect")).dy;
    final runBoxY = tester.getTopLeft(find.text("Start your bridge")).dy;
    final whyY = tester.getTopLeft(find.text("Why is this needed?")).dy;
    final disclosureY = tester.getTopLeft(find.text("Install commands")).dy;
    expect(reconnectY, lessThan(runBoxY));
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
