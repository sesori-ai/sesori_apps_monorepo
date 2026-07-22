import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/settings/plugin_settings_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

const _activePlugin = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "plugin-a",
    displayName: "Plugin A",
    state: PluginSetupState.ready,
    actionHint: null,
  ),
  runtimeState: PluginRuntimeState.active,
  workState: PluginManagementWorkState.idle,
  idleTimeoutMins: 10,
  hasIdleTimeoutOverride: false,
  actionHint: null,
);

const _disabledPlugin = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "plugin-b",
    displayName: "Plugin B",
    state: PluginSetupState.runtimeMissing,
    actionHint: "Install the runtime on your computer.",
  ),
  runtimeState: PluginRuntimeState.disabled,
  workState: PluginManagementWorkState.unknown,
  idleTimeoutMins: 20,
  hasIdleTimeoutOverride: true,
  actionHint: "Check setup after resolving the issue.",
);

const _response = PluginManagementResponse(
  revision: 1,
  defaultPluginId: "plugin-b",
  defaultIdleTimeoutMins: 10,
  plugins: [_activePlugin, _disabledPlugin],
);

Widget _app() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => const PluginSettingsScreen(),
      ),
      GoRoute(
        path: "/projects",
        builder: (context, state) => const SizedBox.shrink(),
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

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app());
  await tester.pump();
}

