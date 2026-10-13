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

const _scope = McpSessionScope(sessionId: "fixture-session");
const _server = McpServerSnapshot(
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
  setUp(() {
    cubit = _Cubit();
    states = BehaviorSubject.seeded(_ready(entries: [_server], refresh: const McpInventoryRefreshIdle()));
    when(() => cubit.state).thenAnswer((_) => states.value);
    when(() => cubit.stream).thenAnswer((_) => states.stream);
    when(() => cubit.refresh()).thenAnswer((_) async {});
  });
  tearDown(() => states.close());

  Widget app({required double scale}) => MaterialApp(
    theme: buildPregoThemeData(brightness: Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(
      body: BlocProvider<McpCubit>.value(value: cubit, child: const McpInventoryView()),
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
    expect(find.text("Discovery succeeded with no tools."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("refresh failure preserves scroll offset and server rows", (tester) async {
    final entries = [
      for (var i = 0; i < 35; i++)
        McpServerSnapshot(
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
  testWidgets("unrecognized inventory asks for a newer app without a false empty catalog", (tester) async {
    states.add(const McpInventoryUnrecognized());
    await tester.pumpWidget(app(scale: 1));
    await tester.pumpAndSettle();
    expect(find.text("Some inventory information requires a newer app."), findsWidgets);
    expect(find.text("No entries were returned."), findsNothing);
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
