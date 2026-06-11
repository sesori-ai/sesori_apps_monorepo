import "package:opencode_plugin/opencode_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgePlugin,
        BridgePluginApi,
        BridgePluginDescriptor,
        Log,
        PluginConfig,
        PluginConfigException,
        PluginDiagnostics,
        PluginFlagOption,
        PluginHost,
        PluginOption,
        PluginReady,
        PluginStatus,
        PluginStatusController,
        PluginStopped,
        PluginStopping,
        PluginValueOption,
        ProcessIdentity;
import "package:sesori_shared/sesori_shared.dart";

import "../../server/models/open_code_ownership_record.dart";
import "../../server/repositories/open_code_ownership_repository.dart";
import "../../server/services/open_code_server_service.dart";
import "bridge_runtime_server.dart" show defaultTargetHost;

/// Builds the [BridgePluginApi] for a resolved server. The production
/// default constructs an [OpenCodePlugin]; tests inject a fake.
typedef LegacyPluginApiBuilder = BridgePluginApi Function({required String serverUrl, required String? serverPassword});

OpenCodePlugin _createOpenCodePlugin({required String serverUrl, required String? serverPassword}) {
  return OpenCodePlugin(serverUrl: serverUrl, password: serverPassword);
}

/// Migration-window descriptor that wraps today's exact OpenCode startup
/// flow behind the [BridgePluginDescriptor] seam. No OpenCode lifecycle code
/// moves: `start()` drives the same [OpenCodeServerService] calls the runner
/// used to drive through `resolveServer`, and the returned plugin's
/// `shutdown()` folds in what `registerOwnedOpenCodeShutdown` used to
/// register with the shutdown coordinator.
///
/// Unlike the contract's ideal const descriptor, this one is constructed by
/// the runner *inside* the startup mutex with the legacy services injected —
/// the registration-time surface ([cliOptions], [validateConfigValues]) is
/// exposed statically so `bin/bridge.dart` can declare and validate options
/// at argument-parse time without constructing the heavy flow. A second
/// deliberate divergence: `start()` propagates the legacy
/// `OpenCodeServerStartException` for expected start failures instead of the
/// contract's `PluginStartException` — wrapping would change the logged
/// error text. Nothing may pattern-match `on PluginStartException` against
/// this descriptor. Both divergences resolve with the real, const
/// `OpenCodePluginDescriptor` at the flip (PR 12).
class LegacyOpenCodeDescriptor extends BridgePluginDescriptor {
  const LegacyOpenCodeDescriptor({
    required OpenCodeServerService openCodeServerService,
    required OpenCodeOwnershipRepository ownershipRepository,
    required String ownerSessionId,
    required List<ProcessIdentity> terminatedBridgeIdentities,
    LegacyPluginApiBuilder? buildPluginApi,
  }) : _openCodeServerService = openCodeServerService,
       _ownershipRepository = ownershipRepository,
       _ownerSessionId = ownerSessionId,
       _terminatedBridgeIdentities = terminatedBridgeIdentities,
       _buildPluginApi = buildPluginApi;

  /// The four OpenCode CLI options, names/help/defaults identical to the
  /// flags `bin/bridge.dart` has always declared.
  static const List<PluginOption> cliOptions = [
    PluginValueOption.integer(
      name: "port",
      help: "Port for opencode server to listen on",
      defaultsTo: null,
      valueHelp: null,
    ),
    PluginFlagOption(
      name: "no-auto-start",
      help: "Skip auto-starting opencode server (use existing localhost server)",
      defaultsTo: false,
      negatable: true,
    ),
    PluginValueOption(
      name: "password",
      help: "Override server password (auto-generated if not set)",
      defaultsTo: "",
      allowedValues: null,
      valueHelp: null,
      validate: null,
    ),
    PluginValueOption(
      name: "opencode-bin",
      help: "Path to opencode binary",
      defaultsTo: "opencode",
      allowedValues: null,
      valueHelp: null,
      validate: null,
    ),
  ];

  /// Static counterpart of [validateConfig] so argument-parse-time callers
  /// don't need a constructed descriptor (whose dependencies only exist
  /// later, inside the runner).
  static void validateConfigValues(PluginConfig config) {
    if (config.flag("no-auto-start") && config.intValue("port") == null) {
      throw const PluginConfigException("The --no-auto-start flag requires --port to be set.");
    }
  }

  final OpenCodeServerService _openCodeServerService;
  final OpenCodeOwnershipRepository _ownershipRepository;
  final String _ownerSessionId;
  final List<ProcessIdentity> _terminatedBridgeIdentities;
  final LegacyPluginApiBuilder? _buildPluginApi;

  @override
  String get id => "opencode";

  @override
  String get displayName => "OpenCode";

  @override
  List<PluginOption> get options => cliOptions;

  @override
  void validateConfig(PluginConfig config) => validateConfigValues(config);

