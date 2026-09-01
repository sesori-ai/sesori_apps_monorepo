import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/settings/profile_screen.dart";
import "package:sesori_mobile/features/settings/settings_screen.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// An [AuthSession] with valid local tokens but no cached [AuthUser]: the
/// state splash leaves behind when `restoreLocalSession()` finds no stored
/// user, so `SettingsCubit.account` stays null.
class _StubAuthSession() extends Mock implements AuthSession {
  final BehaviorSubject<AuthState> _authState = BehaviorSubject.seeded(const AuthState.unauthenticated());

  @override
  ValueStream<AuthState> get authStateStream => _authState.stream;

  @override
  AuthState get currentState => _authState.value;
}

class _MockNotificationRegistrationService() extends Mock implements NotificationRegistrationService;

class _MockAppearanceStore() extends Mock implements AppearanceStore;

class _MockChatInputModeStore() extends Mock implements ChatInputModeStore;

class _MockUrlLauncher() extends Mock implements UrlLauncher;

class _MockLegalRepository() extends Mock implements LegalRepository;

class _MockBridgeSettingsRepository() extends Mock implements BridgeSettingsRepository;

const _connectionConfig = ServerConnectionConfig(relayHost: "relay.example.com", authToken: null);
const _health = HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _connectionConfig, health: _health);

