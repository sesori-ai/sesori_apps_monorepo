import "dart:async";

import "package:flutter/services.dart";
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
// End-to-end analytics guard for the Projects onboarding/recovery surfaces:
// every ProductAnalyticsEvent union case is fired through a real widget tap, and the
// surface parameter tracks which body hosted it — the connect-your-computer
// setup or the bridge-offline view. (The connected-but-empty state carries no
// onboarding widgets anymore, so it fires no onboarding events.)
//
// Pumps the real home (its cubits are built from getIt, so every
// dependency is registered as a mock below) driven into each state through
// the connection status stream + project list responses.
// ---------------------------------------------------------------------------

const _connectionConfig = ServerConnectionConfig(
  relayHost: "relay.example.com",
  authToken: "test-token",
  bridgeId: null,
);
const _health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false);
const _connectedStatus = ConnectionStatus.connected(config: _connectionConfig, health: _health);
const _bridgeOfflineStatus = ConnectionStatus.bridgeOffline(config: _connectionConfig);

void main() {
  late MockProjectRepository mockProjectRepository;
  late MockConnectionService mockConnectionService;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late MockUrlLauncher mockUrlLauncher;
  late MockProductAnalyticsService mockProductAnalyticsService;
  late StubConnectionOverlayCubit overlayCubit;
  late BehaviorSubject<ConnectionStatus> statusController;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockProjectRepository = MockProjectRepository();
    mockConnectionService = MockConnectionService();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    mockUrlLauncher = MockUrlLauncher();
    mockProductAnalyticsService = MockProductAnalyticsService();
    overlayCubit = StubConnectionOverlayCubit();
    statusController = BehaviorSubject<ConnectionStatus>.seeded(_connectedStatus);

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockConnectionService.events).thenAnswer((_) => const Stream.empty());
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
    when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => true);
    stubProductAnalyticsService(service: mockProductAnalyticsService);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel("dev.fluttercommunity.plus/share"),
      (_) async => "test-share-target",
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );

    getIt.registerLazySingleton<ProjectRepository>(() => mockProjectRepository);
    registerListServicesWithProductAnalytics(
      projectRepository: mockProjectRepository,
      productAnalyticsService: mockProductAnalyticsService,
    );
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    getIt.registerLazySingleton<SseEventTracker>(MockSseEventTracker.new);
    getIt.registerLazySingleton<RouteSource>(MockRouteSource.new);
    getIt.registerLazySingleton<SessionUnseenTracker>(FakeSessionUnseenTracker.new);
    getIt.registerLazySingleton<RegisteredBridgesService>(() => mockRegisteredBridgesService);
    getIt.registerLazySingleton<FailureReporter>(MockFailureReporter.new);
    getIt.registerLazySingleton<UrlLauncher>(() => mockUrlLauncher);
  });

  tearDown(() async {
    await overlayCubit.close();
    await statusController.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel("dev.fluttercommunity.plus/share"),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await getIt.reset();
  });

  /// Pumps the screen and settles. The tall viewport keeps every command box
  /// on-stage so taps land without scrolling; unmounting at the end of the
  /// test disposes the screen's minute ticker, which would otherwise linger
  /// as a pending timer.
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
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  /// Bridge offline with no bridge ever registered → the connect-your-computer
  /// setup onboarding.
  Future<void> pumpConnectSetup(WidgetTester tester) async {
    statusController.add(_bridgeOfflineStatus);
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => false);
    await pumpScreen(tester);
    // The body's caption under the connection graphic.
    expect(find.text("Waiting for your computer..."), findsOneWidget);
  }

  /// Opens the connect onboarding's "Prefer the terminal?" disclosure, which
  /// holds the install and start command boxes.
  Future<void> expandTerminalSteps(WidgetTester tester) async {
    await tester.tap(find.text("Prefer the terminal?"));
    await tester.pumpAndSettle();
  }

  /// Bridge offline with a bridge registered → the bridge-offline recovery
  /// view.
  Future<void> pumpBridgeOffline(WidgetTester tester) async {
    statusController.add(_bridgeOfflineStatus);
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    await pumpScreen(tester);
    expect(find.text("Bridge offline"), findsOneWidget);
  }

  void verifyLogged(ProductAnalyticsEvent event) {
    verify(
      () => mockProductAnalyticsService.logEvent(
        event: event,
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(1);
  }

  void expectCommandCopiedInfoAlert({required WidgetTester tester}) {
    final alert = tester.widget<PregoPopupAlertsNotifications>(find.byType(PregoPopupAlertsNotifications));
    expect(alert.title, "Command copied to clipboard");
    expect(alert.variant, PregoPopupAlertsNotificationsVariant.info);
  }

  group("connect-your-computer setup onboarding", () {
    testWidgets("keeps mobile CLI installation behind the terminal disclosure", (tester) async {
      await pumpConnectSetup(tester);

      // Collapsed by default: Sesori Desktop leads, the commands stay hidden.
      expect(find.text("1. Install the bridge"), findsNothing);
      expect(find.bySemanticsLabel("Copy command"), findsNothing);

      await expandTerminalSteps(tester);

      expect(find.text("Run these in a terminal on your computer:"), findsOneWidget);
      expect(find.text("1. Install the bridge"), findsOneWidget);
      expect(find.text("2. Start the bridge"), findsOneWidget);
      expect(find.bySemanticsLabel("Copy command"), findsNWidgets(2));
      // The desktop's supervised start never shows on the phone.
      expect(find.text("Start the bridge"), findsNothing);

      // Collapsing hides the commands again.
      await tester.tap(find.text("Prefer the terminal?"));
      await tester.pumpAndSettle();
      expect(find.text("1. Install the bridge"), findsNothing);
    });

    testWidgets("leads with the Sesori Desktop card, its link above the buttons", (tester) async {
      await pumpConnectSetup(tester);

      expect(find.text("Get Sesori Desktop"), findsOneWidget);
      expect(
        find.text("It runs on macOS, Windows and Linux. Sign in there and this phone connects."),
        findsOneWidget,
      );
      final linkTop = tester.getTopLeft(find.text("sesori.com/desktop")).dy;
      final sendTop = tester.getTopLeft(find.text("Send link to my computer")).dy;
      final copyTop = tester.getTopLeft(find.text("Copy link")).dy;
      final disclosureTop = tester.getTopLeft(find.text("Prefer the terminal?")).dy;
      expect(linkTop, lessThan(sendTop));
      expect(sendTop, lessThan(copyTop));
      expect(copyTop, lessThan(disclosureTop));
    });

    testWidgets("sending the desktop link shares the download URL and logs the shared event", (tester) async {
      final shareCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel("dev.fluttercommunity.plus/share"),
        (call) async {
          shareCalls.add(call);
          return "test-share-target";
        },
      );
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Send link to my computer"));
      await tester.pumpAndSettle();

      expect(shareCalls, hasLength(1));
      expect(shareCalls.single.arguments, containsPair("uri", "https://sesori.com/desktop/"));
      verifyLogged(
        const ProductAnalyticsEvent.desktopLinkShared(surface: OnboardingSurface.connectSetup),
      );
    });

    testWidgets("a dismissed desktop link share emits no shared outcome", (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel("dev.fluttercommunity.plus/share"),
        (_) async => "",
      );
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Send link to my computer"));
      await tester.pumpAndSettle();

      verifyNever(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.desktopLinkShared(surface: OnboardingSurface.connectSetup),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });

    testWidgets("copying the desktop link copies the URL, shows an info alert and logs the copied event", (
      tester,
    ) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call case MethodCall(method: "Clipboard.setData", arguments: {"text": final String text})) {
            copied.add(text);
          }
          return null;
        },
      );
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Copy link"));
      await tester.pumpAndSettle();

      expect(copied, ["https://sesori.com/desktop/"]);
      final alert = tester.widget<PregoPopupAlertsNotifications>(find.byType(PregoPopupAlertsNotifications));
      expect(alert.title, "Link copied to clipboard");
      expect(alert.variant, PregoPopupAlertsNotificationsVariant.info);
      verifyLogged(
        const ProductAnalyticsEvent.desktopLinkCopied(surface: OnboardingSurface.connectSetup),
      );
    });

    testWidgets("tapping the Need help pill logs the menu-open event", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Need help?"));
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.needHelpMenuOpened(surface: OnboardingSurface.connectSetup),
      );
      // The popup actually opened alongside the event.
      expect(find.text("Email"), findsOneWidget);
    });

    testWidgets("tapping a support channel logs the channel event and launches the link", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Need help?"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Email"));
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.supportLinkOpened(
          channel: SupportChannel.email,
          surface: OnboardingSurface.connectSetup,
        ),
      );
      final launched = verify(() => mockUrlLauncher.launch(captureAny())).captured.single as Uri;
      expect(launched.toString(), SupportLinks.email);
    });

    testWidgets("an unavailable support link emits no outcome event", (tester) async {
      when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Need help?"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Email"));
      await tester.pumpAndSettle();

      verifyNever(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.supportLinkOpened(
            channel: SupportChannel.email,
            surface: OnboardingSurface.connectSetup,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });

    testWidgets("each support channel reports its own analytics channel value", (tester) async {
      await pumpConnectSetup(tester);

      const channelByLabel = {
        "Discord": SupportChannel.discord,
        "DM on X": SupportChannel.x,
      };
      for (final entry in channelByLabel.entries) {
        await tester.tap(find.text("Need help?"));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();

        verifyLogged(
          ProductAnalyticsEvent.supportLinkOpened(
            channel: entry.value,
            surface: OnboardingSurface.connectSetup,
          ),
        );
      }
    });

    testWidgets("opening the why-bridge explainer logs its event", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Why is this needed?"));
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.whyBridgeOpened(surface: OnboardingSurface.connectSetup),
      );
      // The sheet actually opened alongside the event (button + sheet title).
      expect(find.text("Why is this needed?"), findsNWidgets(2));
    });

    // Two command rows inside the terminal disclosure: the install box (step 1)
    // first, the run box (step 2) below it — hence copy/share at index 0 vs 1.
    testWidgets("copying the default install command shows an info alert and logs curl on unix", (tester) async {
      await pumpConnectSetup(tester);
      await expandTerminalSteps(tester);

      await tester.tap(find.bySemanticsLabel("Copy command").at(0));
      await tester.pumpAndSettle();

      expectCommandCopiedInfoAlert(tester: tester);

      verifyLogged(
        const ProductAnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.curl,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.connectSetup,
        ),
      );
    });

    testWidgets("clipboard failure emits no copied outcome", (tester) async {
      await pumpConnectSetup(tester);
      await expandTerminalSteps(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == "Clipboard.setData") throw PlatformException(code: "clipboard-unavailable");
          return null;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(find.bySemanticsLabel("Copy command").at(0));
      await tester.pumpAndSettle();

      verifyNever(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.installCommandCopied(
            method: BridgeInstallMethod.curl,
            os: BridgeInstallOs.unix,
            surface: OnboardingSurface.connectSetup,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });

    testWidgets("copying after switching to the Windows group logs powershell", (tester) async {
      await pumpConnectSetup(tester);
      await expandTerminalSteps(tester);

      await tester.tap(find.text("Windows PowerShell"));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel("Copy command").at(0));
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.powershell,
          os: BridgeInstallOs.windows,
          surface: OnboardingSurface.connectSetup,
        ),
      );
    });

    testWidgets("copying a method tab logs that method under the selected group", (tester) async {
      await pumpConnectSetup(tester);
      await expandTerminalSteps(tester);

      await tester.tap(find.text("npm"));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel("Copy command").at(0));
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.npm,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.connectSetup,
        ),
      );
    });

    testWidgets("a delayed copy reports the method whose command was copied", (tester) async {
      final clipboardCompletion = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == "Clipboard.setData") await clipboardCompletion.future;
          return null;
        },
      );
      await pumpConnectSetup(tester);
      await expandTerminalSteps(tester);

      await tester.tap(find.bySemanticsLabel("Copy command").at(0));
      await tester.pump();
      await tester.tap(find.text("npm"));
      await tester.pump();
      clipboardCompletion.complete();
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.curl,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.connectSetup,
        ),
      );
      verifyNever(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.installCommandCopied(
            method: BridgeInstallMethod.npm,
            os: BridgeInstallOs.unix,
            surface: OnboardingSurface.connectSetup,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });

    testWidgets("sharing the install command logs the shared event", (tester) async {
      await pumpConnectSetup(tester);
      await expandTerminalSteps(tester);

      await tester.tap(find.bySemanticsLabel("Share command").at(0));
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.installCommandShared(
          method: BridgeInstallMethod.curl,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.connectSetup,
        ),
      );
    });

    testWidgets("an unavailable share result emits no shared outcome", (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel("dev.fluttercommunity.plus/share"),
        (_) async => "dev.fluttercommunity.plus/share/unavailable",
      );
      await pumpConnectSetup(tester);
      await expandTerminalSteps(tester);

      await tester.tap(find.bySemanticsLabel("Share command").at(0));
      await tester.pumpAndSettle();

      verifyNever(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.installCommandShared(
            method: BridgeInstallMethod.curl,
            os: BridgeInstallOs.unix,
            surface: OnboardingSurface.connectSetup,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });

    testWidgets("a dismissed share sheet emits no shared outcome", (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel("dev.fluttercommunity.plus/share"),
        (_) async => "",
      );
      await pumpConnectSetup(tester);
      await expandTerminalSteps(tester);

      await tester.tap(find.bySemanticsLabel("Share command").at(0));
      await tester.pumpAndSettle();

      verifyNever(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.installCommandShared(
            method: BridgeInstallMethod.curl,
            os: BridgeInstallOs.unix,
            surface: OnboardingSurface.connectSetup,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });

    testWidgets("copying the step-2 run command shows an info alert and logs the run event", (tester) async {
      await pumpConnectSetup(tester);
      await expandTerminalSteps(tester);

      await tester.tap(find.bySemanticsLabel("Copy command").at(1));
      await tester.pumpAndSettle();

      expectCommandCopiedInfoAlert(tester: tester);

      verifyLogged(
        const ProductAnalyticsEvent.runCommandCopied(surface: OnboardingSurface.connectSetup),
      );
    });
  });

  group("bridge-offline recovery view", () {
    testWidgets("copying the run command shows an info alert and logs the bridge-offline surface", (tester) async {
      await pumpBridgeOffline(tester);

      // The install disclosure starts collapsed, so the always-visible run box
      // owns the only on-stage copy button.
      await tester.tap(find.bySemanticsLabel("Copy command"));
      await tester.pumpAndSettle();

      expectCommandCopiedInfoAlert(tester: tester);
      verifyLogged(
        const ProductAnalyticsEvent.runCommandCopied(surface: OnboardingSurface.bridgeOffline),
      );
    });

    testWidgets("sharing the run command logs the bridge-offline surface", (tester) async {
      await pumpBridgeOffline(tester);

      await tester.tap(find.bySemanticsLabel("Share command"));
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.runCommandShared(surface: OnboardingSurface.bridgeOffline),
      );
    });

    testWidgets("copying from the expanded install disclosure logs the bridge-offline surface", (tester) async {
      await pumpBridgeOffline(tester);

      await tester.tap(find.text("Install options"));
      await tester.pumpAndSettle();

      // Expanded, the install box unfolds below the disclosure at the end of
      // the body, so it sits after the always-visible run box.
      await tester.tap(find.bySemanticsLabel("Copy command").at(1));
      await tester.pumpAndSettle();

      expectCommandCopiedInfoAlert(tester: tester);

      verifyLogged(
        const ProductAnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.curl,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.bridgeOffline,
        ),
      );
    });

    testWidgets("copying the desktop link from the install disclosure logs the bridge-offline surface", (
      tester,
    ) async {
      // No computer named, so the kind is unknown and the disclosure leads
      // with the Sesori Desktop card.
      await pumpBridgeOffline(tester);

      await tester.tap(find.text("Install options"));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text("Copy link"));
      await tester.tap(find.text("Copy link"));
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.desktopLinkCopied(surface: OnboardingSurface.bridgeOffline),
      );
    });

    testWidgets("tapping the Need help pill logs the bridge-offline surface", (tester) async {
      await pumpBridgeOffline(tester);

      await tester.tap(find.text("Need help?"));
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.needHelpMenuOpened(surface: OnboardingSurface.bridgeOffline),
      );
      // The popup actually opened alongside the event.
      expect(find.text("Email"), findsOneWidget);
    });

    testWidgets("opening the why-bridge explainer logs the bridge-offline surface", (tester) async {
      await pumpBridgeOffline(tester);

      await tester.tap(find.text("Why is this needed?"));
      await tester.pumpAndSettle();

      verifyLogged(
        const ProductAnalyticsEvent.whyBridgeOpened(surface: OnboardingSurface.bridgeOffline),
      );
      // The sheet actually opened alongside the event (button + sheet title).
      expect(find.text("Why is this needed?"), findsNWidgets(2));
    });
  });
}
