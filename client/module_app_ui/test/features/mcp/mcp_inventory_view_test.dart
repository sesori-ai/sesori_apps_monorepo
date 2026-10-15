import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _Cubit() extends Mock implements McpCubit;
class _Actions() extends Mock implements McpActionCubit;

const _scope = McpSessionScope(sessionId: "fixture-session");
const _offerTarget = McpConnectorOfferTarget(scope: _scope, offerKey: "fixture-offer");
const _offer = McpConnectorOfferSnapshot(
  offerTarget: _offerTarget,
  name: "Fixture connector",
  description: null,
  availability: McpConnectorOfferAvailability.setupRequired,
  actions: [McpConnectorAction.setup],
);
const _server = McpServerSnapshot(
  authentication: McpAuthenticationCapabilityUnknown(),
  credentialForgetting: McpAuthenticationCapabilityUnknown(),
  actions: [],
  serverTarget: McpServerTarget(scope: _scope, serverKey: "fixture-server"),
  name: "Fixture server",
  description: "A configured server",
  endpointOrigin: "https://fixture.example",
  connection: McpConnectionStatus(phase: McpConnectionPhase.connected),
  authorization: McpAuthorizationState.unknown,
  configuration: McpConfigurationSource(
    scope: McpConfigurationScope.project,
    mutability: McpConfigurationMutability.userManaged,
  ),
  tools: McpToolsAvailable(tools: []),
);

McpInventoryReady _ready({required List<McpInventoryEntry> entries, required McpInventoryRefresh refresh}) =>
    McpInventoryReady(
      inventory: McpInventorySnapshot(
        scope: _scope,
        entries: entries,
        servers: const McpCatalogAvailable(),
        connectors: const McpCatalogUnavailable(message: "Unavailable"),
      ),
      refresh: refresh,
    );