void main() {
  late MockPluginManagementService service;
  late BehaviorSubject<PluginManagementLoadResult> snapshots;

  setUpAll(() {
    registerFallbackValue(const PluginLifecycleCommandRequest.enable());
    registerFallbackValue(const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 0));
  });

  setUp(() async {
    await GetIt.instance.reset();
    service = MockPluginManagementService();
    snapshots = BehaviorSubject<PluginManagementLoadResult>();
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
    when(service.refresh).thenAnswer((_) async {});
    GetIt.instance.registerSingleton<PluginManagementService>(service);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await snapshots.close();
  });

  testWidgets("renders loading and unsupported bridge states", (tester) async {
    await _pumpApp(tester);

    expect(find.bySemanticsLabel("Loading coding tools"), findsOneWidget);

    snapshots.add(const PluginManagementLoadResult.unsupported());
    await tester.pump();

    expect(find.text("Update your bridge to manage coding tools"), findsOneWidget);
    expect(find.textContaining("older bridge"), findsOneWidget);
  });

  testWidgets("failure state retries through the management cubit", (tester) async {
    snapshots.add(PluginManagementLoadResult.failure(error: ApiError.generic()));
    await _pumpApp(tester);

    expect(find.text("Could not load coding tools"), findsOneWidget);
    await tester.tap(find.byKey(const Key("plugin_settings_retry")));

    verify(service.refresh).called(1);
  });

  testWidgets("ready state renders all registrations and dispatches management actions", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response));
    when(
      () => service.command(
        pluginId: any(named: "pluginId"),
        request: any(named: "request"),
      ),
    ).thenAnswer((_) async => const PluginManagementMutationResult.success(response: _response));
    when(
      () => service.updateIdleTimeout(request: any(named: "request")),
    ).thenAnswer((_) async => const PluginManagementMutationResult.success(response: _response));

    await _pumpApp(tester);

    expect(find.byKey(const Key("plugin_settings_card_plugin-a")), findsOneWidget);
    expect(find.byKey(const Key("plugin_settings_card_plugin-b")), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key("plugin_settings_card_plugin-b")),
        matching: find.text("Default"),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key("plugin_settings_card_plugin-a")),
        matching: find.text("Default"),
      ),
      findsNothing,
    );
    expect(find.text("Runtime missing"), findsOneWidget);
    expect(find.text("Not eligible"), findsOneWidget);
    expect(find.text("Custom override"), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key("plugin_settings_refresh_plugin-a")));
    await tester.tap(find.byKey(const Key("plugin_settings_refresh_plugin-a")));
    await tester.pump();
    verify(
      () => service.command(
        pluginId: "plugin-a",
        request: const PluginLifecycleCommandRequest.refresh(),
      ),
    ).called(1);

    await tester.tap(find.byKey(const Key("plugin_settings_restart_plugin-a")));
    await tester.pump();
    verify(
      () => service.command(
        pluginId: "plugin-a",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      ),
    ).called(1);

    await tester.ensureVisible(find.byKey(const Key("plugin_settings_enabled_plugin-a")));
    await tester.tap(find.byKey(const Key("plugin_settings_enabled_plugin-a")));
    await tester.pump();
    verify(
      () => service.command(
        pluginId: "plugin-a",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      ),
    ).called(1);

    await tester.ensureVisible(find.byKey(const Key("plugin_settings_enabled_plugin-b")));
    await tester.tap(find.byKey(const Key("plugin_settings_enabled_plugin-b")));
    await tester.pump();
    verify(
      () => service.command(
        pluginId: "plugin-b",
        request: const PluginLifecycleCommandRequest.enable(),
      ),
    ).called(1);

    await tester.ensureVisible(find.byKey(const Key("plugin_settings_edit_global_timeout")));
    await tester.tap(find.byKey(const Key("plugin_settings_edit_global_timeout")));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("plugin_settings_timeout_input")), "25");
    await tester.tap(find.byKey(const Key("plugin_settings_save_timeout")));
    await tester.pumpAndSettle();
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 25),
      ),
    ).called(1);

    await tester.ensureVisible(find.byKey(const Key("plugin_settings_set_override_plugin-a")));
    await tester.tap(find.byKey(const Key("plugin_settings_set_override_plugin-a")));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("plugin_settings_timeout_input")), "12");
    await tester.tap(find.byKey(const Key("plugin_settings_save_timeout")));
    await tester.pumpAndSettle();
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "plugin-a", idleTimeoutMins: 12),
      ),
    ).called(1);

    await tester.ensureVisible(find.byKey(const Key("plugin_settings_clear_override_plugin-b")));
    await tester.tap(find.byKey(const Key("plugin_settings_clear_override_plugin-b")));
    await tester.pump();
    verify(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "plugin-b"),
      ),
    ).called(1);
  });

  testWidgets("safe conflict requires explicit force confirmation", (tester) async {
    const busyPlugin = PluginManagementMetadata(
      setup: PluginSetupMetadata(
        id: "plugin-a",
        displayName: "Plugin A",
        state: PluginSetupState.ready,
        actionHint: null,
      ),
      runtimeState: PluginRuntimeState.active,
      workState: PluginManagementWorkState.busy,
      idleTimeoutMins: 10,
      hasIdleTimeoutOverride: false,
      actionHint: null,
    );
    const busyResponse = PluginManagementResponse(
      revision: 2,
      defaultPluginId: "plugin-a",
      defaultIdleTimeoutMins: 10,
      plugins: [busyPlugin],
    );
    const conflict = PluginLifecycleConflict(
      pluginId: "plugin-a",
      reasons: [PluginLifecycleConflictReason.busy],
      current: busyPlugin,
    );
    snapshots.add(const PluginManagementLoadResult.supported(response: busyResponse));
    when(
      () => service.command(
        pluginId: "plugin-a",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      ),
    ).thenAnswer((_) async => const PluginManagementMutationResult.conflict(conflict: conflict));
    when(
      () => service.command(
        pluginId: "plugin-a",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
    ).thenAnswer((_) async => const PluginManagementMutationResult.success(response: busyResponse));

    await _pumpApp(tester);

    await tester.ensureVisible(find.byKey(const Key("plugin_settings_enabled_plugin-a")));
    await tester.tap(find.byKey(const Key("plugin_settings_enabled_plugin-a")));
    await tester.pumpAndSettle();
    expect(find.text("Force disable this coding tool?"), findsOneWidget);
    verifyNever(
      () => service.command(
        pluginId: "plugin-a",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
    );

    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();
    verifyNever(
      () => service.command(
        pluginId: "plugin-a",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
    );

    await tester.tap(find.byKey(const Key("plugin_settings_enabled_plugin-a")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Force"));
    await tester.pumpAndSettle();

    verify(
      () => service.command(
        pluginId: "plugin-a",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
    ).called(1);
  });
}
