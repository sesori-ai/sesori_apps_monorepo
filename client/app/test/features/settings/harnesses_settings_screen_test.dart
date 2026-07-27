import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/settings/harnesses_settings_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class _MockPluginManagementService extends Mock implements PluginManagementService {}

const _response = PluginManagementResponse(
  snapshotToken: "snapshot-1",
  bridgeId: "bridge-1",
  defaultPluginId: "opencode",
  defaultIdleTimeoutMins: 10,
  plugins: [
    PluginManagementMetadata(
      setup: PluginSetupMetadata(
        id: "opencode",
        displayName: "OpenCode",
        state: PluginSetupState.ready,
        actionHint: "Run login if requests fail.",
      ),
      runtimeState: PluginRuntimeState.active,
      workState: PluginManagementWorkState.idle,
      idleTimeoutMins: 10,
      hasIdleTimeoutOverride: false,
      actionHint: null,
    ),
    PluginManagementMetadata(
      setup: PluginSetupMetadata(
        id: "future-harness",
        displayName: "Future Harness",
        state: PluginSetupState.unknown,
        actionHint: null,
      ),
      runtimeState: PluginRuntimeState.unknown,
      workState: PluginManagementWorkState.unknown,
      idleTimeoutMins: 20,
      hasIdleTimeoutOverride: true,
      actionHint: "Future guidance.",
    ),
  ],
);

Widget _app() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => BlocProvider<ConnectionOverlayCubit>.value(
          value: StubConnectionOverlayCubit(),
          child: const HarnessesSettingsScreen(),
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

  setUp(() async {
    await GetIt.instance.reset();
    service = _MockPluginManagementService();
    snapshots = BehaviorSubject();
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
    when(() => service.refresh()).thenAnswer((_) async {});
    when(() => service.onDispose()).thenAnswer((_) async {});
    GetIt.instance.registerSingleton<PluginManagementService>(service);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await snapshots.close();
  });

  testWidgets("shows the existing Prego loading treatment", (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byType(PregoActivityIndicator), findsOneWidget);
    expect(find.bySemanticsLabel("Loading harnesses"), findsOneWidget);
  });

  testWidgets("explains when the bridge does not support Harnesses", (tester) async {
    snapshots.add(const PluginManagementLoadResult.unsupported());

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text("Harnesses aren't supported"), findsOneWidget);
    expect(find.text("Update the connected bridge to view and manage its harnesses."), findsOneWidget);
  });

  testWidgets("initial failure offers Retry", (tester) async {
    snapshots.add(PluginManagementLoadResult.failure(error: ApiError.dartHttpClient(Exception("offline"))));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harnesses_retry")));

    verify(() => service.refresh()).called(1);
  });

  testWidgets("ready view renders known and generic logos, status facts, guidance, and default badge", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("harnesses_card_opencode")), findsOneWidget);
    expect(find.byKey(const Key("harnesses_card_future-harness")), findsOneWidget);
    expect(find.byIcon(VESPRSolid.opencode), findsOneWidget);
    expect(find.byIcon(TablerRegular.plug), findsOneWidget);
    expect(find.text("Default"), findsOneWidget);
    expect(find.text("Run login if requests fail."), findsOneWidget);
    expect(find.text("Future guidance."), findsOneWidget);
    expect(find.text("Unknown"), findsNWidgets(3));
    expect(find.text("Active"), findsOneWidget);
    expect(find.text("Idle"), findsOneWidget);
    expect(find.text("Uses the bridge default"), findsOneWidget);
    expect(find.text("Custom for this harness"), findsOneWidget);
    expect(find.text("10 min"), findsOneWidget);
    expect(find.text("20 min"), findsOneWidget);
  });

  testWidgets("supported response with no registered harnesses shows an explicit empty state", (tester) async {
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
  });

  testWidgets("ready refresh failure keeps the snapshot visible and can be dismissed", (tester) async {
    snapshots.add(
      PluginManagementLoadResult.supported(
        response: _response,
        refreshError: ApiError.dartHttpClient(Exception("offline")),
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("harnesses_refresh_error")), findsOneWidget);
    expect(find.text("OpenCode"), findsOneWidget);

    await tester.tap(find.byTooltip("Dismiss refresh error"));
    await tester.pump();

    expect(find.byKey(const Key("harnesses_refresh_error")), findsNothing);
    expect(find.text("OpenCode"), findsOneWidget);
  });

  testWidgets("pull to refresh delegates to the management cubit", (tester) async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pump(const Duration(seconds: 1));

    verify(() => service.refresh()).called(1);
  });

  testWidgets("close returns to Projects", (tester) async {
    snapshots.add(const PluginManagementLoadResult.unsupported());

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.x));
    await tester.pumpAndSettle();

    expect(find.text("projects-route"), findsOneWidget);
  });
}
