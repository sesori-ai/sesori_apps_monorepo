import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _Service() extends Mock implements PluginManagementService;
class _Launcher() extends Mock implements UrlLauncher;

const _ready = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "ready",
    displayName: "Ready harness",
    state: PluginSetupState.ready,
    runtimeVersion: "1.2.3",
    actionHint: null,
  ),
  runtimeState: PluginRuntimeState.active,
  workState: PluginManagementWorkState.idle,
  idleTimeoutMins: 10,
  hasIdleTimeoutOverride: false,
  managementCapabilities: {
    PluginManagementCapability.lifecycle,
    PluginManagementCapability.install,
    PluginManagementCapability.setupRefresh,
    PluginManagementCapability.idleTimeout,
  },
  actionHint: null,
);

PluginManagementMetadata _plugin({
  required String id,
  required PluginRuntimeState runtime,
  required PluginSetupState setup,
}) => _ready.copyWith(
  setup: _ready.setup.copyWith(id: id, displayName: id, state: setup),
  runtimeState: runtime,
);

void main() {
  late _Service service;
  late BehaviorSubject<PluginManagementLoadResult> snapshots;
  late BehaviorSubject<Map<String, PluginInstallState>> installs;
  late StreamController<PluginAuthenticationTerminalUpdate> terminal;
  late PluginManagementCubit cubit;
  late FakeCatalogRescanService scan;
  final opened = <String>[];

  setUpAll(() => registerFallbackValue(const PluginLifecycleCommandRequest.enable()));
  setUp(() {
    service = _Service();
    snapshots = BehaviorSubject(sync: true);
    installs = BehaviorSubject.seeded(const {}, sync: true);
    terminal = StreamController.broadcast();
    scan = FakeCatalogRescanService();
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
    when(() => service.installStates).thenAnswer((_) => installs.stream);
    when(() => service.authenticationTerminal).thenAnswer((_) => terminal.stream);
    when(
      () => service.command(
        pluginId: any(named: "pluginId"),
        request: any(named: "request"),
      ),
    ).thenAnswer((_) async => const PluginManagementMutationResult.uncertain());
    cubit = PluginManagementCubit(service: service, urlLauncher: _Launcher(), catalogRescanService: scan);
    opened.clear();
  });
  tearDown(() async {
    await cubit.close();
    await snapshots.close();
    await installs.close();
    await terminal.close();
    await scan.onDispose();
  });

  void publish({required List<PluginManagementMetadata> plugins}) => snapshots.add(
    PluginManagementLoadResult.supported(
      response: PluginManagementResponse(
        snapshotToken: "test",
        bridgeId: "bridge",
        defaultPluginId: "ready",
        defaultIdleTimeoutMins: 10,
        plugins: plugins,
      ),
      refreshError: null,
    ),
  );

  Widget app({String? detailId, double scale = 1}) => BlocProvider.value(
    value: cubit,
    child: MaterialApp(
      theme: buildPregoThemeData(brightness: Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: HarnessSettingsFlowView(
        child: detailId == null
            ? HarnessesSettingsView(
                presentation: HarnessSettingsPresentation.modal,
                connectionBanner: null,
                onClose: () {},
                onBack: null,
                onOpenHarness: ({required pluginId}) => opened.add(pluginId),
              )
            : HarnessSettingsDetailView(pluginId: detailId, connectionBanner: null, onBack: () {}, onClose: () {}),
      ),
    ),
  );

  void phone({required WidgetTester tester}) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets("overview groups honest states in design order and preserves registry order", (tester) async {
    phone(tester: tester);
    publish(
      plugins: [
        _plugin(id: "disabled", runtime: PluginRuntimeState.disabled, setup: PluginSetupState.authenticationRequired),
        _ready,
        _plugin(id: "missing", runtime: PluginRuntimeState.blocked, setup: PluginSetupState.runtimeMissing),
        _plugin(id: "degraded", runtime: PluginRuntimeState.degraded, setup: PluginSetupState.ready),
        _plugin(id: "unknown", runtime: PluginRuntimeState.unknown, setup: PluginSetupState.ready),
        _plugin(id: "starting", runtime: PluginRuntimeState.starting, setup: PluginSetupState.ready),
      ],
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final ids = tester
        .widgetList<PregoGroupedRow>(find.byType(PregoGroupedRow))
        .map((row) => row.key)
        .whereType<Key>()
        .toList();
    expect(ids, [
      const Key("harnesses_card_degraded"),
      const Key("harnesses_card_unknown"),
      const Key("harnesses_card_ready"),
      const Key("harnesses_card_starting"),
      const Key("harnesses_card_missing"),
      const Key("harnesses_card_disabled"),
      const Key("harness_management_default_timeout"),
    ]);
    final disabled = tester.widget<PregoGroupedRow>(find.byKey(const Key("harnesses_card_disabled")));
    expect(disabled.subtitle, isNull);
    expect(disabled.minHeight, 68);
    expect(find.byKey(const Key("harness_management_enabled_unknown")), findsNothing);
    expect(find.text("Default"), findsNothing);
    expect(find.text("Automatic updates"), findsNothing);
    expect(find.text("Unknown"), findsOneWidget);
    for (final card in tester.widgetList<PregoGroupedRows>(find.byType(PregoGroupedRows)).take(4)) {
      expect(card.showDividers, isFalse);
      expect(card.color, PregoDesignSystem.light.colors.bgSurface2);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("name, actual enabled switch and immediate install icon are independent targets", (tester) async {
    phone(tester: tester);
    publish(
      plugins: [_plugin(id: "missing", runtime: PluginRuntimeState.blocked, setup: PluginSetupState.runtimeMissing)],
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key("harness_management_enabled_missing"));
    final toggleTarget = find.byKey(const Key("harness_management_enabled_target_missing"));
    expect(tester.widget<PregoSwitch>(toggle).value, isTrue);
    expect(tester.getSize(toggle), const Size(64, 28));
    expect(tester.getSize(toggleTarget), const Size(64, 44));
    final enabledSemantics = find.bySemanticsLabel("missing enabled");
    expect(enabledSemantics, findsOneWidget);
    expect(tester.getSemantics(enabledSemantics).rect.height, 44);
    // The padding belongs to the switch, not the navigable harness row.
    await tester.tapAt(tester.getTopLeft(toggleTarget) + const Offset(32, 2));
    await tester.pumpAndSettle();
    verify(
      () => service.command(
        pluginId: "missing",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      ),
    ).called(1);
    expect(opened, isEmpty);
    final install = find.byKey(const Key("harness_management_install_missing"));
    expect(tester.getSize(install).shortestSide, greaterThanOrEqualTo(44));
    await tester.tap(install);
    await tester.pumpAndSettle();
    verify(() => service.command(pluginId: "missing", request: const PluginLifecycleCommandRequest.install()))
        .called(1);
    expect(opened, isEmpty);
    await tester.tap(find.text("missing"));
    expect(opened, ["missing"]);
  });

  testWidgets("global timeout shows progress only for its own all-harness update", (tester) async {
    phone(tester: tester);
    publish(plugins: [_ready]);
    final response = (snapshots.value as PluginManagementLoadResultSupported).response;
    final harnessResult = Completer<PluginManagementMutationResult>();
    when(
      () => service.command(
        pluginId: "ready",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      ),
    ).thenAnswer((_) => harnessResult.future);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final harnessAction = cubit.disable(pluginId: "ready");
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    final timeoutRow = find.byKey(const Key("harness_management_default_timeout"));
    final busyPeerRow = tester.widget<PregoGroupedRow>(timeoutRow);
    expect(busyPeerRow.onTap, isNull);
    expect(busyPeerRow.trailing, isA<Text>().having((text) => text.data, "value", "10 min"));
    harnessResult.complete(PluginManagementMutationResult.success(response: response));
    await harnessAction;
    await tester.pumpAndSettle();

    const input = PluginManagementIdleTimeoutInput.noTimeout();
    const request = PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 0);
    final timeoutResult = Completer<PluginManagementMutationResult>();
    when(() => service.planApplyAllIdleTimeout(input: input)).thenReturn(
      const PluginManagementCommandPlan.request(request: request),
    );
    when(() => service.updateIdleTimeout(request: request)).thenAnswer((_) => timeoutResult.future);
    final timeoutAction = cubit.applyIdleTimeoutToAll(input: input);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(tester.widget<PregoGroupedRow>(timeoutRow).trailing, isA<PregoActivityIndicator>());
    timeoutResult.complete(PluginManagementMutationResult.success(response: response));
    await timeoutAction;
    await tester.pumpAndSettle();
  });

  testWidgets("detail identity keeps its 52px row and a labeled 44px switch target", (tester) async {
    phone(tester: tester);
    publish(plugins: [_ready]);
    await tester.pumpWidget(app(detailId: "ready"));
    await tester.pumpAndSettle();
    // The row includes a one-pixel divider below its 52px content.
    expect(tester.getSize(find.byKey(const Key("harness_management_identity_ready"))).height, 53);
    expect(tester.getSize(find.byKey(const Key("harness_management_enabled_ready"))), const Size(64, 28));
    expect(tester.getSemantics(find.bySemanticsLabel("Ready harness enabled")).rect.height, 44);
  });

  testWidgets("failed detail retains truthful unavailable status and offers a functional retry", (tester) async {
    phone(tester: tester);
    publish(
      plugins: [_plugin(id: "unavailable", runtime: PluginRuntimeState.blocked, setup: PluginSetupState.unavailable)],
    );
    installs.add(const {"unavailable": PluginInstallState.failed()});
    await tester.pumpWidget(app(detailId: "unavailable"));
    await tester.pumpAndSettle();
    expect(find.text("Unavailable"), findsOneWidget);
    expect(find.text("Not installed"), findsNothing);
    expect(find.text("Installation failed"), findsOneWidget);
    final retry = find.byKey(const Key("harness_management_install_unavailable"));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    verify(() => service.command(pluginId: "unavailable", request: const PluginLifecycleCommandRequest.install()))
        .called(1);
    expect(find.byType(PregoBottomSheet), findsNothing);
  });

  testWidgets("install card replaces redundant missing-runtime instructions but preserves manual setup help", (
    tester,
  ) async {
    phone(tester: tester);
    const hint = "Install the harness locally or use Sesori installation.";
    final missing = _plugin(
      id: "missing",
      runtime: PluginRuntimeState.blocked,
      setup: PluginSetupState.runtimeMissing,
    ).copyWith(actionHint: hint);
    publish(plugins: [missing]);
    await tester.pumpWidget(app(detailId: "missing"));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);
    expect(find.text("Start installation"), findsOneWidget);

    publish(
      plugins: [
        missing.copyWith(managementCapabilities: {PluginManagementCapability.lifecycle}),
      ],
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
    expect(find.text("Start installation"), findsNothing);
  });

  testWidgets("disabled missing runtime keeps a false switch and truthful failed-install status", (tester) async {
    phone(tester: tester);
    publish(
      plugins: [_plugin(id: "missing", runtime: PluginRuntimeState.disabled, setup: PluginSetupState.runtimeMissing)],
    );
    installs.add(const {"missing": PluginInstallState.failed()});
    await tester.pumpWidget(app(detailId: "missing"));
    await tester.pumpAndSettle();
    expect(find.text("Not installed"), findsOneWidget);
    expect(find.text("Installation failed"), findsOneWidget);
    expect(tester.widget<PregoSwitch>(find.byKey(const Key("harness_management_enabled_missing"))).value, isFalse);
    expect(find.byKey(const Key("harness_management_restart_missing")), findsNothing);
    expect(find.byKey(const Key("harness_management_refresh_missing")), findsNothing);
  });

  testWidgets("only download percentage is determinate and conflicting switches stay honest", (tester) async {
    phone(tester: tester);
    publish(
      plugins: [_plugin(id: "missing", runtime: PluginRuntimeState.blocked, setup: PluginSetupState.runtimeMissing)],
    );
    installs.add(const {
      "missing": PluginInstallState.inProgress(
        progress: PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 40),
      ),
    });
    await tester.pumpWidget(app(detailId: "missing"));
    await tester.pump();
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, .4);
    final toggle = tester.widget<PregoSwitch>(find.byKey(const Key("harness_management_enabled_missing")));
    expect(toggle.value, isTrue);
    expect(toggle.onChanged, isNull);
    expect(find.byType(PregoButtonsSolid), findsNothing);
    installs.add(const {
      "missing": PluginInstallState.inProgress(
        progress: PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: 40),
      ),
    });
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, isNull);
    expect(find.text("Extracting…"), findsOneWidget);
    expect(find.textContaining("40%"), findsNothing);
  });

  testWidgets("detail selection never substitutes an unknown identity", (tester) async {
    publish(plugins: [_ready]);
    await tester.pumpWidget(app(detailId: "removed"));
    await tester.pumpAndSettle();
    expect(find.text("The harness is no longer registered on this bridge."), findsOneWidget);
    expect(find.text("Ready harness"), findsNothing);
    expect(find.bySemanticsLabel("Back"), findsOneWidget);
    expect(find.bySemanticsLabel("Close settings"), findsOneWidget);
  });

  for (final detail in [false, true]) {
    testWidgets("${detail ? 'detail' : 'overview'} grows at phone width and larger text", (tester) async {
      phone(tester: tester);
      publish(
        plugins: [
          _ready.copyWith(
            setup: _ready.setup.copyWith(state: PluginSetupState.authenticationRequired),
            runtimeState: PluginRuntimeState.blocked,
          ),
        ],
      );
      await tester.pumpWidget(app(detailId: detail ? "ready" : null, scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (detail) {
        publish(plugins: [_ready]);
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key("harness_management_timeout_ready")));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