Widget _app({required AppearanceCubit appearance, ChatInputModeCubit? chatInputMode}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => BlocProvider<ConnectionOverlayCubit>.value(
          value: StubConnectionOverlayCubit(),
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: "/settings/profile",
        builder: (context, state) => BlocProvider<ConnectionOverlayCubit>.value(
          value: StubConnectionOverlayCubit(),
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: "/settings/harnesses",
        builder: (context, state) => const Scaffold(body: Text("harnesses-route")),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<AppearanceCubit>.value(value: appearance),
      if (chatInputMode != null)
        BlocProvider<ChatInputModeCubit>.value(value: chatInputMode)
      else
        BlocProvider<ChatInputModeCubit>(create: (_) => StubChatInputModeCubit()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// Gives the screen room to lay out every section, so rows below the fold are
/// tappable without scrolling.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late AppearanceCubit appearance;
  late _StubAuthSession authSession;
  late _MockNotificationRegistrationService notificationRegistrationService;
  late _MockUrlLauncher urlLauncher;
  late _MockLegalRepository legalRepository;
  late MockProductAnalyticsService productAnalyticsService;
  late BehaviorSubject<ProductAnalyticsState> productAnalyticsStates;
  late _MockBridgeSettingsRepository bridgeSettingsRepository;
  late MockConnectionService connectionService;
  late BehaviorSubject<ConnectionStatus> connectionStatuses;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(UrlLaunchMode.externalApp);
    registerFallbackValue(AppearanceMode.system);
    registerFallbackValue(ChatInputMode.voiceFirst);
    registerFallbackValue(LegalDocument.terms);
    registerFallbackValue(ProductAnalyticsPreference.disabled);
  });

  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: "Sesori",
      packageName: "com.sesori.app",
      version: "1.0.0",
      buildNumber: "1",
      buildSignature: "",
    );

    await GetIt.instance.reset();
    connectionStatuses = BehaviorSubject.seeded(_connected);
    connectionService = MockConnectionService();
    when(() => connectionService.currentStatus).thenAnswer((_) => connectionStatuses.value);
    when(() => connectionService.status).thenAnswer((_) => connectionStatuses.stream);
    GetIt.instance.registerSingleton<ConnectionService>(connectionService);
    GetIt.instance.registerSingleton<CatalogRescanService>(FakeCatalogRescanService());

    authSession = _StubAuthSession();
    when(authSession.logoutCurrentDevice).thenAnswer((_) async {});
    GetIt.instance.registerSingleton<AuthSession>(authSession);

    notificationRegistrationService = _MockNotificationRegistrationService();
    when(notificationRegistrationService.unregisterCurrentDevice).thenAnswer((_) async {});
    when(notificationRegistrationService.resumeRegistrationAfterFailedLogout).thenAnswer((_) async {});
    GetIt.instance.registerSingleton<NotificationRegistrationService>(notificationRegistrationService);

    productAnalyticsStates = BehaviorSubject.seeded(
      const ProductAnalyticsState(
        preference: ProductAnalyticsPreferenceKnown(
          preference: ProductAnalyticsPreference.enabled,
        ),
        synchronization: ProductAnalyticsSynchronized(),
        availability: ProductAnalyticsActive(),
      ),
    );
    productAnalyticsService = MockProductAnalyticsService();
    when(() => productAnalyticsService.state).thenAnswer((_) => productAnalyticsStates.value);
    when(() => productAnalyticsService.stateStream).thenAnswer((_) => productAnalyticsStates.stream);
    when(
      () => productAnalyticsService.setPreference(preference: any(named: "preference")),
    ).thenAnswer((_) async {});
    when(productAnalyticsService.refreshPreference).thenAnswer((_) async {});
    when(productAnalyticsService.retryPendingDisable).thenAnswer((_) async {});
    when(productAnalyticsService.prepareForLogout).thenAnswer((_) async {});
    when(productAnalyticsService.resumeAfterFailedLogout).thenAnswer((_) async {});
    GetIt.instance.registerSingleton<ProductAnalyticsService>(productAnalyticsService);

    final store = _MockAppearanceStore();
    when(() => store.write(mode: any(named: "mode"))).thenAnswer((_) async {});
    appearance = AppearanceCubit(store: store, initialMode: AppearanceMode.system);

    urlLauncher = _MockUrlLauncher();
    when(() => urlLauncher.launch(any(), mode: any(named: "mode"))).thenAnswer((_) async => true);
    GetIt.instance.registerSingleton<UrlLauncher>(urlLauncher);

    legalRepository = _MockLegalRepository();
    GetIt.instance.registerSingleton<LegalRepository>(legalRepository);

    bridgeSettingsRepository = _MockBridgeSettingsRepository();
    when(bridgeSettingsRepository.load).thenAnswer(
      (_) async => const BridgeSettingsLoadSupported(
        response: BridgeSettingsResponse(
          pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
          yolo: YoloSettingsResponse(enabled: false),
        ),
      ),
    );
    when(
      () => bridgeSettingsRepository.updatePullRequestRefresh(
        intervalSeconds: any(named: "intervalSeconds"),
      ),
    ).thenAnswer((invocation) async {
      final intervalSeconds = invocation.namedArguments[#intervalSeconds] as int;
      return PullRequestRefreshSettingsMutationCommitted(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: intervalSeconds),
      );
    });
    when(() => bridgeSettingsRepository.updateYolo(enabled: any(named: "enabled"))).thenAnswer((invocation) async {
      final enabled = invocation.namedArguments[#enabled] as bool;
      return YoloSettingsMutationCommitted(response: YoloSettingsResponse(enabled: enabled));
    });
    GetIt.instance.registerSingleton<BridgeSettingsRepository>(bridgeSettingsRepository);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await connectionStatuses.close();
    await productAnalyticsStates.close();
  });

  testWidgets("profile row stays reachable without a cached account", (tester) async {
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    // Logout lives on the profile screen, so the row navigating there must
    // not depend on cached account metadata.
    await tester.tap(find.text("Profile"));
    await tester.pumpAndSettle();

    expect(find.text("Basic Usage Analytics"), findsOneWidget);
  });

  testWidgets("Harnesses follows Notifications and navigates without changing other sections", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text("Notifications")).dy,
      lessThan(tester.getTopLeft(find.text("Harnesses")).dy),
    );
    expect(find.text("Account"), findsOneWidget);
    expect(find.text("Appearance"), findsOneWidget);
    expect(find.text("Support"), findsOneWidget);
    expect(find.text("Legal"), findsOneWidget);
    expect(find.text("Sesori"), findsOneWidget);

    await tester.tap(find.text("Harnesses"));
    await tester.pumpAndSettle();

    expect(find.text("harnesses-route"), findsOneWidget);
  });

  testWidgets("shows the bridge-committed pull request refresh interval", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    expect(find.text("Bridge"), findsOneWidget);
    expect(find.text("Pull request refresh"), findsOneWidget);
    expect(find.text("30 seconds"), findsOneWidget);
  });

  testWidgets("shows YOLO warning and toggles from the authoritative value", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    expect(find.text("YOLO mode"), findsOneWidget);
    expect(
      find.text("Automatically approves all permission requests. Use with caution."),
      findsOneWidget,
    );
    expect(tester.widget<PregoSwitch>(find.byKey(const Key("yolo_switch"))).value, isFalse);

    await tester.tap(find.byKey(const Key("yolo_switch")));
    await tester.pumpAndSettle();

    verify(() => bridgeSettingsRepository.updateYolo(enabled: true)).called(1);
    expect(tester.widget<PregoSwitch>(find.byKey(const Key("yolo_switch"))).value, isTrue);
  });

  testWidgets("YOLO disables interaction while an update is in progress", (tester) async {
    _useTallSurface(tester);
    final mutation = Completer<YoloSettingsMutationResult>();
    when(() => bridgeSettingsRepository.updateYolo(enabled: true)).thenAnswer((_) => mutation.future);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("yolo_switch")));
    await tester.pump();

    expect(find.byKey(const Key("yolo_switch")), findsNothing);
    expect(find.byType(PregoActivityIndicator), findsOneWidget);
    expect(
      tester.widget<PregoGroupedRow>(find.byKey(const Key("pull_request_refresh_interval"))).onTap,
      isNull,
    );
    await tester.tap(find.text("YOLO mode"));
    verify(() => bridgeSettingsRepository.updateYolo(enabled: true)).called(1);

    mutation.complete(
      const YoloSettingsMutationCommitted(response: YoloSettingsResponse(enabled: true)),
    );
    await tester.pumpAndSettle();
  });

  testWidgets("YOLO disables interaction while a refresh update is in progress", (tester) async {
    _useTallSurface(tester);
    final mutation = Completer<PullRequestRefreshSettingsMutationResult>();
    when(
      () => bridgeSettingsRepository.updatePullRequestRefresh(intervalSeconds: 45),
    ).thenAnswer((_) => mutation.future);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Pull request refresh"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("pull_request_refresh_input")), "45");
    await tester.tap(find.byKey(const Key("pull_request_refresh_save")));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.widget<PregoSwitch>(find.byKey(const Key("yolo_switch"))).onChanged, isNull);

    mutation.complete(
      const PullRequestRefreshSettingsMutationCommitted(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: 45),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets("old bridges show YOLO as unsupported while keeping refresh settings", (tester) async {
    _useTallSurface(tester);
    when(bridgeSettingsRepository.load).thenAnswer(
      (_) async => const BridgeSettingsLoadLegacyPartial(
        pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
      ),
    );
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    expect(find.text("Update the connected bridge to configure this setting."), findsOneWidget);
    expect(find.byKey(const Key("yolo_switch")), findsNothing);
    expect(find.text("Pull request refresh"), findsOneWidget);
    expect(find.text("30 seconds"), findsOneWidget);
  });

  testWidgets("uncertain YOLO mutation reloads and displays the authoritative value", (tester) async {
    _useTallSurface(tester);
    var loads = 0;
    when(bridgeSettingsRepository.load).thenAnswer((_) async {
      loads++;
      return BridgeSettingsLoadSupported(
        response: BridgeSettingsResponse(
          pullRequestRefresh: const PullRequestRefreshSettingsResponse(intervalSeconds: 30),
          yolo: YoloSettingsResponse(enabled: loads > 1),
        ),
      );
    });
    when(() => bridgeSettingsRepository.updateYolo(enabled: true)).thenAnswer(
      (_) async => const YoloSettingsMutationUncertain(),
    );
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("yolo_switch")));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(tester.widget<PregoSwitch>(find.byKey(const Key("yolo_switch"))).value, isTrue);
  });

  testWidgets("shows a stable offline setting before a bridge connects", (tester) async {
    _useTallSurface(tester);
    connectionStatuses.add(const ConnectionStatus.disconnected());

    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    expect(find.text("Connect to a bridge to configure this setting."), findsNWidgets(2));
    expect(find.text("Offline"), findsNWidgets(2));
    verifyNever(bridgeSettingsRepository.load);
  });

  testWidgets("saves a custom interval and displays the committed response", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Pull request refresh"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("pull_request_refresh_input")), "45");
    await tester.tap(find.byKey(const Key("pull_request_refresh_save")));
    await tester.pumpAndSettle();

    verify(
      () => bridgeSettingsRepository.updatePullRequestRefresh(intervalSeconds: 45),
    ).called(1);
    expect(find.text("45 seconds"), findsOneWidget);
  });

  testWidgets("invalid custom input stays in the sheet and dispatches nothing", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Pull request refresh"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("pull_request_refresh_input")), "15.5");
    await tester.tap(find.byKey(const Key("pull_request_refresh_save")));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key("pull_request_refresh_input")),
        matching: find.text("Enter a whole number of seconds."),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key("pull_request_refresh_input")), findsOneWidget);
    verifyNever(
      () => bridgeSettingsRepository.updatePullRequestRefresh(
        intervalSeconds: any(named: "intervalSeconds"),
      ),
    );
  });

  testWidgets("reports when an editor becomes stale before save", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Pull request refresh"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("pull_request_refresh_input")), "45");

    connectionStatuses.add(const ConnectionStatus.connectionLost(config: _connectionConfig));
    connectionStatuses.add(_connected);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("pull_request_refresh_save")));
    await tester.pumpAndSettle();

    expect(find.text("The bridge setting changed while you were editing. Try again."), findsOneWidget);
    verifyNever(
      () => bridgeSettingsRepository.updatePullRequestRefresh(
        intervalSeconds: any(named: "intervalSeconds"),
      ),
    );
  });

  testWidgets("a bridge rejection reports and enforces its authoritative bounds", (tester) async {
    _useTallSurface(tester);
    var updateCalls = 0;
    when(
      () => bridgeSettingsRepository.updatePullRequestRefresh(
        intervalSeconds: any(named: "intervalSeconds"),
      ),
    ).thenAnswer((_) async {
      updateCalls++;
      return PullRequestRefreshSettingsMutationRejected(
        bounds: PullRequestRefreshSettingsBounds(
          minimumIntervalSeconds: 20,
          maximumIntervalSeconds: 1800,
        ),
      );
    });
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Pull request refresh"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("pull_request_refresh_input")), "1900");
    await tester.tap(find.byKey(const Key("pull_request_refresh_save")));
    await tester.pumpAndSettle();

    expect(find.text("Enter a whole number from 20 to 1,800."), findsOneWidget);
    expect(updateCalls, 1);

    await tester.tap(find.text("Pull request refresh"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("pull_request_refresh_input")), "1900");
    await tester.tap(find.byKey(const Key("pull_request_refresh_save")));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key("pull_request_refresh_input")),
        matching: find.text("Enter a whole number from 20 to 1,800."),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key("pull_request_refresh_input")), findsOneWidget);
    expect(updateCalls, 1);
  });

  testWidgets("old bridges show the cadence setting as unsupported", (tester) async {
    _useTallSurface(tester);
    when(
      bridgeSettingsRepository.load,
    ).thenAnswer((_) async => const BridgeSettingsLoadUnsupported());

    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    expect(find.text("Update the connected bridge to configure this setting."), findsNWidgets(2));
    expect(find.text("Unavailable"), findsNWidgets(2));
  });

  testWidgets("a failed cadence load exposes one retry that refreshes it", (tester) async {
    _useTallSurface(tester);
    var loadCalls = 0;
    when(bridgeSettingsRepository.load).thenAnswer((_) async {
      loadCalls++;
      return loadCalls == 1
          ? BridgeSettingsLoadFailure(error: ApiError.generic())
          : const BridgeSettingsLoadSupported(
              response: BridgeSettingsResponse(
                pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
                yolo: YoloSettingsResponse(enabled: false),
              ),
            );
    });

    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("pull_request_refresh_retry")), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const Key("pull_request_refresh_retry"))).tooltip,
      "Retry pull request refresh setting",
    );

    await tester.tap(find.byKey(const Key("pull_request_refresh_retry")));
    await tester.pumpAndSettle();

    expect(find.text("30 seconds"), findsOneWidget);
    expect(loadCalls, 2);
  });

  testWidgets("tapping a theme tile switches the appearance", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Dark"));
    await tester.pumpAndSettle();

    expect(appearance.state, AppearanceMode.dark);
  });

  testWidgets("Default input appears above Appearance and persists a new selection", (tester) async {
    _useTallSurface(tester);
    final store = _MockChatInputModeStore();
    when(() => store.write(mode: any(named: "mode"))).thenAnswer((_) async {});
    final chatInputMode = ChatInputModeCubit(store: store, initialMode: ChatInputMode.voiceFirst);

    await tester.pumpWidget(_app(appearance: appearance, chatInputMode: chatInputMode));
    await tester.pumpAndSettle();

    expect(find.text("Default input"), findsOneWidget);
    expect(find.text("Voice"), findsOneWidget);
    expect(find.text("Chat input"), findsNothing);
    expect(
      tester.getTopLeft(find.text("Default input")).dy,
      lessThan(tester.getTopLeft(find.text("Appearance")).dy),
    );
    await tester.tap(find.text("Text"));
    await tester.pumpAndSettle();

    expect(chatInputMode.state, ChatInputMode.textFirst);
    verify(() => store.write(mode: ChatInputMode.textFirst)).called(1);
  });

  testWidgets("the default input choices announce as one mutually exclusive choice", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();

    // Voice-first is the app default, so it is the checked tile.
    expect(
      tester.getSemantics(find.text("Voice")),
      matchesSemantics(
        label: "Voice",
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text("Text")),
      matchesSemantics(
        label: "Text",
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  testWidgets("the default input choices grow for accessibility text", (tester) async {
    tester.view.physicalSize = const Size(402, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    expect(find.text("Voice"), findsOneWidget);
    expect(find.text("Text"), findsOneWidget);
  });

  testWidgets("the theme tiles announce as one mutually exclusive choice", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();

    // AppearanceMode.system is the seeded state, so System is the checked tile.
    expect(
      tester.getSemantics(find.text("System")),
      matchesSemantics(
        label: "System",
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text("Light")),
      matchesSemantics(
        label: "Light",
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  testWidgets("legal rows open the document in a sheet, not a browser", (tester) async {
    _useTallSurface(tester);
    when(
      () => legalRepository.getMarkdown(document: any(named: "document")),
    ).thenAnswer((_) async => ApiResponse.success("# Privacy Policy\n\nHow we handle your data."));

    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Privacy Policy"));
    await tester.pumpAndSettle();

    verify(() => legalRepository.getMarkdown(document: LegalDocument.privacy)).called(1);
    expect(find.text("How we handle your data."), findsOneWidget);
    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));
  });

  testWidgets("a failed document load offers a retry that reloads it", (tester) async {
    _useTallSurface(tester);
    var attempt = 0;
    when(() => legalRepository.getMarkdown(document: any(named: "document"))).thenAnswer((_) async {
      attempt++;
      return attempt == 1
          ? ApiResponse.error(ApiError.dartHttpClient(Exception("offline")))
          : ApiResponse.success("# Terms of Service\n\nThe agreement text.");
    });

    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Terms of Service"));
    await tester.pumpAndSettle();

    expect(find.text("Connection failed — check your network and try again."), findsOneWidget);

    await tester.tap(find.text("Retry"));
    await tester.pumpAndSettle();

    expect(find.text("The agreement text."), findsOneWidget);
  });

  testWidgets("support rows hand off to the channel's own app", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Discord"));
    await tester.pumpAndSettle();

    verify(
      () => urlLauncher.launch(
        Uri.parse(SupportLinks.discord),
        mode: UrlLaunchMode.externalApp,
      ),
    ).called(1);
  });

  testWidgets("basic usage analytics lives on Profile with concise copy", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    expect(find.text("Basic Usage Analytics"), findsNothing);

    await tester.tap(find.text("Profile"));
    await tester.pumpAndSettle();

    expect(find.text("Basic Usage Analytics"), findsOneWidget);
    expect(
      find.text("Share basic feature usage — never your code or messages."),
      findsOneWidget,
    );
    expect(find.textContaining("automatic installation events"), findsNothing);
    expect(find.textContaining("retention"), findsNothing);

    await tester.tap(find.text("Basic Usage Analytics"));
    await tester.pump();

    verify(
      () => productAnalyticsService.setPreference(preference: ProductAnalyticsPreference.disabled),
    ).called(1);
  });

  testWidgets("a failed analytics preference shows one inline retry action", (tester) async {
    _useTallSurface(tester);
    productAnalyticsStates.add(
      const ProductAnalyticsState(
        preference: ProductAnalyticsPreferenceUnknown(),
        synchronization: ProductAnalyticsSynchronizationFailed(),
        availability: ProductAnalyticsInactive(
          reason: ProductAnalyticsInactiveReason.storageFailure,
        ),
      ),
    );
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Profile"));
    await tester.pumpAndSettle();

    expect(find.text("Analytics preference failed to load."), findsOneWidget);
    expect(find.byKey(const Key("analytics_preference_retry")), findsOneWidget);
    expect(find.bySemanticsLabel("Retry preference sync"), findsOneWidget);
    expect(find.text("Refresh analytics preference"), findsNothing);

    await tester.tap(find.byKey(const Key("analytics_preference_retry")));
    await tester.pump();

    verify(productAnalyticsService.refreshPreference).called(1);
  });

  testWidgets("a known preference remains editable when synchronization fails", (tester) async {
    _useTallSurface(tester);
    productAnalyticsStates.add(
      const ProductAnalyticsState(
        preference: ProductAnalyticsPreferenceKnown(
          preference: ProductAnalyticsPreference.enabled,
        ),
        synchronization: ProductAnalyticsSynchronizationFailed(),
        availability: ProductAnalyticsInactive(
          reason: ProductAnalyticsInactiveReason.requestFailure,
        ),
      ),
    );
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Profile"));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't sync preference."), findsOneWidget);
    expect(find.byType(PregoSwitch), findsOneWidget);
    expect(find.byKey(const Key("analytics_preference_retry")), findsOneWidget);

    await tester.tap(find.byType(PregoSwitch));
    await tester.pump();

    verify(
      () => productAnalyticsService.setPreference(preference: ProductAnalyticsPreference.disabled),
    ).called(1);

    await tester.tap(find.byKey(const Key("analytics_preference_retry")));
    await tester.pump();

    verify(productAnalyticsService.refreshPreference).called(1);
  });

  testWidgets("analytics actions are blocked while logout is in progress", (tester) async {
    _useTallSurface(tester);
    final logoutPreparation = Completer<void>();
    when(productAnalyticsService.prepareForLogout).thenAnswer((_) => logoutPreparation.future);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Profile"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Log Out"));
    await tester.pump();

    expect(tester.widget<PregoSwitch>(find.byType(PregoSwitch)).onChanged, isNull);
    await tester.tap(find.text("Basic Usage Analytics"));
    await tester.pump();
    verifyNever(
      () => productAnalyticsService.setPreference(preference: any(named: "preference")),
    );

    logoutPreparation.complete();
    await tester.pumpAndSettle();
  });

  testWidgets("runtime unavailability does not add alarming session copy", (tester) async {
    _useTallSurface(tester);
    productAnalyticsStates.add(
      const ProductAnalyticsState(
        preference: ProductAnalyticsPreferenceKnown(
          preference: ProductAnalyticsPreference.enabled,
        ),
        synchronization: ProductAnalyticsSynchronized(),
        availability: ProductAnalyticsInactive(
          reason: ProductAnalyticsInactiveReason.runtimeUnavailable,
        ),
      ),
    );

    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Profile"));
    await tester.pumpAndSettle();

    expect(find.text("Basic Usage Analytics"), findsOneWidget);
    expect(find.textContaining("unavailable for this app run"), findsNothing);
  });
}
