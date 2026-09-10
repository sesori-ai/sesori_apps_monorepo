import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/features/settings/harnesses_settings_screen.dart";
import "package:sesori_mobile/features/settings/settings_screen.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class _MockPluginManagementService() extends Mock implements PluginManagementService;

class _MockUrlLauncher() extends Mock implements UrlLauncher;

const _managed = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "future-harness",
    displayName: "Future Harness",
    state: PluginSetupState.ready,
    runtimeVersion: "9.8.7",
    actionHint: null,
  ),
  runtimeState: PluginRuntimeState.active,
  workState: PluginManagementWorkState.idle,
  idleTimeoutMins: 20,
  hasIdleTimeoutOverride: true,
  managementCapabilities: {
    PluginManagementCapability.lifecycle,
    PluginManagementCapability.setupRefresh,
    PluginManagementCapability.idleTimeout,
  },
  actionHint: null,
);

const _externalOpenCode = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "opencode",
    displayName: "OpenCode",
    state: PluginSetupState.ready,
    runtimeVersion: null,
    actionHint: "Run login if requests fail.",
  ),
  runtimeState: PluginRuntimeState.active,
  workState: PluginManagementWorkState.idle,
  idleTimeoutMins: 0,
  hasIdleTimeoutOverride: false,
  managementCapabilities: {PluginManagementCapability.setupRefresh},
  actionHint: null,
);

const _authenticationRequired = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "codex",
    displayName: "Codex",
    state: PluginSetupState.authenticationRequired,
    runtimeVersion: "0.42.0",
    actionHint: "Log in to continue.",
  ),
  runtimeState: PluginRuntimeState.blocked,
  workState: PluginManagementWorkState.idle,
  authenticationState: PluginAuthenticationState.idle,
  idleTimeoutMins: 0,
  hasIdleTimeoutOverride: false,
  managementCapabilities: {PluginManagementCapability.authentication},
  actionHint: "Log in to continue.",
);

const _response = PluginManagementResponse(
  snapshotToken: "snapshot-1",
  bridgeId: "bridge-1",
  defaultPluginId: "opencode",
  defaultIdleTimeoutMins: 10,
  plugins: [_externalOpenCode, _managed],
);

const _conflict = PluginLifecycleConflict(
  pluginId: "future-harness",
  reasons: [PluginLifecycleConflictReason.busy],
  current: _managed,
);

