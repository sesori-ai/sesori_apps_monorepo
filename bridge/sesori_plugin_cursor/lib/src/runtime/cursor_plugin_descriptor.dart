import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show BinaryDownloadClient, CommandResult, HostProcessCommandExecutor, PlatformTarget, stripAnsi;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;

import "../api/cursor_session_storage_api.dart";
import "../cursor_binary.dart";
import "../cursor_plugin_impl.dart";
import "../repositories/cursor_session_storage_repository.dart";
import "../services/cursor_session_cleanup_service.dart";
import "cursor_runtime_manifest.dart";

const int _setupProbeOutputLimit = 64 * 1024;

/// Builds the [CursorPlugin] (the live [BridgePluginApi]) for a resolved
/// binary. The production default constructs the real plugin wired to the
/// host-backed process factory; tests inject a fake to avoid spawning the
/// Cursor CLI.
typedef CursorPluginFactory = CursorPlugin Function({
  required String binaryPath,
  required String launchDirectory,
  required String? apiEndpoint,
  required AcpProcessFactory processFactory,
  required CursorSessionCleanupService sessionCleanupService,
});

CursorPlugin _defaultBuildPlugin({
  required String binaryPath,
  required String launchDirectory,
  required String? apiEndpoint,
  required AcpProcessFactory processFactory,
  required CursorSessionCleanupService sessionCleanupService,
}) {
  return CursorPlugin(
    binaryPath: binaryPath,
    launchDirectory: launchDirectory,
    apiEndpoint: apiEndpoint,
    processFactory: processFactory,
    sessionCleanupService: sessionCleanupService,
  );
}

