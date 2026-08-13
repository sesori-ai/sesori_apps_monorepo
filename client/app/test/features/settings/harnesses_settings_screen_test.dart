import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/features/settings/harnesses_settings_screen.dart";
import "package:sesori_mobile/features/settings/settings_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
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

Widget _app() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => BlocProvider<ConnectionOverlayCubit>.value(
          value: StubConnectionOverlayCubit(),
          child: const HarnessesSettingsScreen(presentation: HarnessSettingsPresentation.modal),
        ),
      ),
      GoRoute(
        path: "/projects",
        builder: (context, state) => const Scaffold(body: Text("projects-route")),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

/// The app's real route table with a stand-in for whatever screen raises
/// harness settings — the new-session harness menu in production. Exercises the
/// close button's pop branch, which `_app` (mounted at the router root) cannot.
Widget _appPushedFromOpener({
  HarnessSettingsPresentation presentation = HarnessSettingsPresentation.modal,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: "/opener",
    routes: [
      GoRoute(
        path: "/opener",
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.pushRoute(AppRoute.settingsHarnesses(presentation: presentation)),
            child: const Text("open-harnesses"),
          ),
        ),
      ),
      GoRoute(
        path: "/projects",
        builder: (context, state) => const Scaffold(body: Text("projects-route")),
      ),
      ...buildAppRoutesForTesting(rootNavigatorKey: rootNavigatorKey),
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
  final row = find.byKey(Key(key));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Finder _switchFor(String pluginId) => find.descendant(
  of: find.byKey(Key("harness_management_enabled_$pluginId")),
  matching: find.byType(PregoSwitch),
);

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
  late BehaviorSubject<Map<String, PluginInstallProgress>> installProgress;
  late BehaviorSubject<Map<String, PluginAuthenticationChallenge>> authenticationChallenges;
  late StreamController<PluginAuthenticationTerminalUpdate> authenticationTerminal;
  late _MockUrlLauncher urlLauncher;

  setUpAll(() {
    registerFallbackValue(const PluginLifecycleCommandRequest.enable());
    registerFallbackValue(const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 10));
    registerFallbackValue(const PluginManagementIdleTimeoutInput.noTimeout());
    registerFallbackValue(_conflict);
    registerFallbackValue(PluginManagementForceAction.disable);
    registerFallbackValue(Uri.parse("https://example.com"));
    registerFallbackValue(UrlLaunchMode.externalApp);
  });

  setUp(() async {
    await GetIt.instance.reset();
    service = _MockPluginManagementService();
    urlLauncher = _MockUrlLauncher();
    snapshots = BehaviorSubject();
    installProgress = BehaviorSubject.seeded(const {});
    authenticationChallenges = BehaviorSubject.seeded(const {});
    authenticationTerminal = StreamController.broadcast(sync: true);
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
    when(() => service.installProgress).thenAnswer((_) => installProgress.stream);
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
      (_) async => const PluginAuthenticationStartResult.challenge(
        challenge: PluginAuthenticationChallengeResponse.deviceCode(
          verificationUrl: "https://auth.example/device",
          userCode: "ABCD-EFGH",
        ),
      ),
    );
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
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await snapshots.close();
    await installProgress.close();
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

    expect(find.byKey(const Key("harness_authentication_codex")), findsOneWidget);
    expect(find.text("Log in"), findsOneWidget);
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

  testWidgets("device-code sheet opens browser explicitly and dismissal does not cancel", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired]),
        refreshError: null,
      ),
    );
    authenticationChallenges.add({
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();

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
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("harness_authentication_copy")));
    await tester.pump();

    expect(clipboardCall?.method, "Clipboard.setData");
    expect(clipboardCall?.arguments, {"text": "ABCD-EFGH"});
    expect(find.text("Code copied"), findsOneWidget);
  });

  testWidgets("browser launch failure keeps the challenge and shows retry guidance", (tester) async {
    _useTallSurface(tester);
    when(
      () => urlLauncher.launch(any(), mode: any(named: "mode")),
    ).thenAnswer((_) async => false);
    await tester.pumpWidget(_app());
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(plugins: [_authenticationRequired]),
        refreshError: null,
      ),
    );
    authenticationChallenges.add({
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harness_authentication_codex")));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("harness_authentication_open_browser")));
    await tester.pumpAndSettle();

    expect(find.text("ABCD-EFGH"), findsOneWidget);
    expect(find.text("The secure website could not be opened. Copy the code and try again."), findsOneWidget);
    expect(find.byKey(const Key("harness_authentication_open_browser")), findsOneWidget);
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
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
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
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
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
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
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
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
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

    cancelResult.complete(const PluginAuthenticationCancelResult.uncertain());
    await tester.pumpAndSettle();
    expect(
      tester.widget<PregoButtonsSolid>(find.byKey(const Key("harness_authentication_open_browser"))).onPressed,
      isNull,
    );
    expect(
      tester.widget<PregoButtonsSolid>(find.byKey(const Key("harness_authentication_cancel"))).onPressed,
      isNotNull,
    );
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
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await tester.pumpAndSettle();
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

    expect(find.text("Runtime missing"), findsOneWidget);
    expect(find.text("Install the harness runtime."), findsOneWidget);
    expect(find.byKey(const Key("harness_management_enabled_future-harness")), findsOneWidget);
    expect(tester.widget<PregoSwitch>(_switchFor("future-harness")).value, isTrue);
    expect(find.byKey(const Key("harness_management_refresh_future-harness")), findsOneWidget);
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

  testWidgets("install is offered for a missing runtime and streams its phases", (tester) async {
    _useTallSurface(tester);
    final plugin = _managed.copyWith(
      setup: _managed.setup.copyWith(state: PluginSetupState.runtimeMissing, actionHint: null),
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
    expect(find.text("Download this harness for Sesori only. Your system stays untouched."), findsOneWidget);

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
    installProgress.add(const {
      "future-harness": PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 42),
    });
    await tester.pump();
    await tester.pump();
    expect(find.text("Downloading… 42%"), findsOneWidget);

    installProgress.add(const {
      "future-harness": PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null),
    });
    await tester.pump();
    await tester.pump();
    expect(find.text("Extracting…"), findsOneWidget);

    // A second tap while installing must not send another command.
    await tester.tap(find.byKey(const Key("harness_management_install_future-harness")));
    await tester.pump();
    verifyNever(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.install(),
      ),
    );

    // A phase only a newer bridge names still reads as work in progress.
    installProgress.add(const {
      "future-harness": PluginInstallProgress(phase: PluginInstallPhase.unknown, percent: null),
    });
    await tester.pump();
    await tester.pump();
    expect(find.text("Installing…"), findsOneWidget);
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

    expect(find.text("Ready"), findsOneWidget);
    expect(find.byKey(const Key("harness_management_enabled_future-harness")), findsOneWidget);
    expect(tester.widget<PregoSwitch>(_switchFor("future-harness")).value, isFalse);
    expect(find.byKey(const Key("harness_management_refresh_future-harness")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_restart_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_timeout_future-harness")), findsNothing);
    expect(find.byKey(const Key("harness_management_default_timeout")), findsNothing);
    expect(find.text("Runtime"), findsNothing);
    expect(find.text("Work"), findsNothing);
    expect(find.text("Idle"), findsNothing);

    await tester.tap(_switchFor("future-harness"));
    await tester.pump();
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.enable(),
      ),
    ).called(1);
  });

  testWidgets("setup-ready enabled renders known facts, controls, logos, and default badge", (tester) async {
    _useTallSurface(tester);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final scaffold = tester.widget<PregoGlassScaffold>(find.byType(PregoGlassScaffold));
    expect(scaffold.title, "Harnesses");
    expect(scaffold.titleMode, PregoTopNavigationTitleMode.inline);
    expect(find.byKey(const Key("harnesses_manage")), findsNothing);
    expect(find.byKey(const Key("harnesses_card_opencode")), findsOneWidget);
    expect(find.byKey(const Key("harnesses_card_future-harness")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_card_future-harness")), findsOneWidget);
    expect(findBrandLogo("opencode"), findsOneWidget);
    expect(find.byIcon(TablerRegular.plug), findsOneWidget);
    expect(find.text("Default"), findsOneWidget);
    expect(find.text("Run login if requests fail."), findsOneWidget);
    expect(find.text("Active"), findsNWidgets(2));
    expect(find.text("Idle"), findsNWidgets(2));
    expect(find.byKey(const Key("harness_management_enabled_future-harness")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_restart_future-harness")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_timeout_future-harness")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_default_timeout")), findsOneWidget);
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

    expect(find.byKey(const Key("harness_management_external_opencode")), findsOneWidget);
    expect(find.text("Managed outside Sesori"), findsOneWidget);
    expect(find.byKey(const Key("harness_management_refresh_opencode")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_enabled_opencode")), findsNothing);
    expect(find.byKey(const Key("harness_management_restart_opencode")), findsNothing);
    expect(find.byKey(const Key("harness_management_timeout_opencode")), findsNothing);
    expect(find.byKey(const Key("harness_management_default_timeout")), findsNothing);
    expect(find.text("Active"), findsOneWidget);
    expect(find.text("Idle"), findsOneWidget);

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

  testWidgets("unknown runtime and work facts are omitted rather than presented as disabled", (tester) async {
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

    expect(find.text("Unknown"), findsNothing);
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

    expect(find.text("Active"), findsOneWidget);
    expect(find.text("Work"), findsNothing);
    expect(find.text("Unknown"), findsNothing);
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

    await tester.tap(find.byKey(const Key("harness_management_refresh_opencode")));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("harness_management_action_error")), findsOneWidget);
    expect(find.text("The harness is no longer registered on this bridge."), findsOneWidget);

    await tester.tap(find.byTooltip("Dismiss action error"));
    await tester.pump();
    expect(find.byKey(const Key("harness_management_action_error")), findsNothing);
    expect(find.text("OpenCode"), findsOneWidget);
  });

  testWidgets("safe setup refresh and restart actions dispatch once", (tester) async {
    _useTallSurface(tester);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

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

  testWidgets("an in-progress action blocks conflicting controls", (tester) async {
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

    await tester.tap(find.byKey(const Key("harness_management_refresh_opencode")));
    await tester.pump();

    final restart = find.byKey(const Key("harness_management_restart_future-harness"));
    expect(tester.widget<PregoGroupedRow>(restart).onTap, isNull);
    expect(tester.widget<PregoSwitch>(_switchFor("future-harness")).onChanged, isNull);

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

    expect(find.text("No timeout"), findsNWidgets(2));
    expect(find.text("This harness stays running"), findsOneWidget);
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

    await _openRow(tester, "harness_management_clear_timeout_future-harness");
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

  testWidgets("pull refresh delegates to the cubit and close returns to Projects", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pump(const Duration(seconds: 1));
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
    // `/settings/harnesses` is a child route of `/settings`, but an imperative
    // push adds one page for the location's last route — the Settings list is
    // not inserted underneath. If a go_router upgrade ever changed that, the
    // single pop below would land on Settings instead of the opener.
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.tap(find.bySemanticsLabel("Close settings"));
    await tester.pumpAndSettle();

    expect(find.byType(HarnessesSettingsScreen), findsNothing);
    expect(find.text("open-harnesses"), findsOneWidget);
    expect(find.text("projects-route"), findsNothing);
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

  testWidgets("pushed onto the settings stack, the bar goes back and shows no close button", (tester) async {
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
}
