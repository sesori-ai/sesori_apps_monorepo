import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Behaviour guards for the bridge-offline recovery view: the heading naming
// the computer with how long it has been gone; the account's other online
// computers as one-tap switches; how to start that computer's bridge, by how
// it was installed; a single info control; and the install-commands
// disclosure that closes the body.
//
// Pumps the real home (its cubits are built from getIt, so every
// dependency is registered as a mock below) driven into the bridge-offline
// state through the connection status stream.
// ---------------------------------------------------------------------------

class _MockComputerSwitchDispatcher() extends Mock implements ComputerSwitchDispatcher;

const _connectionConfig = ServerConnectionConfig(
  relayHost: "relay.example.com",
  authToken: "test-token",
  bridgeId: null,
);
const _bridgeOfflineStatus = ConnectionStatus.bridgeOffline(config: _connectionConfig);

BridgeSummary _bridge({
  required String id,
  required String name,
  BridgePlatform platform = BridgePlatform.macos,
  BridgeRegistrationStatus status = BridgeRegistrationStatus.active,
  DateTime? lastSeenAt,
  BridgeKind? kind,
}) {
  return BridgeSummary(
    id: id,
    name: name,
    hostname: name,
    platform: platform,
    status: status,
    addedAt: DateTime.utc(2026, 1, 1),
    lastSeenAt: lastSeenAt,
    kind: kind,
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
    when(() => mockConnectionService.events).thenAnswer((_) => const Stream.empty());
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
      MultiBlocProvider(
        providers: [
          BlocProvider<ConnectionOverlayCubit>.value(value: overlayCubit),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: testHome(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Why is this needed?"), findsOneWidget);
    expect(find.text("Start the bridge"), findsNothing);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  group("the computer's name", () {
    testWidgets("is in the heading and the bar's computer button", (tester) async {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [_bridge(id: "a", name: "Macbook-Pro.local", lastSeenAt: DateTime.utc(2026, 7, 1))],
      );

      await pumpScreen(tester);

      expect(find.text("Bridge offline"), findsNothing);
      expect(find.text("Macbook-Pro.local is offline"), findsOneWidget);
      expect(
        tester.widget<PregoButtonsIconGlass>(find.byKey(const Key("home-computer"))).semanticLabel,
        "Computer: Macbook-Pro.local, offline",
      );
    });
  });

  group("other computers", () {
    final bridges = [
      _bridge(id: "a", name: "Macbook-Pro.local", lastSeenAt: DateTime.utc(2026, 7, 1), kind: BridgeKind.cli),
      _bridge(id: "b", name: "work-desktop", platform: BridgePlatform.linux),
      _bridge(id: "c", name: "old-tower", status: BridgeRegistrationStatus.inactive),
    ];

    testWidgets("lists the online ones above the start command, and a tap switches", (tester) async {
      final dispatcher = _MockComputerSwitchDispatcher();
      when(
        () => dispatcher.switchTo(
          bridgeId: any(named: "bridgeId"),
          source: ComputerSwitchSource.offlineScreen,
        ),
      ).thenAnswer((_) async {});
      getIt.registerLazySingleton<ComputerSwitchDispatcher>(() => dispatcher);
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => bridges);
      mockRegisteredBridgesService.emitBridges(bridges: bridges);

      await pumpScreen(tester);

      expect(find.text("old-tower"), findsNothing);
      expect(
        tester.getTopLeft(find.text("work-desktop")).dy,
        lessThan(tester.getTopLeft(find.text("Make sure the Bridge is running")).dy),
      );

      await tester.tap(find.text("work-desktop"));
      await tester.pumpAndSettle();

      verify(() => dispatcher.switchTo(bridgeId: "b", source: ComputerSwitchSource.offlineScreen)).called(1);
    });

    testWidgets("says when none is online", (tester) async {
      final offline = [bridges.first, bridges.last];
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => offline);
      mockRegisteredBridgesService.emitBridges(bridges: offline);

      await pumpScreen(tester);

      expect(find.text("No other computers online"), findsOneWidget);
      expect(find.text("old-tower"), findsNothing);
    });

    testWidgets("push Need help? below the last control instead of under it", (tester) async {
      final crowded = [
        ...bridges,
        _bridge(id: "d", name: "studio-mac"),
        _bridge(id: "e", name: "build-box", platform: BridgePlatform.linux),
      ];
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => crowded);
      mockRegisteredBridgesService.emitBridges(bridges: crowded);

      await pumpScreen(tester);
      // A phone-sized viewport, short enough for the card to make the body
      // reach the bottom.
      tester.view.physicalSize = const Size(402, 874);
      await tester.pumpAndSettle();

      // At rest, before any scroll: the link follows the body, so it can be
      // pushed past the fold but never drawn over a control.
      expect(
        tester.getTopLeft(find.text("Need help?", skipOffstage: false)).dy,
        greaterThan(tester.getBottomLeft(find.text("Install commands")).dy),
      );
    });
  });

  group("starting the bridge", () {
    Future<void> pumpWithBridge(WidgetTester tester, {required BridgeKind? kind}) async {
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
        (_) async => [_bridge(id: "a", name: "Macbook-Pro.local", kind: kind)],
      );
      await pumpScreen(tester);
    }

    testWidgets("a command-line bridge gets the start command", (tester) async {
      await pumpWithBridge(tester, kind: BridgeKind.cli);

      expect(find.text("Make sure the Bridge is running"), findsOneWidget);
      expect(find.text("sesori-bridge"), findsOneWidget);
      expect(find.textContaining("Sesori Desktop"), findsNothing);
      expect(find.text("Terminal:"), findsNothing);
    });

    testWidgets("Sesori Desktop gets told to open the app, with no command", (tester) async {
      await pumpWithBridge(tester, kind: BridgeKind.desktop);

      // Sesori Desktop puts no sesori-bridge command on PATH.
      expect(find.text("Open Sesori Desktop on Macbook-Pro.local."), findsOneWidget);
      expect(find.text("sesori-bridge"), findsNothing);
      expect(find.text("Make sure the Bridge is running"), findsNothing);
      expect(find.text("Terminal:"), findsNothing);
      // The reinstall disclosure stays, relabelled for the app.
      expect(find.text("Reinstall Sesori Desktop"), findsOneWidget);
    });

    testWidgets("Sesori Desktop reinstalls from its download, not the CLI installers", (tester) async {
      await pumpWithBridge(tester, kind: BridgeKind.desktop);

      expect(find.text("Install commands"), findsNothing);
      await tester.tap(find.text("Reinstall Sesori Desktop"));
      await tester.pumpAndSettle();

      expect(find.text("Get Sesori Desktop"), findsOneWidget);
      expect(find.text("sesori.com/desktop"), findsOneWidget);
      expect(find.text("Send link to my computer"), findsOneWidget);
      expect(find.text("macOS, Linux, WSL"), findsNothing);
    });

    testWidgets("a command-line bridge reinstalls from the CLI installers only", (tester) async {
      await pumpWithBridge(tester, kind: BridgeKind.cli);

      expect(find.text("Reinstall Sesori Desktop"), findsNothing);
      await tester.tap(find.text("Install commands"));
      await tester.pumpAndSettle();

      expect(find.text("macOS, Linux, WSL"), findsOneWidget);
      expect(find.text("Get Sesori Desktop"), findsNothing);
    });

    testWidgets("an unknown kind offers the Sesori Desktop card above the CLI installers", (tester) async {
      await pumpWithBridge(tester, kind: null);

      await tester.tap(find.text("Install options"));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text("Get Sesori Desktop")).dy,
        lessThan(tester.getTopLeft(find.text("macOS, Linux, WSL")).dy),
      );
    });

    testWidgets("an unknown kind gets both, each labelled", (tester) async {
      await pumpWithBridge(tester, kind: null);

      expect(find.text("Make sure the Bridge is running"), findsNothing);
      final desktopY = tester.getTopLeft(find.text("Sesori Desktop: open the app.")).dy;
      final terminalY = tester.getTopLeft(find.text("Terminal:")).dy;
      final commandY = tester.getTopLeft(find.text("sesori-bridge")).dy;
      expect(desktopY, lessThan(terminalY));
      expect(terminalY, lessThan(commandY));
    });
  });

  testWidgets("the heading stands alone when the bridges could not be fetched", (tester) async {
    await pumpScreen(tester);

    expect(find.text("Bridge offline"), findsOneWidget);
    // Without a computer there is no kind either, so both ways to start it show.
    expect(find.text("Sesori Desktop: open the app."), findsOneWidget);
    expect(find.text("Terminal:"), findsOneWidget);
    expect(find.textContaining("Last seen"), findsNothing);
    expect(find.text("Install options"), findsOneWidget);
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
    final runBoxY = tester.getTopLeft(find.text("sesori-bridge")).dy;
    final whyY = tester.getTopLeft(find.text("Why is this needed?")).dy;
    final disclosureY = tester.getTopLeft(find.text("Install options")).dy;
    expect(runBoxY, lessThan(whyY));
    expect(whyY, lessThan(disclosureY));

    // Collapsed: no install command boxes on stage.
    expect(find.text("macOS, Linux, WSL"), findsNothing);

    await tester.tap(find.text("Install options"));
    await tester.pumpAndSettle();

    // Expanded: the install boxes unfold below the disclosure button. The
    // centred body shifts up as it grows, so re-measure the button.
    final expandedDisclosureY = tester.getTopLeft(find.text("Install options")).dy;
    final installBoxY = tester.getTopLeft(find.text("macOS, Linux, WSL")).dy;
    expect(installBoxY, greaterThan(expandedDisclosureY));
  });
}