/// The const Cursor plugin descriptor.
///
/// Cursor drives a `cursor-agent acp` stdio subprocess over the generic ACP
/// machinery, so it needs no managed-runtime supervisor (no listening port to
/// reclaim, no ownership file). It declares its CLI surface, probes the
/// Cursor CLI binary for availability, and on [start] spawns the agent
/// through the [PluginHost] process seam and returns an [AcpBridgePlugin].
///
/// The optional constructor parameters are test seams; the registered instance
/// is `const CursorPluginDescriptor()`.
class const CursorPluginDescriptor({
  final CursorPluginFactory? _buildPlugin,
  final Duration _connectBudget = const Duration(seconds: 15),
  final Duration _versionProbeTimeout = const Duration(seconds: 10),

  /// Test seam for existing-runtime resolution. Production builds a default in
  /// [ensureRuntime] from the host's process service.
  final ManagedRuntimeProvisionService? _provisionService,
}) extends BridgePluginDescriptor {
  /// Minimum Cursor CLI build the bridge supports, owned by
  /// [CursorRuntimeManifest.minPathVersion]. Earlier builds (e.g.
  /// `2026.05.28`) advertise the `acp` model picker and `session/load` but
  /// silently no-op model switching and history replay, so the experience is
  /// broken in ways the user can't see.
  static String get minVersion => const CursorRuntimeManifest().minPathVersion.raw;

  /// CLI option naming the Cursor CLI binary (path or PATH name). Declared
  /// as the bare local name — the bridge's [PluginCliOptionsMapper] namespaces
  /// it to the public `--cursor-bin` flag.
  static const String binOption = "bin";

  /// CLI option overriding the Cursor API endpoint (passed as `-e <endpoint>`).
  /// Bare local name; surfaces publicly as `--cursor-api-endpoint`.
  static const String apiEndpointOption = "api-endpoint";

  static const List<PluginOption> cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to the Cursor CLI binary (cursor-agent)",
      defaultsTo: CursorBinary.defaultBinary,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
    PluginValueOption(
      name: apiEndpointOption,
      help: "Override the Cursor API endpoint (passed to the Cursor CLI as -e <endpoint>)",
      defaultsTo: null,
      allowedValues: null,
      valueHelp: "url",
      validate: null,
    ),
  ];

  @override
  String get id => Harness.cursor.name;

  @override
  String get displayName => "Cursor";

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.plugin;

  @override
  bool get supportsPromptAttachments => true;

  @override
  List<PluginOption> get options => cliOptions;

  /// The explicit `--cursor-bin` override, or null when unset, empty, or left
  /// at the bare default (which means "resolve via [ensureRuntime]": a
  /// recent-enough PATH CLI or the pinned managed runtime).
  String? _explicitBin(PluginConfig config) {
    final value = config.value(binOption)?.trim();
    if (value == null || value.isEmpty || value == CursorBinary.defaultBinary) return null;
    return value;
  }

  @override
  Set<PluginControlCapability> managementCapabilities({required PluginConfig config}) {
    return {
      ...super.managementCapabilities(config: config),
      if (_supportsManagedInstall(config: config)) PluginControlCapability.install,
    };
  }

  /// Whether the pinned managed Cursor CLI can be installed on request: no
  /// explicit binary override and a published package for this platform.
  /// Cursor publishes darwin and linux only, so Windows never advertises it.
  bool _supportsManagedInstall({required PluginConfig config}) {
    if (_explicitBin(config) != null) return false;
    final PlatformTarget target;
    try {
      target = PlatformTarget.current();
    } on Object catch (error, stackTrace) {
      Log.w("[cursor] platform detection failed; managed install unavailable", error, stackTrace);
      return false;
    }
    return const CursorRuntimeManifest().supportsManagedInstallOn(target: target);
  }

  /// Resolves an existing Cursor CLI (a recent-enough PATH install or the
  /// pinned managed runtime when already installed). Skipped when an explicit
  /// `--cursor-bin` is set. The resolved path reaches [start] through
  /// [PluginHost.provisionedRuntimePath].
  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    if (_explicitBin(host.config) != null) return;

    final injected = _provisionService;
    if (injected != null) {
      yield* injected.provision(host: host, explicitExecutablePath: null);
      return;
    }
    yield* _buildDefaultProvisionService(host: host).provision(host: host, explicitExecutablePath: null);
  }

  ManagedRuntimeProvisionService _buildDefaultProvisionService({required PluginHost host}) {
    const manifest = CursorRuntimeManifest();
    return const ManagedRuntimeComposition().createProvisioner(
      manifest: manifest,
      versionValidator: _versionValidatorFor(
        processes: host.processes,
        maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
      ),
      // Cursor has no desktop-app-bundled CLI to fall back to.
      fallbackExecutableCandidates: const [],
    );
  }

  @override
  bool needsManagedRuntimeUpgrade({required PluginConfig config, required String stateDirectory}) {
    if (!managementCapabilities(config: config).contains(PluginControlCapability.install)) return false;
    return const ManagedRuntimeInventory(
      manifest: CursorRuntimeManifest(),
    ).hasSupersededVersion(stateDirectory: stateDirectory);
  }

  @override
  Stream<RuntimeProvisionProgress> installRuntime({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal startAborted,
    required RuntimeInUseSignal runtimeInUse,
  }) async* {
    const manifest = CursorRuntimeManifest();
    final commandExecutor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: null,
    );
    final httpClient = http.Client();
    try {
      final installService = const ManagedRuntimeComposition().createInstaller(
        manifest: manifest,
        commandExecutor: commandExecutor,
        downloadClient: BinaryDownloadClient(httpClient: httpClient),
        versionValidator: _versionValidatorFor(
          processes: processes,
          maxCapturedOutputCharactersPerStream: null,
        ),
        assetResolver: ({required target}) async => manifest.assetFor(target: target),
      );
      yield* installService.install(
        environment: environment,
        stateDirectory: stateDirectory,
        startAborted: startAborted,
        runtimeInUse: runtimeInUse,
      );
    } finally {
      httpClient.close();
    }
  }

  /// Version probing for the Cursor CLI. Its `--version` prints a bare calendar
  /// build (`2026.08.11-e8db854`), which the shared validator parses.
  RuntimeVersionValidator _versionValidatorFor({
    required HostProcessService processes,
    required int? maxCapturedOutputCharactersPerStream,
  }) {
    return RuntimeVersionValidator(
      commandExecutor: HostProcessCommandExecutor(
        processes: processes,
        runInShell: io.Platform.isWindows,
        maxCapturedOutputCharactersPerStream: maxCapturedOutputCharactersPerStream,
      ),
      manifest: const CursorRuntimeManifest(),
      probeTimeout: _versionProbeTimeout,
    );
  }

  @override
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    final explicitBin = _explicitBin(config);
    final selection =
        await ManagedRuntimeSelectionService(
          manifest: const CursorRuntimeManifest(),
          versionValidator: _versionValidatorFor(
            processes: processes,
            maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
          ),
          inventory: const ManagedRuntimeInventory(manifest: CursorRuntimeManifest()),
        ).select(
          explicitExecutablePath: explicitBin,
          fallbackExecutableCandidates: const [],
          environment: environment,
          stateDirectory: stateDirectory,
          abortSignal: StartAbortSignal.never,
        );

    /// What to tell the user when nothing usable was found and Sesori can
    /// install the runtime itself.
    String missingRuntimeHint() {
      if (!_supportsManagedInstall(config: config)) {
        return "Install the Cursor CLI locally, then retry setup detection.";
      }
      const inventory = ManagedRuntimeInventory(manifest: CursorRuntimeManifest());
      return inventory.hasSupersededVersion(stateDirectory: stateDirectory)
          ? "This bridge needs a newer Cursor CLI. Install it from Sesori to update the managed runtime."
          : "Install the Cursor CLI from Sesori, or install it locally and retry setup detection.";
    }

    if (selection is ManagedRuntimeNotSelected) {
      if (explicitBin != null) {
        return switch (selection.primaryRejection) {
          ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) => const PluginSetupRuntimeMissing(
            actionHint: "Fix the configured Cursor CLI path, then restart the bridge.",
          ),
          ManagedRuntimeVersionRejected() => const PluginSetupUnavailable(
            actionHint: "The configured Cursor CLI is too old. Update it and restart the bridge.",
          ),
          ManagedRuntimeProbeRejected() => const PluginSetupUnknown(
            actionHint: "Cursor setup could not be determined. Verify the local CLI and retry.",
          ),
        };
      }
      if (selection.primaryRejection
          case ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) || ManagedRuntimeVersionRejected()) {
        return PluginSetupRuntimeMissing(actionHint: missingRuntimeHint());
      }
      return const PluginSetupUnknown(
        actionHint: "Cursor setup could not be determined. Verify the local CLI and retry.",
      );
    }
    final selected = selection as ManagedRuntimeSelected;
    final executablePath = selected.binaryPath;
    final runtimeVersion = selected.version.raw;
    Log.d("[cursor] available: '$executablePath --version' -> $runtimeVersion");

    if (environment["CURSOR_API_KEY"]?.trim().isNotEmpty ?? false) {
      return PluginSetupReady.versioned(runtimeVersion: runtimeVersion);
    }
    final executor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );
    final CommandResult statusResult;
    try {
      statusResult = await executor.run(
        executablePath,
        const ["status"],
        environment: environment,
        timeout: _versionProbeTimeout,
      );
    } on Object {
      return PluginSetupUnknown.versioned(
        actionHint:
            "Cursor authentication could not be determined. Run the Cursor CLI status command locally and retry.",
        runtimeVersion: runtimeVersion,
      );
    }
    final statusOutput = _normalizedStatusOutput(statusResult);
    if (statusOutput.contains("not authenticated") ||
        statusOutput.contains("unauthenticated") ||
        statusOutput.contains("not logged in") ||
        statusOutput.contains("logged out")) {
      return PluginSetupAuthenticationRequired.versioned(
        actionHint: "Log in with the Cursor CLI on this machine, then retry setup detection.",
        runtimeVersion: runtimeVersion,
      );
    }
    if (statusResult.exitCode == 0 && (statusOutput.contains("authenticated") || statusOutput.contains("logged in"))) {
      return PluginSetupReady.versioned(runtimeVersion: runtimeVersion);
    }
    return PluginSetupUnknown.versioned(
      actionHint: "Cursor authentication could not be determined. Run the Cursor CLI status command locally and retry.",
      runtimeVersion: runtimeVersion,
    );
  }

  String _normalizedStatusOutput(CommandResult result) {
    final combined = "${result.stdout}\n${result.stderr}";
    return stripAnsi(value: combined).trim().toLowerCase();
  }

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    final config = host.config;
    // Precedence: an explicit --cursor-bin wins, then whatever ensureRuntime
    // resolved (a recent PATH CLI or the pinned managed runtime), then the
    // bare PATH name so a failed resolution still produces a clear spawn error.
    final binaryPath = _explicitBin(config) ?? host.provisionedRuntimePath ?? CursorBinary.defaultBinary;
    final rawEndpoint = config.value(apiEndpointOption)?.trim();
    final apiEndpoint = (rawEndpoint == null || rawEndpoint.isEmpty) ? null : rawEndpoint;

    // Route the agent subprocess through the host process seam rather than
    // io.Process.start, so the bridge owns identity capture and signalling.
    final processFactory = hostProcessAcpFactory(
      processes: host.processes,
      environment: host.environment,
    );
    final sessionCleanupService = CursorSessionCleanupService(
      repository: CursorSessionStorageRepository(
        api: const CursorSessionStorageApi(),
      ),
      environment: host.environment,
    );

    final cursor = (_buildPlugin ?? _defaultBuildPlugin)(
      binaryPath: binaryPath,
      // The bridge seeds the launch directory as an always-present project;
      // the bridge itself owns all project/session persistence for this
      // derive-style plugin, so the plugin needs no store of its own.
      launchDirectory: io.Directory.current.path,
      apiEndpoint: apiEndpoint,
      processFactory: processFactory,
      sessionCleanupService: sessionCleanupService,
    );
    // Eagerly spawns the agent and runs the ACP handshake (bounded), so the
    // first mobile request is fast and the status reflects reality; a
    // timeout/failure leaves the plugin degraded rather than failing the bridge,
    // and an abort that lands while connecting is rolled back.
    return await AcpBridgePlugin.start(plugin: cursor, host: host, connectBudget: _connectBudget);
  }
}
