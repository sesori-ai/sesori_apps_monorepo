import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/settings/harness_management_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class _MockPluginManagementService extends Mock implements PluginManagementService {}

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
    actionHint: null,
  ),
  runtimeState: PluginRuntimeState.active,
  workState: PluginManagementWorkState.idle,
  idleTimeoutMins: 0,
  hasIdleTimeoutOverride: false,
  managementCapabilities: {PluginManagementCapability.setupRefresh},
  actionHint: null,
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

Widget _app({String initialLocation = "/manage"}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: "/overview",
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push("/manage"),
            child: const Text("open-management"),
          ),
        ),
      ),
      GoRoute(
        path: "/manage",
        builder: (context, state) => BlocProvider<ConnectionOverlayCubit>.value(
          value: StubConnectionOverlayCubit(),
          child: const HarnessManagementScreen(),
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

void main() {
  late _MockPluginManagementService service;
  late BehaviorSubject<PluginManagementLoadResult> snapshots;

  setUpAll(() {
    registerFallbackValue(const PluginLifecycleCommandRequest.enable());
    registerFallbackValue(const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 10));
    registerFallbackValue(_conflict);
    registerFallbackValue(PluginManagementForceAction.disable);
  });

  setUp(() async {
    await GetIt.instance.reset();
    service = _MockPluginManagementService();
    snapshots = BehaviorSubject();
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
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
      () => service.planApplyAllIdleTimeout(input: any(named: "input")),
    ).thenAnswer((invocation) {
      final input = invocation.namedArguments[#input] as String;
      final minutes = int.tryParse(input.trim());
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
      final input = invocation.namedArguments[#input] as String;
      final minutes = int.tryParse(input.trim());
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
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await snapshots.close();
  });

  testWidgets("renders loading, unsupported, and failure treatments", (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.bySemanticsLabel("Loading harnesses"), findsOneWidget);

    snapshots.add(const PluginManagementLoadResult.unsupported());
    await tester.pumpAndSettle();
    expect(find.text("Harnesses aren't supported"), findsOneWidget);

    snapshots.add(PluginManagementLoadResult.failure(error: ApiError.dartHttpClient(Exception("offline"))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harness_management_retry")));
    verify(() => service.refresh()).called(1);
  });

  testWidgets("renders controls strictly from capabilities rather than plugin identity or state", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("harness_management_external_opencode")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_refresh_opencode")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_enabled_opencode")), findsNothing);
    expect(find.byKey(const Key("harness_management_restart_opencode")), findsNothing);
    expect(find.byKey(const Key("harness_management_timeout_opencode")), findsNothing);

    expect(find.byKey(const Key("harness_management_enabled_future-harness")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_restart_future-harness")), findsOneWidget);
    expect(find.byKey(const Key("harness_management_timeout_future-harness")), findsOneWidget);
    expect(findBrandLogo("opencode"), findsOneWidget);
    expect(find.byIcon(TablerRegular.plug), findsOneWidget);
  });

  testWidgets("unknown runtime state keeps lifecycle controls visible but fails closed as disabled", (tester) async {
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response.copyWith(
          plugins: [_managed.copyWith(runtimeState: PluginRuntimeState.unknown)],
        ),
        refreshError: null,
      ),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final switchFinder = find.descendant(
      of: find.byKey(const Key("harness_management_enabled_future-harness")),
      matching: find.byType(PregoSwitch),
    );
    final lifecycleSwitch = tester.widget<PregoSwitch>(switchFinder);
    expect(lifecycleSwitch.value, isFalse);
    expect(lifecycleSwitch.onChanged, isNull);
    final restart = find.byKey(const Key("harness_management_restart_future-harness"));
    expect(tester.widget<PregoGroupedRow>(restart).onTap, isNull);
  });

  testWidgets("safe lifecycle and setup refresh controls dispatch once", (tester) async {
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

    await tester.ensureVisible(find.byKey(const Key("harness_management_restart_future-harness")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harness_management_restart_future-harness")));
    await tester.pump();
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      ),
    ).called(1);
  });

  testWidgets("an in-progress action disables conflicting controls", (tester) async {
    final commandCompleter = Completer<PluginManagementMutationResult>();
    when(
      () => service.command(pluginId: "opencode", request: const PluginLifecycleCommandRequest.refresh()),
    ).thenAnswer((_) => commandCompleter.future);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("harness_management_refresh_opencode")));
    await tester.pump();
    final restart = find.byKey(const Key("harness_management_restart_future-harness"));
    await tester.ensureVisible(restart);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<PregoGroupedRow>(restart).onTap, isNull);

    commandCompleter.complete(const PluginManagementMutationResult.success(response: _response));
    await tester.pumpAndSettle();
  });

  testWidgets("global timeout accepts signed values and invalid input stays visible as an action error", (
    tester,
  ) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("harness_management_default_timeout")));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("harness_management_timeout_input")), "-5");
    await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
    await tester.pumpAndSettle();
    verify(() => service.planApplyAllIdleTimeout(input: "-5")).called(1);
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: -5),
      ),
    ).called(1);

    await tester.tap(find.byKey(const Key("harness_management_default_timeout")));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("harness_management_timeout_input")), "invalid");
    await tester.tap(find.byKey(const Key("harness_management_timeout_save")));
    await tester.pumpAndSettle();
    expect(find.text("Enter a whole number of minutes."), findsOneWidget);
  });

  testWidgets("per-harness timeout can be overridden and cleared", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final timeout = find.byKey(const Key("harness_management_timeout_future-harness"));
    await tester.ensureVisible(timeout);
    await tester.pumpAndSettle();
    await tester.tap(timeout);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("harness_management_timeout_input")), "0");
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

    final clear = find.byKey(const Key("harness_management_clear_timeout_future-harness"));
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pump();
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "future-harness"),
      ),
    ).called(1);
  });

  testWidgets("force confirmation cancel does not dispatch and confirm sends exactly one force command", (
    tester,
  ) async {
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
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final switchFinder = find.descendant(
      of: find.byKey(const Key("harness_management_enabled_future-harness")),
      matching: find.byType(PregoSwitch),
    );
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harness_management_force_cancel")));
    await tester.pumpAndSettle();
    expect(safeCalls, 1);
    verifyNever(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
    );

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harness_management_force_confirm")));
    await tester.pumpAndSettle();
    expect(safeCalls, 2);
    verify(
      () => service.command(
        pluginId: "future-harness",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
    ).called(1);
  });

  testWidgets("refresh failure remains visible while force confirmation is pending", (tester) async {
    when(
      () => service.command(
        pluginId: "future-harness",
        request: any(named: "request"),
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

    final restart = find.byKey(const Key("harness_management_restart_future-harness"));
    await tester.ensureVisible(restart);
    await tester.pumpAndSettle();
    await tester.tap(restart);
    await tester.pumpAndSettle();
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response,
        refreshError: ApiError.dartHttpClient(Exception("offline")),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key("harness_management_force_cancel")), findsOneWidget);
    await tester.tap(find.byKey(const Key("harness_management_force_cancel")));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("harness_management_refresh_error")), findsOneWidget);
  });

  testWidgets("back returns to overview and close returns to Projects", (tester) async {
    snapshots.add(const PluginManagementLoadResult.unsupported());
    await tester.pumpWidget(_app(initialLocation: "/overview"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("open-management"));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text("open-management"), findsOneWidget);

    await tester.tap(find.text("open-management"));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.x));
    await tester.pumpAndSettle();
    expect(find.text("projects-route"), findsOneWidget);
  });
}