  @override
  Future<LegacyOpenCodeBridgePlugin> start(PluginHost host) async {
    final config = host.config;
    final requestedPort = config.intValue("port");
    final password = config.value("password")?.normalize();

    if (config.flag("no-auto-start")) {
      try {
        final runtime = await _openCodeServerService.validateExistingServer(
          port: requestedPort!,
          password: password,
        );
        Log.i("Using existing server at ${runtime.serverUri} (auto-start disabled)");
        return _wrap(
          serverUrl: runtime.serverUri.toString(),
          serverPassword: runtime.serverPassword,
          port: runtime.port,
          ownedOpenCodeRecord: null,
        );
      } on OpenCodeServerStartException catch (error) {
        Log.w(
          "Cannot reach OpenCode at port $requestedPort (auto-start disabled): $error. Bridge will start anyway; start OpenCode manually to enable proxying.",
        );
        return _wrap(
          serverUrl: "$defaultTargetHost:$requestedPort",
          serverPassword: password,
          port: requestedPort!,
          ownedOpenCodeRecord: null,
        );
      }
    }

    Log.d("[OPENCODE] Starting new instance");
    final runtime = await _openCodeServerService.start(
      executablePath: config.value("opencode-bin")!,
      requestedPort: requestedPort,
      password: password,
      terminatedBridgeIdentities: _terminatedBridgeIdentities,
    );

    Log.d("[OPENCODE] Started on port ${runtime.port}");
    final ownedOpenCodeRecord = await _ownershipRepository.readByOwnerSessionId(
      ownerSessionId: _ownerSessionId,
    );

    return _wrap(
      serverUrl: runtime.serverUri.toString(),
      serverPassword: runtime.serverPassword,
      port: runtime.port,
      ownedOpenCodeRecord: ownedOpenCodeRecord?.status == OpenCodeOwnershipStatus.ready ? ownedOpenCodeRecord : null,
    );
  }

  LegacyOpenCodeBridgePlugin _wrap({
    required String serverUrl,
    required String? serverPassword,
    required int port,
    required OpenCodeOwnershipRecord? ownedOpenCodeRecord,
  }) {
    return LegacyOpenCodeBridgePlugin(
      api: (_buildPluginApi ?? _createOpenCodePlugin)(serverUrl: serverUrl, serverPassword: serverPassword),
      serverUrl: serverUrl,
      serverPassword: serverPassword,
      port: port,
      ownedOpenCodeRecord: ownedOpenCodeRecord,
      stopOwnedServer: (record) => _openCodeServerService.stopOwnedServer(record: record),
    );
  }
}

/// Live-plugin wrapper for the legacy OpenCode flow.
///
/// [serverUrl]/[serverPassword] feed `BridgeConfig` until PR 12 removes
/// those fields; [shutdown] runs api teardown then the owned-server stop in
/// order (previously two racing parallel disposables).
class LegacyOpenCodeBridgePlugin implements BridgePlugin {
  LegacyOpenCodeBridgePlugin({
    required this.api,
    required this.serverUrl,
    required this.serverPassword,
    required this.port,
    required OpenCodeOwnershipRecord? ownedOpenCodeRecord,
    required Future<void> Function(OpenCodeOwnershipRecord record) stopOwnedServer,
  }) : _ownedOpenCodeRecord = ownedOpenCodeRecord,
       _stopOwnedServer = stopOwnedServer;

  @override
  final BridgePluginApi api;

  final String serverUrl;
  final String? serverPassword;
  final int port;
  final OpenCodeOwnershipRecord? _ownedOpenCodeRecord;
  final Future<void> Function(OpenCodeOwnershipRecord record) _stopOwnedServer;

  // The legacy flow returns from start() only once the server answered a
  // health probe (or attach mode accepted it degraded-but-addressable), so
  // the wrapper is born Ready. Nothing monitors the runtime after start
  // until PR 12 activates the supervisor's exit monitor, so no Failed /
  // Degraded source exists here.
  final PluginStatusController _status = PluginStatusController(initial: const PluginReady());

  Future<void>? _shutdown;

  @override
  Stream<PluginStatus> get status => _status.stream;

  @override
  PluginStatus get currentStatus => _status.current;

  @override
  PluginDiagnostics describe() {
    return PluginDiagnostics(
      pluginId: "opencode",
      endpoint: serverUrl,
      details: {
        "port": "$port",
        "mode": _ownedOpenCodeRecord == null ? "attached" : "managed",
      },
    );
  }

  /// Stops the plugin: api teardown first, then the owned `opencode serve`
  /// process (when this bridge owns one). Idempotent — repeated calls return
  /// the same future — and safe before/after [BridgePluginApi.dispose],
  /// which the orchestrator still calls directly until PR 12.
  ///
  /// [budget] is accepted but not subdivided: the legacy stop path keeps its
  /// own internal pacing (graceful signal, wait, force). The shutdown
  /// coordinator's backstop, sized from the same budget, bounds the total.
  @override
  Future<void> shutdown({required Duration? budget}) => _shutdown ??= _shutdownNow();

  Future<void> _shutdownNow() async {
    _status.set(const PluginStopping());
    try {
      Object? disposeError;
      StackTrace? disposeStackTrace;
      try {
        await api.dispose();
      } catch (error, stackTrace) {
        // The owned server must still be stopped when api teardown fails —
        // the old parallel registration guaranteed their independence.
        disposeError = error;
        disposeStackTrace = stackTrace;
        Log.e("Plugin api dispose failed: $error");
      }
      final record = _ownedOpenCodeRecord;
      if (record != null) {
        await _stopOwnedServer(record);
      }
      if (disposeError != null) {
        Error.throwWithStackTrace(disposeError, disposeStackTrace!);
      }
    } finally {
      _status.set(const PluginStopped());
    }
  }
}
