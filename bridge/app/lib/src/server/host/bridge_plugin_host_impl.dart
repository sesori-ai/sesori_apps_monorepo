import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeHostInfo,
        HostJsonStore,
        HostPortService,
        HostProcessService,
        PluginConfig,
        PluginHost,
        ProcessIdentity,
        ProcessUser,
        ServerClock,
        StartAbortSignal;

import "../api/loopback_port_api.dart";
import "../api/runtime_file_api.dart";
import "../repositories/process_repository.dart";
import "bridge_host_info_impl.dart";
import "bridge_host_json_store.dart";
import "bridge_host_port_service.dart";
import "bridge_host_process_service.dart";

/// The bridge's production [PluginHost].
///
/// The constructor is pure wiring (tests may inject fakes per service);
/// [create] assembles the production services from the bridge's existing
/// seams and creates [stateDirectory] — the contract promises it exists
/// before the plugin's `start()` runs.
///
/// [create] builds a fresh [RuntimeFileApi] over [stateDirectory]. When the
/// bridge already holds a [RuntimeFileApi] over that directory (OpenCode's
/// `<cacheDir>/runtime`), wire through the plain constructor with a store
/// over the shared instance instead — `RuntimeFileApi.updateFile`'s mutual
/// exclusion is only guaranteed within one instance per directory.
class BridgePluginHostImpl implements PluginHost {
  BridgePluginHostImpl({
    required this.config,
    required this.stateDirectory,
    required this.environment,
    required this.clock,
    required this.startAborted,
    required this.bridge,
    required this.processes,
    required this.ports,
    required this.store,
  });

  static Future<BridgePluginHostImpl> create({
    required PluginConfig config,
    required String stateDirectory,
    required Map<String, String> environment,
    required ServerClock clock,
    required StartAbortSignal startAborted,
    required ProcessIdentity bridgeIdentity,
    required String ownerSessionId,
    required List<ProcessIdentity> terminatedBridgeIdentities,
    required ProcessRepository processRepository,
    required LoopbackPortApi loopbackPortApi,
    required HostProcessStarter processStarter,
    required ProcessUser? currentUser,
    required bool isWindows,
    required String platform,
  }) async {
    if (!p.isAbsolute(stateDirectory)) {
      throw ArgumentError.value(stateDirectory, "stateDirectory", "must be an absolute path");
    }
    await Directory(stateDirectory).create(recursive: true);

    return BridgePluginHostImpl(
      config: config,
      stateDirectory: stateDirectory,
      environment: Map<String, String>.unmodifiable(environment),
      clock: clock,
      startAborted: startAborted,
      bridge: BridgeHostInfoImpl(
        identity: bridgeIdentity,
        ownerSessionId: ownerSessionId,
        terminatedBridgeIdentities: terminatedBridgeIdentities,
        processRepository: processRepository,
      ),
      processes: BridgeHostProcessService(
        processStarter: processStarter,
        processRepository: processRepository,
        clock: clock,
        currentUser: currentUser,
        isWindows: isWindows,
        platform: platform,
      ),
      ports: BridgeHostPortService(loopbackPortApi: loopbackPortApi),
      store: BridgeHostJsonStore(
        fileApi: RuntimeFileApi(runtimeDirectory: stateDirectory),
      ),
    );
  }

  @override
  final PluginConfig config;

  @override
  final String stateDirectory;

  /// Set by the bridge runner from `ensureRuntime`'s [ProvisionReady] result,
  /// after the host is built and before `start()` runs; `null` when the plugin
  /// did no provisioning or it failed.
  @override
  String? provisionedRuntimePath;

  @override
  final Map<String, String> environment;

  @override
  final ServerClock clock;

  @override
  final StartAbortSignal startAborted;

  @override
  final BridgeHostInfo bridge;

  @override
  final HostProcessService processes;

  @override
  final HostPortService ports;

  @override
  final HostJsonStore store;
}
