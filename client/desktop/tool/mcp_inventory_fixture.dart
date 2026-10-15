/// Native visual fixture. No account, relay, bridge, or persistence is initialized.
library;

import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";
import "package:window_manager/window_manager.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize(warmUpMode: GlassWarmUpMode.never);
  await windowManager.ensureInitialized();
  runApp(const _Fixture());
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: Size(960, 720), title: "MCP visual fixture"),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

const _sessionTitle = "Fixture session";
const _transcript =
    "Inspect the project status.\n\nThe fixture session is ready for inspection.\n\n"
    "Opening MCP inventory keeps this content in place.\n\n"
    "All server names, endpoints, and tools in this fixture are synthetic.";

class const _Fixture() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PregoInteractionScope(
    mode: PregoInteractionMode.pointer,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildPregoThemeData(brightness: Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(PregoSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_sessionTitle, style: context.prego.textTheme.textLg.medium),
                const SizedBox(height: PregoSpacing.lg),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: PregoButtonsSolid(
                    label: context.loc.mcpTitle,
                    leadingIcon: TablerRegular.plug,
                    hierarchy: PregoButtonsSolidHierarchy.secondary,
                    size: PregoButtonsSolidSize.sm,
                    onPressed: () => showMcpInventory(
                      context: context,
                      request: const McpInventoryRequest(pluginId: "fixture", scope: _scope),
                      createService: _FixtureService.new,
                      authenticationService: _ReadOnlyAuthentication.new,
                      mutationsAllowed: false,
                    ),
                  ),
                ),
                const SizedBox(height: PregoSpacing.lg),
                const Expanded(
                  child: SingleChildScrollView(
                    child: Text(_transcript),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

const _scope = McpSessionScope(sessionId: "fixture-session");
final _inventory = McpInventorySnapshot(
  scope: _scope,
  entries: [
    for (var i = 0; i < 24; i++)
      McpServerSnapshot(
        authentication: const McpAuthenticationCapabilityUnknown(),
        credentialForgetting: const McpAuthenticationCapabilityUnknown(),
        actions: const [],
        serverTarget: McpServerTarget(scope: _scope, serverKey: "fixture-$i"),
        name: i == 0 ? "Project tools" : "Fixture server $i",
        description: "Synthetic MCP server",
        endpointOrigin: "https://fixture.example",
        connection: McpConnectionStatus(
          phase: i == 1 ? McpConnectionPhase.authenticationRequired : McpConnectionPhase.connected,
        ),
        authorization: i == 1 ? McpAuthorizationState.required : McpAuthorizationState.unknown,
        configuration: const McpConfigurationSource(
          scope: McpConfigurationScope.project,
          mutability: McpConfigurationMutability.userManaged,
        ),
        tools: const McpToolsAvailable(
          tools: [McpTool(name: "project_status", description: "Read the fixture project status.")],
        ),
      ),
  ],
  servers: const McpCatalogAvailable(),
  connectors: const McpCatalogUnavailable(message: "Fixture catalog unavailable"),
);

class _FixtureService() implements McpService {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
  final _states = BehaviorSubject<McpInventoryState>.seeded(const McpInventoryInitial());
  @override
  ValueStream<McpInventoryState> get states => _states.stream;
  @override
  McpInventoryState get currentState => _states.value;
  @override
  void bind({required McpInventoryRequest request, required bool mutationsAllowed}) =>
      _states.add(McpInventoryReady(inventory: _inventory, refresh: const McpInventoryRefreshIdle()));
  @override
  Future<void> refresh() async {
    _states.add(McpInventoryReady(inventory: _inventory, refresh: const McpInventoryRefreshing()));
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!_states.isClosed) {
      _states.add(
        McpInventoryReady(
          inventory: _inventory,
          refresh: const McpInventoryRefreshUnavailable(
            cause: McpInventoryUnavailable(
              scope: _scope,
              reason: McpInventoryUnavailableReason.readFailed,
              message: "Fixture read failed",
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<void> dispose() => _states.close();
}

class _ReadOnlyAuthentication() implements McpAuthenticationService {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