Widget _app({String initialLocation = "/settings/harnesses"}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: "/projects",
        builder: (_, _) => const Scaffold(body: Text("projects-route")),
      ),
      ...buildAppRoutesForTesting(rootNavigatorKey: rootNavigatorKey).map(
        (route) => route is GoRoute && route.path == AppRouteDef.settings.path
            ? GoRoute(
                path: route.path,
                routes: route.routes,
                builder: (_, _) => const Scaffold(body: Text("settings-ancestor")),
              )
            : route,
      ),
    ],
  );
  return BlocProvider<ConnectionOverlayCubit>.value(
    value: StubConnectionOverlayCubit(),
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// The app's real route table with a stand-in for whatever screen raises
/// harness settings — the new-session harness menu in production. Exercises the
/// close button's pop branch, which `_app` (mounted at the router root) cannot.
Widget _appPushedFromOpener({
  HarnessSettingsPresentation presentation = HarnessSettingsPresentation.modal,
  String openerPath = "/opener",
  bool throughSettings = false,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: openerPath,
    routes: [
      GoRoute(
        path: openerPath,
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.pushRoute(
              throughSettings ? const AppRoute.settings() : AppRoute.settingsHarnesses(presentation: presentation),
            ),
            child: const Text("open-harnesses"),
          ),
        ),
      ),
      GoRoute(
        path: "/projects",
        builder: (context, state) => const Scaffold(body: Text("projects-route")),
      ),
      ...buildAppRoutesForTesting(rootNavigatorKey: rootNavigatorKey).map(
        (route) => throughSettings && route is GoRoute && route.path == AppRouteDef.settings.path
            ? GoRoute(
                path: route.path,
                routes: route.routes,
                builder: (context, _) => Scaffold(
                  body: TextButton(
                    onPressed: () => context.pushRoute(AppRoute.settingsHarnesses(presentation: presentation)),
                    child: const Text("settings-open-harnesses"),
                  ),
                ),
              )
            : route,
      ),
    ],
  );

  return BlocProvider<ConnectionOverlayCubit>.value(
    value: StubConnectionOverlayCubit(),
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _openRow(WidgetTester tester, String key) async {
  if (find.byKey(Key(key)).evaluate().isEmpty && !key.contains("default_timeout")) {
    final pluginId = key.substring(key.lastIndexOf("_") + 1);
    await _showDetail(tester, pluginId);
  }
  final row = find.byKey(Key(key));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Finder _switchFor(String pluginId) => find.byKey(Key("harness_management_enabled_$pluginId"));

Future<void> _showDetail(WidgetTester tester, String pluginId) async {
  if (find.byType(HarnessSettingsDetailView).evaluate().isNotEmpty) {
    if (tester.widget<HarnessSettingsDetailView>(find.byType(HarnessSettingsDetailView)).pluginId == pluginId) return;
    GoRouter.of(tester.element(find.byType(HarnessSettingsDetailView))).pop();
    await tester.pumpAndSettle();
  }
  final row = find.byKey(Key("harnesses_card_$pluginId"));
  await tester.ensureVisible(row);
  await tester.tap(find.descendant(of: row, matching: find.byType(Text)).first);
  await tester.pumpAndSettle();
}

Finder _timeoutField() => find.descendant(
  of: find.byKey(const Key("harness_management_timeout_input")),
  matching: find.byType(TextFormField),
);

int? _timeoutMinutes(PluginManagementIdleTimeoutInput input) => switch (input) {
  PluginManagementIdleTimeoutInputNoTimeout() => 0,
  PluginManagementIdleTimeoutInputCustom(:final input) => switch (int.tryParse(input.trim())) {
    final minutes? when minutes > 0 => minutes,
    _ => null,
  },
};

void main() {
  late _MockPluginManagementService service;
  late BehaviorSubject<PluginManagementLoadResult> snapshots;
  late BehaviorSubject<Map<String, PluginInstallState>> installStates;
  late BehaviorSubject<Map<String, PluginAuthenticationChallenge>> authenticationChallenges;
  late StreamController<PluginAuthenticationTerminalUpdate> authenticationTerminal;
  late _MockUrlLauncher urlLauncher;
  late FakeCatalogRescanService rescan;

  setUpAll(() {
    registerFallbackValue(const PluginLifecycleCommandRequest.enable());
    registerFallbackValue(const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 10));
    registerFallbackValue(const PluginManagementIdleTimeoutInput.noTimeout());
    registerFallbackValue(const PluginAuthenticationContinuationIntent.pasted(rawInput: "redirect"));
    registerFallbackValue(_conflict);
    registerFallbackValue(PluginManagementForceAction.disable);
    registerFallbackValue(Uri.parse("https://example.com"));
    registerFallbackValue(UrlLaunchMode.externalApp);
  });

  setUp(() async {
    await GetIt.instance.reset();
    service = _MockPluginManagementService();
    urlLauncher = _MockUrlLauncher();
    rescan = FakeCatalogRescanService();
    snapshots = BehaviorSubject();
    installStates = BehaviorSubject.seeded(const {});
    authenticationChallenges = BehaviorSubject.seeded(const {});
    authenticationTerminal = StreamController.broadcast(sync: true);
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
    when(() => service.installStates).thenAnswer((_) => installStates.stream);
    when(() => service.authenticationChallenges).thenAnswer((_) => authenticationChallenges.stream);
    when(() => service.authenticationTerminal).thenAnswer((_) => authenticationTerminal.stream);
    when(() => service.refresh()).thenAnswer((_) async {});
    when(() => service.onDispose()).thenAnswer((_) async {});
    when(
      () => service.command(
        pluginId: any(named: "pluginId"),
        request: any(named: "request"),
      ),
    ).thenAnswer((_) async => const PluginManagementMutationResult.success(response: _response));
    when(
      () => service.updateIdleTimeout(request: any(named: "request")),
    ).thenAnswer((_) async => const PluginManagementMutationResult.success(response: _response));
    when(
      () => service.startAuthentication(pluginId: any(named: "pluginId")),
    ).thenAnswer(
      (_) async => PluginAuthenticationStartResult.challenge(
        challenge: PluginAuthenticationDeviceCodeChallenge(
          verificationUri: Uri.parse("https://auth.example/device"),
          userCode: "ABCD-EFGH",
        ),
      ),
    );
    when(
      () => service.submitAuthenticationRedirect(
        pluginId: any(named: "pluginId"),
        intent: any(named: "intent"),
      ),
    ).thenAnswer((_) async => const PluginAuthenticationContinuationResult.applied());
    when(
      () => service.cancelAuthentication(pluginId: any(named: "pluginId")),
    ).thenAnswer((_) async => const PluginAuthenticationCancelResult.success());
    when(
      () => urlLauncher.launch(any(), mode: any(named: "mode")),
    ).thenAnswer((_) async => true);
    when(
      () => service.planApplyAllIdleTimeout(input: any(named: "input")),
    ).thenAnswer((invocation) {
      final input = invocation.namedArguments[#input] as PluginManagementIdleTimeoutInput;
      final minutes = _timeoutMinutes(input);
      return minutes == null
          ? const PluginManagementCommandPlan.invalidInput()
          : PluginManagementCommandPlan.request(
              request: PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: minutes),
            );
    });
    when(
      () => service.planSetIdleTimeoutOverride(
        pluginId: any(named: "pluginId"),
        input: any(named: "input"),
      ),
    ).thenAnswer((invocation) {
      final pluginId = invocation.namedArguments[#pluginId] as String;
      final input = invocation.namedArguments[#input] as PluginManagementIdleTimeoutInput;
      final minutes = _timeoutMinutes(input);
      return minutes == null
          ? const PluginManagementCommandPlan.invalidInput()
          : PluginManagementCommandPlan.request(
              request: PluginIdleTimeoutUpdateRequest.setOverride(
                pluginId: pluginId,
                idleTimeoutMins: minutes,
              ),
            );
    });
    when(
      () => service.planClearIdleTimeoutOverride(pluginId: any(named: "pluginId")),
    ).thenAnswer(
      (invocation) => PluginManagementCommandPlan.request(
        request: PluginIdleTimeoutUpdateRequest.clearOverride(
          pluginId: invocation.namedArguments[#pluginId] as String,
        ),
      ),
    );
    GetIt.instance.registerSingleton<PluginManagementService>(service);
    GetIt.instance.registerSingleton<UrlLauncher>(urlLauncher);
    GetIt.instance.registerSingleton<CatalogRescanService>(rescan);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await snapshots.close();
    await installStates.close();
    await authenticationChallenges.close();
    await authenticationTerminal.close();
  });

  testWidgets("renders loading, unsupported, and initial failure treatments", (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byType(PregoActivityIndicator), findsOneWidget);
    expect(find.bySemanticsLabel("Loading harnesses"), findsOneWidget);

    snapshots.add(const PluginManagementLoadResult.unsupported());
    await tester.pumpAndSettle();
    expect(find.text("Harnesses aren't supported"), findsOneWidget);
    expect(find.text("Update the connected bridge to view and manage its harnesses."), findsOneWidget);

    snapshots.add(PluginManagementLoadResult.failure(error: ApiError.dartHttpClient(Exception("offline"))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harnesses_retry")));

    verify(() => service.refresh()).called(1);
    expect(find.byKey(const Key("harness_management_retry")), findsOneWidget);
  });

  testWidgets("authentication row is gated by capability and setup state", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired, _managed]),
        refreshError: null,
      ),
    );
    await tester.pumpAndSettle();

    await _showDetail(tester, "codex");
    expect(find.byKey(const Key("harness_authentication_codex")), findsOneWidget);
    expect(find.text("Log in"), findsOneWidget);
    expect(find.text("0.42.0"), findsOneWidget);
    expect(find.byKey(const Key("harness_authentication_future-harness")), findsNothing);

    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(
          plugins: [
            _authenticationRequired.copyWith(
              setup: _authenticationRequired.setup.copyWith(state: PluginSetupState.ready),
            ),
          ],
        ),
        refreshError: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("harness_authentication_codex")), findsNothing);
  });

  testWidgets("one authentication start disables every other harness login", (tester) async {
    _useTallSurface(tester);
    final startResult = Completer<PluginAuthenticationStartResult>();
    when(
      () => service.startAuthentication(pluginId: "codex"),
    ).thenAnswer((_) => startResult.future);
    final secondAuthentication = _authenticationRequired.copyWith(
      setup: _authenticationRequired.setup.copyWith(id: "claude", displayName: "Claude"),
    );
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired, secondAuthentication]),
        refreshError: null,
      ),
    );
    await tester.pumpAndSettle();

    await _showDetail(tester, "codex");
    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pump();

    await _showDetail(tester, "claude");
    expect(
      tester.widget<PregoGroupedRow>(find.byKey(const Key("harness_authentication_claude"))).onTap,
      isNull,
    );
    verifyNever(() => service.startAuthentication(pluginId: "claude"));
    await _showDetail(tester, "codex");

    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    startResult.complete(
      PluginAuthenticationStartResult.challenge(
        challenge: PluginAuthenticationDeviceCodeChallenge(
          verificationUri: Uri.parse("https://auth.example/device"),
          userCode: "ABCD-EFGH",
        ),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets("dismissed authentication stays gated and can be reopened", (tester) async {
    _useTallSurface(tester);
    final secondAuthentication = _authenticationRequired.copyWith(
      setup: _authenticationRequired.setup.copyWith(id: "claude", displayName: "Claude"),
    );
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired, secondAuthentication]),
        refreshError: null,
      ),
    );
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();

    await _showDetail(tester, "codex");
    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();
    expect(find.text("ABCD-EFGH"), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp("Security notice")), findsOneWidget);
    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));
    await tester.tap(find.byKey(const Key("harness_authentication_open_browser")));
    await tester.pump();
    verify(
      () => urlLauncher.launch(Uri.parse("https://auth.example/device"), mode: UrlLaunchMode.externalApp),
    ).called(1);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    verifyNever(() => service.cancelAuthentication(pluginId: any(named: "pluginId")));
    await _showDetail(tester, "claude");
    expect(
      tester.widget<PregoGroupedRow>(find.byKey(const Key("harness_authentication_claude"))).onTap,
      isNull,
    );

    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();
    expect(find.text("ABCD-EFGH"), findsOneWidget);
    verify(() => service.startAuthentication(pluginId: "codex")).called(1);
  });

  testWidgets("device-code sheet copies only the presented one-time code", (tester) async {
    _useTallSurface(tester);
    MethodCall? clipboardCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.setData") clipboardCall = call;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired]),
        refreshError: null,
      ),
    );
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
    await _showDetail(tester, "codex");
    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("harness_authentication_copy")));
    await tester.pump();

    expect(clipboardCall?.method, "Clipboard.setData");
    expect(clipboardCall?.arguments, {"text": "ABCD-EFGH"});
    expect(find.text("Code copied"), findsOneWidget);
  });

  testWidgets("browser authentication launches and submits a pasted redirect", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired]),
        refreshError: null,
      ),
    );
    authenticationChallenges.add({
      "codex": PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse("https://accounts.example/authorize"),
        expectedCallbackUri: Uri.parse("http://127.0.0.1/callback"),
      ),
    });
    await tester.pumpAndSettle();
    await _showDetail(tester, "codex");
    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();

    final redirectField = find.descendant(
      of: find.byKey(const Key("harness_authentication_redirect_input")),
      matching: find.byType(TextFormField),
    );
    expect(redirectField, findsOneWidget);
    tester.widget<PregoButtonsSolid>(find.byKey(const Key("harness_authentication_open_browser"))).onPressed!();
    await tester.pump();
    await tester.enterText(redirectField, "http://127.0.0.1/callback?code=opaque");
    await tester.ensureVisible(find.byKey(const Key("harness_authentication_submit_redirect")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harness_authentication_submit_redirect")));
    await tester.pump();

    verify(
      () => urlLauncher.launch(Uri.parse("https://accounts.example/authorize"), mode: UrlLaunchMode.externalApp),
    ).called(1);
    final captured =
        verify(
              () => service.submitAuthenticationRedirect(
                pluginId: "codex",
                intent: captureAny(named: "intent"),
              ),
            ).captured.single
            as PluginAuthenticationPastedContinuationIntent;
    expect(captured.rawInput, "http://127.0.0.1/callback?code=opaque");
  });

  testWidgets("cancel waits and terminal completion closes the authentication sheet", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired]),
        refreshError: null,
      ),
    );
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
    await _showDetail(tester, "codex");
    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("harness_authentication_cancel")));
    await tester.pump();
    verify(() => service.cancelAuthentication(pluginId: "codex")).called(1);
    expect(find.text("Cancelling…"), findsNWidgets(2));

    authenticationTerminal.add((pluginId: "codex", progress: const PluginAuthenticationProgress.cancelled()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("Log in to harness"), findsNothing);
  });

  testWidgets("terminal failure closes the authentication sheet and remains visible", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired]),
        refreshError: null,
      ),
    );
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
    await _showDetail(tester, "codex");
    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();

    authenticationTerminal.add((
      pluginId: "codex",
      progress: const PluginAuthenticationProgress.failed(message: "Authorization expired."),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Log in to harness"), findsNothing);
    expect(find.byKey(const Key("harness_authentication_error")), findsOneWidget);
    expect(find.text("Authorization expired."), findsOneWidget);
  });

  testWidgets("terminal failure before sheet attachment does not leave an empty sheet", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired]),
        refreshError: null,
      ),
    );
    await tester.pumpAndSettle();

    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await _showDetail(tester, "codex");
    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    authenticationTerminal.add((
      pluginId: "codex",
      progress: const PluginAuthenticationProgress.failed(message: "Authorization expired."),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Log in to harness"), findsNothing);
    expect(find.byKey(const Key("harness_authentication_error")), findsOneWidget);
    expect(find.text("Authorization expired."), findsOneWidget);
  });

  testWidgets("cancellation disables browser launch and uncertain cancellation enables retry", (tester) async {
    _useTallSurface(tester);
    final cancelResult = Completer<PluginAuthenticationCancelResult>();
    when(
      () => service.cancelAuthentication(pluginId: "codex"),
    ).thenAnswer((_) => cancelResult.future);
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired]),
        refreshError: null,
      ),
    );
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
    await _showDetail(tester, "codex");
    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("harness_authentication_cancel")));
    await tester.pump();
    expect(
      tester.widget<PregoButtonsSolid>(find.byKey(const Key("harness_authentication_open_browser"))).onPressed,
      isNull,
    );
    expect(
      tester.widget<PregoButtonsSolid>(find.byKey(const Key("harness_authentication_cancel"))).onPressed,
      isNull,
    );

    cancelResult.complete(
      const PluginAuthenticationCancelResult.failed(failure: PluginAuthenticationFailure.uncertain()),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PregoButtonsSolid>(find.byKey(const Key("harness_authentication_open_browser"))).onPressed,
      isNull,
    );
    expect(
      tester.widget<PregoButtonsSolid>(find.byKey(const Key("harness_authentication_cancel"))).onPressed,
      isNotNull,
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text("Log in to harness"), findsNothing);

    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();
    expect(find.text("ABCD-EFGH"), findsOneWidget);
    verify(() => service.startAuthentication(pluginId: "codex")).called(1);
  });

  testWidgets("dismissing during cancellation preserves terminal settlement", (tester) async {
    _useTallSurface(tester);
    final cancelResult = Completer<PluginAuthenticationCancelResult>();
    when(
      () => service.cancelAuthentication(pluginId: "codex"),
    ).thenAnswer((_) => cancelResult.future);
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired]),
        refreshError: null,
      ),
    );
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
    await _showDetail(tester, "codex");
    await _showDetail(tester, "codex");
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harness_authentication_cancel")));
    await tester.pump();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    authenticationTerminal.add((
      pluginId: "codex",
      progress: const PluginAuthenticationProgress.failed(message: "Cancellation failed."),
    ));
    cancelResult.complete(const PluginAuthenticationCancelResult.success());
    await tester.pumpAndSettle();

    expect(find.text("Log in to harness"), findsNothing);
    expect(find.byKey(const Key("harness_authentication_error")), findsOneWidget);
    expect(find.text("Cancellation failed."), findsOneWidget);
  });

  testWidgets("setup-not-ready shows setup guidance and only meaningful eligibility controls", (tester) async {
    _useTallSurface(tester);
    final plugin = _managed.copyWith(
      setup: _managed.setup.copyWith(
        state: PluginSetupState.runtimeMissing,
        actionHint: "Install the harness runtime.",
      ),
      runtimeState: PluginRuntimeState.blocked,
      workState: PluginManagementWorkState.busy,
    );
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(defaultPluginId: plugin.setup.id, plugins: [plugin]),
        refreshError: null,
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _showDetail(tester, "future-harness");

    expect(find.text("Not installed"), findsOneWidget);
    expect(find.text("Install the harness runtime."), findsOneWidget);
    expect(find.byKey(const Key("harness_management_enabled_future-harness")), findsOneWidget);
    expect(tester.widget<PregoSwitch>(_switchFor("future-harness")).value, isTrue);
    expect(find.byKey(const Key("harness_management_refresh_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_restart_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_timeout_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_default_timeout")), findsNothing);
    expect(find.text("Runtime"), findsNothing);
    expect(find.text("Work"), findsNothing);
    expect(find.text("Blocked"), findsNothing);
    expect(find.text("Busy"), findsNothing);
    expect(find.text("20 min"), findsNothing);

    await tester.tap(_switchFor("future-harness"));
    await tester.pump();
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      ),
    ).called(1);
  });

  testWidgets("overview opens install guidance before a missing runtime can be installed", (tester) async {
    _useTallSurface(tester);
    const guidance = "Review runtime terms at https://example.test/terms and docs at https://example.test/docs.";
    final plugin = _managed.copyWith(
      setup: _managed.setup.copyWith(state: PluginSetupState.runtimeMissing, actionHint: guidance),
      runtimeState: PluginRuntimeState.blocked,
      managementCapabilities: {..._managed.managementCapabilities, PluginManagementCapability.install},
    );
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [plugin]),
        refreshError: null,
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final installRow = find.byKey(const Key("harness_management_install_future-harness"));
    expect(installRow, findsOneWidget);
    expect(find.byType(HarnessSettingsDetailView), findsNothing);

    await _openRow(tester, "harness_management_install_future-harness");
    expect(find.byType(HarnessSettingsDetailView), findsOneWidget);
    expect(find.text(guidance), findsOneWidget);
    verifyNever(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.install(),
      ),
    );

    await _openRow(tester, "harness_management_install_future-harness");
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.install(),
      ),
    ).called(1);

    // The service marks the install in flight from the tap; the streamed
    // phases are what the user sees. Two pumps: one delivers the stream event
    // to the cubit, the next rebuilds with it. The progress row animates
    // continuously, so never settle here.
    installStates.add(const {
      "future-harness": PluginInstallState.inProgress(
        progress: PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 42),
      ),
    });
    await tester.pump();
    await tester.pump();
    expect(find.text("Downloading… 42%"), findsOneWidget);

    installStates.add(const {
      "future-harness": PluginInstallState.inProgress(
        progress: PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null),
      ),
    });
    await tester.pump();
    await tester.pump();
    expect(find.text("Extracting…"), findsOneWidget);

    // A second tap while installing must not send another command.
    expect(find.byKey(const Key("harness_management_install_future-harness")), findsNothing);
    await tester.pump();
    verifyNever(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.install(),
      ),
    );

    // A phase only a newer bridge names still reads as work in progress.
    installStates.add(const {
      "future-harness": PluginInstallState.inProgress(
        progress: PluginInstallProgress(phase: PluginInstallPhase.unknown, percent: null),
      ),
    });
    await tester.pump();
    await tester.pump();
    expect(find.text("Installing…"), findsOneWidget);
  });

  testWidgets("direct detail keeps invalid-runtime guidance visible before install", (tester) async {
    _useTallSurface(tester);
    const guidance = "The local pair is invalid. Review https://example.test/terms and https://example.test/docs.";
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(
          plugins: [
            _managed.copyWith(
              setup: _managed.setup.copyWith(state: PluginSetupState.unavailable, actionHint: guidance),
              runtimeState: PluginRuntimeState.blocked,
              managementCapabilities: {..._managed.managementCapabilities, PluginManagementCapability.install},
            ),
          ],
        ),
        refreshError: null,
      ),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _showDetail(tester, "future-harness");
    expect(find.text(guidance), findsOneWidget);
    verifyNever(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.install(),
      ),
    );
    await _openRow(tester, "harness_management_install_future-harness");
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.install(),
      ),
    ).called(1);
  });

  testWidgets("install is hidden without the capability and when the runtime is ready", (tester) async {
    _useTallSurface(tester);
    final installable = _managed.copyWith(
      setup: _managed.setup.copyWith(state: PluginSetupState.runtimeMissing, actionHint: null),
      runtimeState: PluginRuntimeState.blocked,
    );
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [installable]),
        refreshError: null,
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("harness_management_install_future-harness")), findsNothing);

    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(
          plugins: [
            _managed.copyWith(
              managementCapabilities: {..._managed.managementCapabilities, PluginManagementCapability.install},
            ),
          ],
        ),
        refreshError: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("harness_management_install_future-harness")), findsNothing);
  });

  testWidgets("setup-ready disabled shows enable and setup refresh without operational facts", (tester) async {
    _useTallSurface(tester);
    final plugin = _managed.copyWith(runtimeState: PluginRuntimeState.disabled);
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [plugin]),
        refreshError: null,
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _showDetail(tester, "future-harness");

    expect(find.text("Disabled"), findsOneWidget);
    expect(find.byKey(const Key("harness_management_enabled_future-harness")), findsOneWidget);
    expect(tester.widget<PregoSwitch>(_switchFor("future-harness")).value, isFalse);
    expect(find.byKey(const Key("harness_management_refresh_future-harness")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_restart_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_timeout_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_default_timeout")), findsNothing);
    expect(find.text("Runtime"), findsNothing);
    expect(find.text("Work"), findsNothing);
    expect(find.text("Idle"), findsNothing);
    expect(find.text("Version"), findsOneWidget);
    expect(find.text("9.8.7"), findsOneWidget);

    await tester.tap(_switchFor("future-harness"));
    await tester.pump();
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.enable(),
      ),
    ).called(1);
  });

  testWidgets("overview opens known detail facts without a default badge", (tester) async {
    _useTallSurface(tester);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(findBrandLogo("opencode"), findsOneWidget);
    expect(find.text("Default"), findsNothing);
    expect(find.text("9.8.7"), findsNothing);
    expect(find.byKey(const Key("harness_management_default_timeout")), findsOneWidget);
    await _showDetail(tester, "future-harness");
    expect(find.text("Version"), findsOneWidget);
    expect(find.text("9.8.7"), findsOneWidget);
    expect(find.text("Running"), findsNothing);
    expect(find.text("Idle"), findsNWidgets(2));
    expect(find.byKey(const Key("harness_management_restart_future-harness")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_timeout_future-harness")), findsOneWidget);
    expect(find.text("20 min"), findsOneWidget);
  });

  testWidgets("capability-limited and external presentation is capability-driven", (tester) async {
    _useTallSurface(tester);
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(defaultPluginId: "opencode", plugins: [_externalOpenCode]),
        refreshError: null,
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _showDetail(tester, "opencode");

    expect(find.byKey(const Key("harness_management_external_opencode")), findsOneWidget);
    expect(find.text("Managed outside Sesori"), findsOneWidget);
    expect(find.byKey(const Key("harness_management_refresh_opencode")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_enabled_opencode")), findsNothing);
    expect(find.byKey(const Key("harness_management_restart_opencode")), findsNothing);
    expect(find.byKey(const Key("harness_management_timeout_opencode")), findsNothing);
    expect(find.byKey(const Key("harness_management_default_timeout")), findsNothing);
    expect(find.text("Running"), findsNothing);
    expect(find.text("Idle"), findsNWidgets(2));
    expect(find.text("Version"), findsNothing);

    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(
          defaultPluginId: "future-harness",
          plugins: [
            _managed.copyWith(managementCapabilities: {PluginManagementCapability.unknown}),
          ],
        ),
        refreshError: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("harness_management_external_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_enabled_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_refresh_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_restart_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_timeout_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_default_timeout")), findsNothing);
  });

  testWidgets("unknown runtime or work never implies disabled or Running", (tester) async {
    _useTallSurface(tester);
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(
          defaultPluginId: "future-harness",
          plugins: [
            _managed.copyWith(
              runtimeState: PluginRuntimeState.unknown,
              workState: PluginManagementWorkState.unknown,
            ),
          ],
        ),
        refreshError: null,
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _showDetail(tester, "future-harness");

    expect(find.text("Unknown"), findsOneWidget);
    expect(find.text("Runtime"), findsNothing);
    expect(find.text("Work"), findsNothing);
    expect(find.byKey(const Key("harness_management_enabled_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_restart_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_timeout_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_default_timeout")), findsNothing);
    expect(find.byKey(const Key("harness_management_refresh_future-harness")), findsOneWidget);

    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(
          defaultPluginId: "future-harness",
          plugins: [_managed.copyWith(workState: PluginManagementWorkState.unknown)],
        ),
        refreshError: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Running"), findsNothing);
    expect(find.text("Work"), findsNothing);
    expect(find.text("Unknown"), findsOneWidget);
  });

  testWidgets("supported response with no harnesses shows the empty state", (tester) async {
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: []),
        refreshError: null,
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text("No harnesses registered"), findsOneWidget);
    expect(find.text("The connected bridge hasn't registered any coding harnesses."), findsOneWidget);
    expect(find.byKey(const Key("harness_management_default_timeout")), findsNothing);
  });

  testWidgets("retained refresh and action errors keep the snapshot visible and dismiss independently", (tester) async {
    _useTallSurface(tester);
    when(
      () => service.command(
        pluginId: "opencode",
        request: const PluginLifecycleCommandRequest.refresh(),
      ),
    ).thenAnswer((_) async => const PluginManagementMutationResult.notFound());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_externalOpenCode]),
        refreshError: ApiError.dartHttpClient(Exception("offline")),
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("harnesses_refresh_error")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_refresh_error")), findsOneWidget);
    expect(find.text("OpenCode"), findsOneWidget);

    await tester.tap(find.byTooltip("Dismiss refresh error"));
    await tester.pump();
    expect(find.byKey(const Key("harnesses_refresh_error")), findsNothing);
    expect(find.text("OpenCode"), findsOneWidget);

    await _showDetail(tester, "opencode");
    await tester.tap(find.byKey(const Key("harness_management_refresh_opencode")));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("harness_management_action_error_opencode")), findsOneWidget);
    expect(find.text("The harness is no longer registered on this bridge."), findsOneWidget);

    await tester.tap(find.byTooltip("Dismiss action error"));
    await tester.pump();
    expect(find.byKey(const Key("harness_management_action_error_opencode")), findsNothing);
    expect(find.text("OpenCode"), findsNWidgets(2));
  });

  testWidgets("safe setup refresh and restart actions dispatch once", (tester) async {
    _useTallSurface(tester);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _showDetail(tester, "opencode");
    await tester.tap(find.byKey(const Key("harness_management_refresh_opencode")));
    await tester.pump();
    verify(
      () => service.command(
        pluginId: "opencode",
        request: const PluginLifecycleCommandRequest.refresh(),
      ),
    ).called(1);

    await _openRow(tester, "harness_management_restart_future-harness");
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      ),
    ).called(1);
  });

  testWidgets("an in-progress action blocks only its own harness controls", (tester) async {
    _useTallSurface(tester);
    final commandCompleter = Completer<PluginManagementMutationResult>();
    when(
      () => service.command(
        pluginId: "opencode",
        request: const PluginLifecycleCommandRequest.refresh(),
      ),
    ).thenAnswer((_) => commandCompleter.future);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _showDetail(tester, "opencode");
    await tester.tap(find.byKey(const Key("harness_management_refresh_opencode")));
    await tester.pump();

    expect(tester.widget<PregoGroupedRow>(find.byKey(const Key("harness_management_refresh_opencode"))).onTap, isNull);
    await _showDetail(tester, "future-harness");
    final restart = find.byKey(const Key("harness_management_restart_future-harness"));
    expect(tester.widget<PregoGroupedRow>(restart).onTap, isNotNull);
    expect(tester.widget<PregoSwitch>(_switchFor("future-harness")).onChanged, isNotNull);
    await tester.tap(restart);
    await tester.pump();
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      ),
    ).called(1);

    commandCompleter.complete(const PluginManagementMutationResult.success(response: _response));
    await tester.pumpAndSettle();
  });

  testWidgets("global timeout maps no-timeout and positive custom choices to typed inputs", (tester) async {
    _useTallSurface(tester);
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(defaultPluginId: "future-harness", plugins: [_managed]),
        refreshError: null,
      ),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _openRow(tester, "harness_management_default_timeout");
    expect(find.byType(PregoBottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(PregoInputField), findsOneWidget);
    expect(find.byType(PregoButtonsSolid), findsNWidgets(2));
    expect(
      find.descendant(of: find.byType(PregoBottomSheet), matching: find.byType(TextButton)),
      findsNothing,
    );
    expect(_timeoutField(), findsOneWidget);
    expect(tester.widget<TextFormField>(_timeoutField()).controller?.text, "10");

    await tester.enterText(_timeoutField(), "25");
    await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
    await tester.pumpAndSettle();

    final customInput =
        verify(
              () => service.planApplyAllIdleTimeout(input: captureAny(named: "input")),
            ).captured.single
            as PluginManagementIdleTimeoutInputCustom;
    expect(customInput.input, "25");
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 25),
      ),
    ).called(1);

    await _openRow(tester, "harness_management_default_timeout");
    await tester.tap(find.byKey(const Key("harness_management_timeout_no_timeout")));
    await tester.pump();
    expect(find.byType(PregoInputField), findsNothing);
    await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
    await tester.pumpAndSettle();

    final inputs = verify(
      () => service.planApplyAllIdleTimeout(input: captureAny(named: "input")),
    ).captured;
    expect(inputs, hasLength(1));
    expect(inputs.single, isA<PluginManagementIdleTimeoutInputNoTimeout>());
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 0),
      ),
    ).called(1);
  });

  testWidgets("zero global timeout opens with No timeout selected", (tester) async {
    _useTallSurface(tester);
    final plugin = _managed.copyWith(idleTimeoutMins: 0);
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(
          defaultPluginId: "future-harness",
          defaultIdleTimeoutMins: 0,
          plugins: [plugin],
        ),
        refreshError: null,
      ),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text("No timeout"), findsOneWidget);
    expect(find.text("0 min"), findsNothing);

    await _openRow(tester, "harness_management_default_timeout");
    expect(find.byType(PregoInputField), findsNothing);
    await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
    await tester.pumpAndSettle();

    final input = verify(
      () => service.planApplyAllIdleTimeout(input: captureAny(named: "input")),
    ).captured.single;
    expect(input, isA<PluginManagementIdleTimeoutInputNoTimeout>());
  });

  testWidgets("per-harness timeout supports custom, no-timeout, inheritance, and clear override", (tester) async {
    _useTallSurface(tester);
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(defaultPluginId: "future-harness", plugins: [_managed]),
        refreshError: null,
      ),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _openRow(tester, "harness_management_timeout_future-harness");
    expect(_timeoutField(), findsOneWidget);
    expect(tester.widget<TextFormField>(_timeoutField()).controller?.text, "20");
    await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
    await tester.pumpAndSettle();
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.setOverride(
          pluginId: "future-harness",
          idleTimeoutMins: 20,
        ),
      ),
    ).called(1);

    await _openRow(tester, "harness_management_timeout_future-harness");
    await tester.tap(find.byKey(const Key("harness_management_timeout_no_timeout")));
    await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
    await tester.pumpAndSettle();
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.setOverride(
          pluginId: "future-harness",
          idleTimeoutMins: 0,
        ),
      ),
    ).called(1);

    await _openRow(tester, "harness_management_timeout_future-harness");
    await tester.tap(find.byKey(const Key("harness_management_timeout_use_default")));
    await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
    await tester.pumpAndSettle();
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "future-harness"),
      ),
    ).called(1);

    await _openRow(tester, "harness_management_timeout_future-harness");
    await tester.tap(find.byKey(const Key("harness_management_timeout_use_default")));
    await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
    await tester.pumpAndSettle();
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "future-harness"),
      ),
    ).called(1);
  });

  testWidgets("inherited per-harness timeout opens with Use bridge default selected", (tester) async {
    _useTallSurface(tester);
    final plugin = _managed.copyWith(idleTimeoutMins: 10, hasIdleTimeoutOverride: false);
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(defaultPluginId: "future-harness", plugins: [plugin]),
        refreshError: null,
      ),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _openRow(tester, "harness_management_timeout_future-harness");
    expect(find.byType(PregoInputField), findsNothing);
    await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
    await tester.pumpAndSettle();

    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "future-harness"),
      ),
    ).called(1);
    verifyNever(
      () => service.planSetIdleTimeoutOverride(
        pluginId: any(named: "pluginId"),
        input: any(named: "input"),
      ),
    );
  });

  testWidgets("custom timeout rejects non-numeric, zero, and negative values locally", (tester) async {
    _useTallSurface(tester);
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(
          defaultPluginId: "future-harness",
          defaultIdleTimeoutMins: 0,
          plugins: [_managed],
        ),
        refreshError: null,
      ),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _openRow(tester, "harness_management_default_timeout");
    await tester.tap(find.byKey(const Key("harness_management_timeout_custom")));
    await tester.pump();

    for (final invalid in ["invalid", "0", "-5"]) {
      await tester.enterText(_timeoutField(), invalid);
      await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
      await tester.pump();
      expect(find.text("Enter a whole number greater than zero."), findsOneWidget);
      expect(find.byType(PregoBottomSheet), findsOneWidget);
    }

    verifyNever(() => service.planApplyAllIdleTimeout(input: any(named: "input")));
    verifyNever(() => service.updateIdleTimeout(request: any(named: "request")));

    await tester.tap(find.byKey(const Key("harness_management_timeout_cancel")));
    await tester.pumpAndSettle();
    expect(find.byType(PregoBottomSheet), findsNothing);
  });

  testWidgets("safe restart opens named confirmation before one explicit force restart", (tester) async {
    when(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      ),
    ).thenAnswer((_) async => const PluginManagementMutationResult.conflict(conflict: _conflict));
    when(
      () => service.assessForce(
        conflict: any(named: "conflict"),
        action: any(named: "action"),
      ),
    ).thenReturn(
      const PluginManagementForceAssessment.requiresConfirmation(
        request: PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
      ),
    );
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openRow(tester, "harness_management_restart_future-harness");
    expect(
      find.descendant(of: find.byType(PregoBottomSheet), matching: find.text("Restart Future Harness?")),
      findsOneWidget,
    );
    expect(find.text("Force restart"), findsOneWidget);
    verifyNever(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
      ),
    );
    final confirm = find.byKey(const Key("harness_management_force_confirm"));
    final cancel = find.byKey(const Key("harness_management_force_cancel"));
    expect(tester.getTopLeft(confirm).dy, lessThan(tester.getTopLeft(cancel).dy));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
      ),
    ).called(1);
  });

  testWidgets("force cancel and close send zero force requests, then confirm sends exactly one", (tester) async {
    _useTallSurface(tester);
    var safeCalls = 0;
    when(
      () => service.command(
        pluginId: "future-harness",
        request: any(named: "request"),
      ),
    ).thenAnswer((invocation) async {
      final request = invocation.namedArguments[#request] as PluginLifecycleCommandRequest;
      if (request == const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe)) {
        safeCalls++;
        return const PluginManagementMutationResult.conflict(conflict: _conflict);
      }
      return const PluginManagementMutationResult.success(response: _response);
    });
    when(
      () => service.assessForce(
        conflict: any(named: "conflict"),
        action: any(named: "action"),
      ),
    ).thenReturn(
      const PluginManagementForceAssessment.requiresConfirmation(
        request: PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
    );
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(defaultPluginId: "future-harness", plugins: [_managed]),
        refreshError: null,
      ),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(_switchFor("future-harness"));
    await tester.pumpAndSettle();
    expect(find.byType(PregoBottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.widget<PregoButtonsSolid>(find.byKey(const Key("harness_management_force_confirm"))).type,
      PregoButtonsSolidType.destructive,
    );

    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(defaultPluginId: "future-harness", plugins: [_managed]),
        refreshError: ApiError.dartHttpClient(Exception("offline")),
      ),
    );
    await tester.pump();
    expect(find.byType(PregoBottomSheet), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.byType(PregoBottomSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key("harness_management_force_cancel")));
    await tester.pumpAndSettle();
    expect(safeCalls, 1);
    expect(find.byKey(const Key("harnesses_refresh_error")), findsOneWidget);
    verifyNever(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
    );

    await tester.tap(_switchFor("future-harness"));
    await tester.pumpAndSettle();
    final sheetClose = find.descendant(
      of: find.byType(PregoBottomSheet),
      matching: find.byType(PregoButtonsIconGlass),
    );
    expect(sheetClose, findsOneWidget);
    await tester.tap(sheetClose);
    await tester.pumpAndSettle();
    expect(safeCalls, 2);
    verifyNever(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
    );

    await tester.tap(_switchFor("future-harness"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harness_management_force_confirm")));
    await tester.pumpAndSettle();

    expect(safeCalls, 3);
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
    ).called(1);
  });

  testWidgets("pull refresh delegates to the cubit and direct modal X returns to Projects", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Dispatched on release, and the release must not be a fling: the control
    // waits for the overscroll to spring back to the extent it holds itself.
    final gesture = await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();
    await gesture.moveBy(Offset.zero);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    verify(() => service.refresh()).called(1);

    await tester.tap(find.bySemanticsLabel("Close settings"));
    await tester.pumpAndSettle();
    expect(find.text("projects-route"), findsOneWidget);
  });

  testWidgets("pushed over another screen, close returns to the opener without stacking Settings", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_appPushedFromOpener());
    await tester.pumpAndSettle();

    await tester.tap(find.text("open-harnesses"));
    await tester.pumpAndSettle();

    expect(find.byType(HarnessesSettingsScreen), findsOneWidget);
    // The harness-only shell never synthesizes an unrelated Settings page.
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.tap(find.bySemanticsLabel("Close settings"));
    await tester.pumpAndSettle();

    expect(find.byType(HarnessesSettingsScreen), findsNothing);
    expect(find.text("open-harnesses"), findsOneWidget);
    expect(find.text("projects-route"), findsNothing);
  });

  for (final openerPath in ["/projects", "/projects/p/sessions/s", "/projects/p/sessions/new"]) {
    testWidgets("pushed Back preserves Settings and its original $openerPath opener", (tester) async {
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await tester.pumpWidget(
        _appPushedFromOpener(
          openerPath: openerPath,
          throughSettings: true,
          presentation: HarnessSettingsPresentation.pushed,
        ),
      );
      await tester.pumpAndSettle();
      final opener = tester.element(find.text("open-harnesses"));
      await tester.tap(find.text("open-harnesses"));
      await tester.pumpAndSettle();
      final settings = tester.element(find.text("settings-open-harnesses"));
      await tester.tap(find.text("settings-open-harnesses"));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel("Close settings"), findsNothing);
      final cubit = tester.element(find.byType(HarnessesSettingsView)).read<PluginManagementCubit>();
      await _showDetail(tester, "future-harness");
      expect(find.bySemanticsLabel("Close settings"), findsNothing);
      await tester.tap(find.bySemanticsLabel("Back"));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(HarnessesSettingsView)).read<PluginManagementCubit>(), same(cubit));
      await tester.tap(find.bySemanticsLabel("Back"));
      await tester.pumpAndSettle();
      expect(tester.element(find.text("settings-open-harnesses")), same(settings));
      // Stream cancellation completes outside the widget-test clock.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(cubit.isClosed, isTrue);
      expect(snapshots.hasListener, isFalse);
      expect(authenticationTerminal.hasListener, isFalse);
      GoRouter.of(settings).pop();
      await tester.pumpAndSettle();
      expect(tester.element(find.text("open-harnesses")), same(opener));
      expect(find.byType(HarnessesSettingsView), findsNothing);
    });
  }

  testWidgets("closing the flow also removes its authentication sheet without cancelling the operation", (
    tester,
  ) async {
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired]),
        refreshError: null,
      ),
    );
    await tester.pumpWidget(_appPushedFromOpener());
    await tester.pumpAndSettle();
    await tester.tap(find.text("open-harnesses"));
    await tester.pumpAndSettle();
    await _showDetail(tester, "codex");
    final detail = tester.widget<HarnessSettingsDetailView>(find.byType(HarnessSettingsDetailView));
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pump();
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();
    expect(find.byType(PregoBottomSheet), findsOneWidget);
    detail.onClose();
    await tester.pumpAndSettle();
    expect(find.byType(PregoBottomSheet), findsNothing);
    expect(find.text("open-harnesses"), findsOneWidget);
    verifyNever(() => service.cancelAuthentication(pluginId: any(named: "pluginId")));
  });

  testWidgets("direct pushed detail constructs only overview ancestry and Back falls back to Projects", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app(initialLocation: "/settings/harnesses/future-harness?presentation=pushed"));
    await tester.pumpAndSettle();
    expect(find.byType(HarnessSettingsDetailView), findsOneWidget);
    expect(find.byType(HarnessesSettingsView, skipOffstage: false), findsOneWidget);
    await tester.tap(find.bySemanticsLabel("Back"));
    await tester.pumpAndSettle();
    expect(find.byType(HarnessesSettingsView), findsOneWidget);
    expect(find.text("settings-ancestor", skipOffstage: false), findsNothing);
    await tester.tap(find.bySemanticsLabel("Back"));
    await tester.pumpAndSettle();
    expect(find.text("projects-route"), findsOneWidget);
  });

  testWidgets("production harness shell retains one cubit across detail Back and closes to the opener", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_appPushedFromOpener());
    await tester.pumpAndSettle();
    await tester.tap(find.text("open-harnesses"));
    await tester.pumpAndSettle();
    final overview = tester.element(find.byType(HarnessesSettingsView));
    final cubit = overview.read<PluginManagementCubit>();
    unawaited(
      GoRouter.of(overview).push<void>(
        const AppRoute.settingsHarnessDetail(
          pluginId: "future-harness",
          presentation: HarnessSettingsPresentation.modal,
        ).buildPath(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(HarnessSettingsDetailView)).read<PluginManagementCubit>(), same(cubit));
    expect(find.byType(HarnessesSettingsView, skipOffstage: false), findsOneWidget);
    expect(find.byType(HarnessSettingsFlowView), findsOneWidget);
    await tester.tap(find.bySemanticsLabel("Back"));
    await tester.pumpAndSettle();
    expect(find.byType(HarnessSettingsDetailView), findsNothing);
    expect(tester.element(find.byType(HarnessesSettingsView)).read<PluginManagementCubit>(), same(cubit));
    unawaited(
      GoRouter.of(overview).push<void>(
        const AppRoute.settingsHarnessDetail(
          pluginId: "future-harness",
          presentation: HarnessSettingsPresentation.modal,
        ).buildPath(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel("Close settings"));
    await tester.pumpAndSettle();
    expect(find.text("open-harnesses"), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HarnessesSettingsScreen, skipOffstage: false), findsNothing);
    expect(snapshots.hasListener, isFalse);
    expect(authenticationTerminal.hasListener, isFalse);
  });

  testWidgets("raised as a modal, the bar closes with the X and shows no back button", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_appPushedFromOpener());
    await tester.pumpAndSettle();

    await tester.tap(find.text("open-harnesses"));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel("Close settings"), findsOneWidget);
    expect(find.bySemanticsLabel("Back"), findsNothing);
  });

  testWidgets("pushed onto the settings stack, the bar offers Back only", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_appPushedFromOpener(presentation: HarnessSettingsPresentation.pushed));
    await tester.pumpAndSettle();

    await tester.tap(find.text("open-harnesses"));
    await tester.pumpAndSettle();

    expect(find.byType(HarnessesSettingsScreen), findsOneWidget);
    expect(find.bySemanticsLabel("Close settings"), findsNothing);

    await tester.tap(find.bySemanticsLabel("Back"));
    await tester.pumpAndSettle();

    expect(find.byType(HarnessesSettingsScreen), findsNothing);
    expect(find.text("open-harnesses"), findsOneWidget);
  });

  group("per-harness catalog scan", () {
    Finder scanRowText(String pluginId, String text) => find.descendant(
      of: find.byKey(Key("harness_management_scan_$pluginId")),
      matching: find.text(text),
    );

    Future<void> openHarnesses(WidgetTester tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_app());
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await tester.pumpAndSettle();
      await _showDetail(tester, "future-harness");
    }

    // The keyboard-and-pointer twin of the lists' deep pull. A screen reader
    // cannot perform that gesture at all, so this row is not optional.
    testWidgets("starts a scan for the harness whose row was tapped", (tester) async {
      await openHarnesses(tester);

      await _openRow(tester, "harness_management_scan_future-harness");

      expect(rescan.startedPluginIds, ["future-harness"]);
    });

    // isEnabled is true for blocked and failed, which the bridge rejects with a
    // 503, so offering the row there would be a tappable no-op.
    testWidgets("offers no scan for a harness the bridge would refuse", (tester) async {
      await openHarnesses(tester);

      expect(find.byKey(const Key("harness_management_scan_future-harness")), findsOneWidget);
      expect(
        find.byKey(const Key("harness_management_scan_codex")),
        findsNothing,
        reason: "codex is setup-blocked, so it is not routable",
      );
    });

    testWidgets("does not offer the scan again while one covers this harness", (tester) async {
      await openHarnesses(tester);
      final row = find.byKey(const Key("harness_management_scan_future-harness"));
      await tester.ensureVisible(row);
      rescan.emit(
        const CatalogRescanState.preparingOne(
          pendingPluginName: "Future Harness",
          pluginIds: {"future-harness"},
        ),
      );
      // Fixed pumps rather than settling: the row's spinner never stops.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.widget<PregoGroupedRow>(row).onTap, isNull);

      expect(rescan.startedPluginIds, isEmpty);
      expect(
        find.descendant(of: row, matching: find.byType(PregoActivityIndicator)),
        findsOneWidget,
      );
    });

    // The fan-out skips a harness it cannot import from; a targeted scan must
    // say so on the card the user actually tapped.
    testWidgets("reports a targeted rejection on the harness that was named", (tester) async {
      await openHarnesses(tester);
      rescan.stubStartResult(const CatalogRescanStartResult.notImportable());

      await _openRow(tester, "harness_management_scan_future-harness");

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(scanRowText("future-harness", loc.harnessManagementScanNotReady), findsOneWidget);
      await _showDetail(tester, "opencode");
      expect(
        scanRowText("opencode", loc.harnessManagementScanDescription),
        findsOneWidget,
        reason: "a rejection belongs to the harness that was named, not to every card",
      );
    });

    testWidgets("says an older bridge cannot scan rather than reporting a failure", (tester) async {
      await openHarnesses(tester);
      rescan.stubStartResult(const CatalogRescanStartResult.unsupported());

      await _openRow(tester, "harness_management_scan_future-harness");

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(scanRowText("future-harness", loc.harnessManagementScanUnsupported), findsOneWidget);
    });

    // The cause is kept for the local log; the card renders bounded text only.
    testWidgets("never renders the error behind a failed start", (tester) async {
      await openHarnesses(tester);
      rescan.stubStartResult(
        CatalogRescanStartResult.failed(
          cause: ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "boom /Users/someone/secret"),
        ),
      );

      await _openRow(tester, "harness_management_scan_future-harness");

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(scanRowText("future-harness", loc.harnessManagementScanFailed), findsOneWidget);
      expect(find.textContaining("boom"), findsNothing);
      expect(find.textContaining("secret"), findsNothing);
    });

    // This screen has no progress row, so without the popup a scan started
    // here ends in silence and its result is auto-cleared before the user
    // could reach a list to read it.
    testWidgets("announces what a scan started here found", (tester) async {
      await openHarnesses(tester);
      await _openRow(tester, "harness_management_scan_future-harness");

      rescan.emit(
        const CatalogRescanState.succeeded(
          harnessCount: 1,
          counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 5),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining("5 new sessions in 2 new projects"), findsOneWidget);
    });

    testWidgets("announces a failure rather than letting the spinner just stop", (tester) async {
      await openHarnesses(tester);
      await _openRow(tester, "harness_management_scan_future-harness");

      rescan.emit(const CatalogRescanState.failed(harnessCount: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(find.text(loc.harnessManagementScanFinishedFailed), findsOneWidget);
    });

    // The row above that list already reported it.
    testWidgets("says nothing about a scan a list started", (tester) async {
      await openHarnesses(tester);

      rescan.emit(
        const CatalogRescanState.succeeded(
          harnessCount: 1,
          counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 3),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining("3 new sessions"), findsNothing);
    });

    testWidgets("a retry clears the rejection the previous attempt left", (tester) async {
      await openHarnesses(tester);
      rescan.stubStartResult(const CatalogRescanStartResult.notImportable());
      await _openRow(tester, "harness_management_scan_future-harness");

      rescan.stubStartResult(const CatalogRescanStartResult.accepted());
      await _openRow(tester, "harness_management_scan_future-harness");

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(scanRowText("future-harness", loc.harnessManagementScanNotReady), findsNothing);
      expect(scanRowText("future-harness", loc.harnessManagementScanDescription), findsOneWidget);
    });
  });
}
