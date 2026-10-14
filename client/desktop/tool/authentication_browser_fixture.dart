/// Native visual fixture: synthetic state only; no account, bridge, browser or persistence.
library;

import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
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
    const WindowOptions(size: Size(760, 720), title: "Authentication visual fixture"),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

const _title = "Synthetic sign-in fixture";
const _description = "All destinations and state are fixtures. No website is opened.";

class const _Fixture() extends StatefulWidget {
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState() extends State<_Fixture> {
  final _service = _FixtureService();
  final _scan = FakeCatalogRescanService();
  late final _cubit = PluginManagementCubit(
    service: _service,
    urlLauncher: _FixtureLauncher(),
    catalogRescanService: _scan,
  );

  @override
  void dispose() {
    unawaited(_cubit.close());
    unawaited(_service.onDispose());
    unawaited(_scan.onDispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PregoInteractionScope(
    mode: PregoInteractionMode.pointer,
    child: BlocProvider.value(
      value: _cubit,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HarnessSettingsFlowView(
            child: Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.all(PregoSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_title, style: context.prego.textTheme.textLg.medium),
                    const SizedBox(height: PregoSpacing.lg),
                    PregoButtonsSolid(
                      hierarchy: PregoButtonsSolidHierarchy.secondary,
                      size: PregoButtonsSolidSize.sm,
                      label: "Launch failure",
                      onPressed: () {
                        _service.blocked = false;
                        unawaited(_cubit.startAuthentication(pluginId: "fixture"));
                      },
                    ),
                    const SizedBox(height: PregoSpacing.lg),
                    PregoButtonsSolid(
                      hierarchy: PregoButtonsSolidHierarchy.secondary,
                      size: PregoButtonsSolidSize.sm,
                      label: "Busy browser",
                      onPressed: () {
                        _service.blocked = true;
                        unawaited(_cubit.startAuthentication(pluginId: "fixture"));
                      },
                    ),
                    const SizedBox(height: PregoSpacing.lg),
                    const Text(_description),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final _challenge = PluginAuthenticationBrowserChallenge(
  authorizationUri: Uri.parse("https://fixture.example/authorize"),
  expectedCallbackUri: Uri.parse("http://127.0.0.1:43120/callback"),
);

class _FixtureService() implements PluginManagementService {
  bool blocked = true;
  final _snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
    const PluginManagementLoadResult.supported(
      response: PluginManagementResponse(
        snapshotToken: "fixture",
        bridgeId: "fixture",
        defaultPluginId: "fixture",
        defaultIdleTimeoutMins: 10,
        plugins: [
          PluginManagementMetadata(
            setup: PluginSetupMetadata(
              id: "fixture",
              displayName: "Fixture harness",
              state: PluginSetupState.authenticationRequired,
              runtimeVersion: null,
              actionHint: null,
            ),
            runtimeState: PluginRuntimeState.active,
            workState: PluginManagementWorkState.idle,
            idleTimeoutMins: 10,
            hasIdleTimeoutOverride: false,
            managementCapabilities: {PluginManagementCapability.authentication},
            actionHint: null,
          ),
        ],
      ),
      refreshError: null,
    ),
  );
  final _installs = BehaviorSubject<Map<String, PluginInstallState>>.seeded(const {});
  final _challenges = BehaviorSubject<Map<String, PluginAuthenticationChallenge>>.seeded(const {});
  final _browserStates = BehaviorSubject<Map<String, PluginAuthenticationBrowserState>>.seeded(const {});
  final _terminal = StreamController<PluginAuthenticationTerminalUpdate>.broadcast();
  @override
  ValueStream<PluginManagementLoadResult> get snapshots => _snapshots.stream;
  @override
  ValueStream<Map<String, PluginInstallState>> get installStates => _installs.stream;
  @override
  ValueStream<Map<String, PluginAuthenticationChallenge>> get authenticationChallenges => _challenges.stream;
  @override
  Stream<PluginAuthenticationTerminalUpdate> get authenticationTerminal => _terminal.stream;
  @override
  ValueStream<Map<String, PluginAuthenticationBrowserState>> get authenticationBrowserStates => _browserStates.stream;
  @override
  Future<PluginAuthenticationStartResult> startAuthentication({required String pluginId}) async {
    _browserStates.add({
      pluginId: blocked
          ? const PluginAuthenticationBrowserBlocked()
          : PluginAuthenticationBrowserRetryableFailure(
              failure: PluginAuthenticationBrowserFlowFailed(
                innerError: StateError("Fixture launch failure"),
                stackTrace: StackTrace.current,
                retryableWithActiveListener: true,
              ),
            ),
    });
    _challenges.add({pluginId: _challenge});
    return PluginAuthenticationStartResult.challenge(challenge: _challenge);
  }

  @override
  Future<void> retryBrowserAuthentication({required String pluginId}) async {
    _browserStates.add({pluginId: const PluginAuthenticationBrowserOpening()});
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!_browserStates.isClosed) _browserStates.add({pluginId: const PluginAuthenticationBrowserWaiting()});
  }

  @override
  Future<PluginAuthenticationCancelResult> cancelAuthentication({required String pluginId}) async {
    _terminal.add((pluginId: pluginId, progress: const PluginAuthenticationProgress.cancelled()));
    _challenges.add(const {});
    _browserStates.add(const {});
    return const PluginAuthenticationCancelResult.success();
  }

  @override
  Future<void> onDispose() => Future.wait([
    _snapshots.close(),
    _installs.close(),
    _challenges.close(),
    _browserStates.close(),
    _terminal.close(),
  ]);
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FixtureLauncher() implements UrlLauncher {
  @override
  Future<bool> launch(Uri uri, {UrlLaunchMode mode = UrlLaunchMode.externalApp}) async => false;
}