void main() {
  late _Cubit cubit;
  late BehaviorSubject<McpInventoryState> states;
  late _Actions actions;
  late BehaviorSubject<McpActionClientState> actionStates;
  setUp(() {
    cubit = _Cubit();
    actions = _Actions();
    actionStates = BehaviorSubject.seeded(const McpActionIdle());
    when(() => actions.state).thenAnswer((_) => actionStates.value);
    when(() => actions.stream).thenAnswer((_) => actionStates.stream);
    when(() => cubit.mutationsAllowed).thenReturn(false);
    states = BehaviorSubject.seeded(_ready(entries: [_server], refresh: const McpInventoryRefreshIdle()));
    when(() => cubit.state).thenAnswer((_) => states.value);
    when(() => cubit.stream).thenAnswer((_) => states.stream);
    when(() => cubit.refresh()).thenAnswer((_) async {});
  });
  tearDown(() async {
    await states.close();
    await actionStates.close();
  });

  Widget app({required double scale}) => MaterialApp(
    theme: buildPregoThemeData(brightness: Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<McpCubit>.value(value: cubit),
          BlocProvider<McpActionCubit>.value(value: actions),
        ],
        child: const McpInventoryView(),
      ),
    ),
  );

  testWidgets("unavailable connectors leave configured servers readable", (tester) async {
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    expect(find.text("Fixture server"), findsOneWidget);
    expect(find.text("This catalog is currently unavailable."), findsOneWidget);
    expect(find.text("No entries were returned."), findsNothing);
    await tester.tap(find.text("Fixture server"));
    await tester.pumpAndSettle();
    expect(find.text("Connected"), findsWidgets);
    expect(find.text("Unknown"), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text("Discovery succeeded with no tools."),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text("Discovery succeeded with no tools."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("setup uses the exact offered target and honors pending/read-only/offline gates", (tester) async {
    states.add(_ready(entries: [_offer], refresh: const McpInventoryRefreshIdle()));
    const action = McpConnectorSetupEntryAction(offerTarget: _offerTarget);
    when(() => actions.execute(action: action)).thenAnswer((_) async {});
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(PregoButtonsSolid, "Open setup");
    expect(tester.widget<PregoButtonsSolid>(button).onPressed, isNull);
    when(() => cubit.mutationsAllowed).thenReturn(true);
    actionStates.add(const McpActionIdle());
    await tester.pumpAndSettle();
    await tester.tap(button);
    verify(() => actions.execute(action: action)).called(1);
    const request = McpEntryActionRequest(pluginId: "fixture", action: action);
    for (final blocked in [
      const McpActionPending(request: request),
      const McpActionOffline(),
      const McpActionsReadOnly(),
    ]) {
      actionStates.add(blocked);
      await tester.pumpAndSettle();
      expect(tester.widget<PregoButtonsSolid>(button).onPressed, isNull);
    }
    actionStates.add(const McpConnectorSetupOpened(request: request));
    await tester.pumpAndSettle();
    expect(find.text("Finish setup in browser, then refresh."), findsOneWidget);
    expect(find.text("Setup required"), findsOneWidget);
    expect(find.text("Connected"), findsNothing);
    expect(tester.widget<PregoButtonsSolid>(button).onPressed, isNotNull);
    states.add(_ready(entries: [_offer], refresh: const McpInventoryRefreshOffline()));
    await tester.pumpAndSettle();
    expect(tester.widget<PregoButtonsSolid>(button).onPressed, isNull);
  });

  testWidgets("offers without a verified setup action give a native-tool handoff", (tester) async {
    states.add(
      _ready(
        entries: [
          const McpConnectorOfferSnapshot(
            offerTarget: _offerTarget,
            name: "Fixture connector",
            description: null,
            availability: McpConnectorOfferAvailability.setupRequired,
          ),
        ],
        refresh: const McpInventoryRefreshIdle(),
      ),
    );
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    expect(find.text("Open setup"), findsNothing);
    expect(find.text("Set up this connector with your coding tool."), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets("phone setup feedback remains usable at text scale $scale", (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      states.add(_ready(entries: [_offer], refresh: const McpInventoryRefreshIdle()));
      when(() => cubit.mutationsAllowed).thenReturn(true);
      actionStates.add(
        const McpConnectorSetupOpened(
          request: McpEntryActionRequest(
            pluginId: "fixture",
            action: McpConnectorSetupEntryAction(offerTarget: _offerTarget),
          ),
        ),
      );
      await tester.pumpWidget(app(scale: scale));
      await tester.pumpAndSettle();
      expect(find.text("Open setup"), findsOneWidget);
      expect(find.text("Finish setup in browser, then refresh."), findsOneWidget);
      expect(tester.takeException(), isNull);
      final animatedRow = find.ancestor(of: find.byType(PregoGroupedRow), matching: find.byType(AnimatedSize)).first;
      final initialHeight = tester.getSize(animatedRow).height;
      states.add(
        _ready(
          entries: [
            const McpConnectorOfferSnapshot(
              offerTarget: _offerTarget,
              name: "Fixture connector",
              description: null,
              availability: McpConnectorOfferAvailability.available,
            ),
          ],
          refresh: const McpInventoryRefreshIdle(),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.getSize(animatedRow).height, initialHeight);
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getSize(animatedRow).height, lessThan(initialHeight));
      await tester.pumpAndSettle();
      expect(find.text("Open setup"), findsNothing);
      expect(find.text("Available"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("refresh failure preserves scroll offset and server rows", (tester) async {
    final entries = [
      for (var i = 0; i < 35; i++)
        McpServerSnapshot(
          authentication: const McpAuthenticationCapabilityUnknown(),
          credentialForgetting: const McpAuthenticationCapabilityUnknown(),
          actions: const [],
          serverTarget: McpServerTarget(scope: _scope, serverKey: "fixture-$i"),
          name: "Server $i",
          description: null,
          endpointOrigin: null,
          connection: _server.connection,
          authorization: _server.authorization,
          configuration: null,
          tools: const McpToolsUnavailable(),
        ),
    ];
    states.add(_ready(entries: entries, refresh: const McpInventoryRefreshIdle()));
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    final offset = scroll.position.pixels;
    states.add(
      _ready(
        entries: entries,
        refresh: McpInventoryRefreshFailed(cause: ApiError.generic()),
      ),
    );
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, offset);
    expect(find.text("Could not refresh. Showing the last inventory."), findsOneWidget);
    actionStates.add(
      const McpConnectorSetupOpened(
        request: McpEntryActionRequest(
          pluginId: "fixture",
          action: McpConnectorSetupEntryAction(offerTarget: _offerTarget),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, offset);
    expect(tester.takeException(), isNull);
  });

  testWidgets("scope unavailability is explicit and offers no mutation", (tester) async {
    states.add(
      const McpInventoryReady(
        inventory: McpInventoryUnavailable(
          scope: McpHarnessScope(),
          reason: McpInventoryUnavailableReason.unsupportedScope,
          message: "Unavailable",
        ),
        refresh: McpInventoryRefreshIdle(),
      ),
    );
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining("Open MCP from a running session"), findsOneWidget);
    expect(find.text("Sign in"), findsNothing);
    await tester.tap(find.byType(PregoButtonsSolid));
    verify(() => cubit.refresh()).called(1);
  });
  testWidgets("offline inventory disables refresh and keeps its servers readable", (tester) async {
    states.add(_ready(entries: [_server], refresh: const McpInventoryRefreshOffline()));
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    expect(tester.widget<PregoButtonsSolid>(find.byType(PregoButtonsSolid)).onPressed, isNull);
    expect(find.text("Fixture server"), findsOneWidget);
    await tester.tap(find.text("Fixture server"));
    await tester.pumpAndSettle();
    expect(find.text("Offline. Showing the last inventory."), findsWidgets);
    expect(tester.widget<PregoButtonsSolid>(find.byType(PregoButtonsSolid).last).onPressed, isNull);
    verifyNever(() => cubit.refresh());
  });

  testWidgets("details distinguish removed servers and failed reads", (tester) async {
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Fixture server"));
    await tester.pumpAndSettle();
    states.add(_ready(entries: [], refresh: const McpInventoryRefreshIdle()));
    await tester.pumpAndSettle();
    expect(find.text("This server is no longer in the inventory."), findsOneWidget);
    states.add(
      const McpInventoryReadFailed(
        cause: McpInventoryUnavailable(
          scope: _scope,
          reason: McpInventoryUnavailableReason.readFailed,
          message: "Unavailable",
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Could not read inventory. Try refreshing."), findsWidgets);
    expect(find.text("This server is no longer in the inventory."), findsNothing);
    expect(find.text("Inventory is unavailable."), findsNothing);
  });

  testWidgets("failed refresh remains visible above retained server details", (tester) async {
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Fixture server"));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).last);
    final offset = scroll.position.pixels;
    states.add(
      _ready(
        entries: [_server],
        refresh: McpInventoryRefreshFailed(cause: ApiError.generic()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Could not refresh. Showing the last inventory."), findsWidgets);
    expect(find.text("Connected"), findsWidgets);
    expect(scroll.position.pixels, offset);
    expect(tester.takeException(), isNull);
  });
  testWidgets("unrecognized inventory asks for a newer app without a false empty catalog", (tester) async {
    states.add(const McpInventoryUnrecognized());
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    expect(find.text("Some inventory information requires a newer app."), findsWidgets);
    expect(find.text("No entries were returned."), findsNothing);
  });

  testWidgets("unknown entries never produce a successful empty-catalog claim", (tester) async {
    states.add(
      const McpInventoryReady(
        inventory: McpInventorySnapshot(
          scope: _scope,
          entries: [McpUnknownInventoryEntry()],
          servers: McpCatalogAvailable(),
          connectors: McpCatalogAvailable(),
        ),
        refresh: McpInventoryRefreshIdle(),
      ),
    );
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    expect(find.text("No entries were returned."), findsNothing);
    expect(find.text("Some inventory information requires a newer app."), findsOneWidget);
    states.add(_ready(entries: [_server, const McpUnknownInventoryEntry()], refresh: const McpInventoryRefreshIdle()));
    await tester.pumpAndSettle();
    expect(find.text("Fixture server"), findsOneWidget);
    expect(find.text("Some inventory information requires a newer app."), findsOneWidget);
  });

  testWidgets("phone width with larger text keeps refresh and server details reachable", (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text("Fixture server"));
    await tester.pumpAndSettle();
    expect(find.text("Server details"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
