import "dart:async";
import "dart:io" as io;

import "package:http/http.dart" as http;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../api/pi_process_factory.dart";
import "../pi_identity.dart";
import "../pi_plugin_impl.dart";
import "pi_bridge_plugin.dart";
import "pi_runtime_manifest.dart";

typedef PiPluginFactory = PiPlugin Function({
  required String binaryPath,
  required Map<String, String> storageEnvironment,
  required Map<String, String> processEnvironment,
  required PiProcessFactory processFactory,
  required CommandExecutor commandExecutor,
  required ServerClock clock,
  required String launchDirectory,
  required Duration startupExitTimeout,
  required Duration historyRpcTimeout,
  required Duration catalogTimeout,
  required Duration healthTimeout,
  required Duration? Function() resolveIdleTimeout,
  required Duration editorTimeout,
  required PluginAgentToolServices? agentToolServices,
});

PiPlugin _buildPiPlugin({
  required String binaryPath,
  required Map<String, String> storageEnvironment,
  required Map<String, String> processEnvironment,
  required PiProcessFactory processFactory,
  required CommandExecutor commandExecutor,
  required ServerClock clock,
  required String launchDirectory,
  required Duration startupExitTimeout,
  required Duration historyRpcTimeout,
  required Duration catalogTimeout,
  required Duration healthTimeout,
  required Duration? Function() resolveIdleTimeout,
  required Duration editorTimeout,
  required PluginAgentToolServices? agentToolServices,
}) => PiPlugin(
  binaryPath: binaryPath,
  storageEnvironment: storageEnvironment,
  processEnvironment: processEnvironment,
  processFactory: processFactory,
  commandExecutor: commandExecutor,
  clock: clock,
  launchDirectory: launchDirectory,
  startupExitTimeout: startupExitTimeout,
  historyRpcTimeout: historyRpcTimeout,
  catalogTimeout: catalogTimeout,
  healthTimeout: healthTimeout,
  resolveIdleTimeout: resolveIdleTimeout,
  editorTimeout: editorTimeout,
  agentToolServices: agentToolServices,
);

/// Descriptor and lifecycle composition root for the local Pi CLI plugin.
final class const PiPluginDescriptor({
  required final PiPluginFactory _buildPlugin,
  required final Duration _versionProbeTimeout,
  required final Duration _statusDebounce,
}) extends BridgePluginDescriptor {
  factory production() => const PiPluginDescriptor(
    buildPlugin: _buildPiPlugin,
    versionProbeTimeout: Duration(seconds: 10),
    statusDebounce: Duration(seconds: 5),
  );

  static const String binOption = "bin";
  static const List<PluginOption> cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to the Pi CLI binary",
      defaultsTo: null,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
  ];

  @override
  String get id => PiPluginIdentity.id;

  @override
  String get displayName => PiPluginIdentity.displayName;

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.project;

  @override
  bool get supportsPromptAttachments => true;

  /// Pi owns idle reclamation per session: each RPC child is reaped on the
  /// user-configured timeout and resumed transparently on the next turn.
  /// Whole-plugin suspension would duplicate that timer and can race the
  /// per-session teardown, so the adapter remains resident like Claude Code.
  @override
  PluginResidencyPolicy residencyPolicy({required PluginConfig config}) => PluginResidencyPolicy.resident;

  @override
  List<PluginOption> get options => cliOptions;

  String? _explicitBin(PluginConfig config) {
    final value = config.value(binOption)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Set<PluginControlCapability> managementCapabilities({required PluginConfig config}) => {
    ...super.managementCapabilities(config: config),
    if (_supportsManagedInstall(config: config)) PluginControlCapability.install,
  };

  bool _supportsManagedInstall({required PluginConfig config}) {
    if (_explicitBin(config) != null) return false;
    try {
      return const PiRuntimeManifest().supportsManagedInstallOn(target: PlatformTarget.current());
    } on Object catch (error, stackTrace) {
      Log.w("[pi] platform detection failed; managed install unavailable", error, stackTrace);
      return false;
    }
  }

  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    if (_explicitBin(host.config) != null) return;
    const manifest = PiRuntimeManifest();
    yield* ManagedRuntimeProvisionService(
      manifest: manifest,
      selectionService: ManagedRuntimeSelectionService(
        manifest: manifest,
        versionValidator: _versionValidator(processes: host.processes),
      ),
      fallbackExecutableCandidates: const [],
    ).provision(host: host, explicitExecutablePath: null);
  }

  @override
  Stream<RuntimeProvisionProgress> installRuntime({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal startAborted,
  }) async* {
    const manifest = PiRuntimeManifest();
    final commandExecutor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: 64 * 1024,
    );
    final httpClient = http.Client();
    try {
      final service = ManagedRuntimeInstallService(
        manifest: manifest,
        versionValidator: _versionValidator(processes: processes),
        installService: RuntimeInstallService(
          downloadClient: BinaryDownloadClient(httpClient: httpClient),
          checksumValidator: ChecksumValidator(),
          archiveExtractor: ArchiveExtractor(commandExecutor: commandExecutor),
          commandExecutor: commandExecutor,
          runtimeId: manifest.runtimeId,
        ),
        cleaner: ManagedRuntimeCleaner(runtimeId: manifest.runtimeId),
        assetResolver: ({required target}) async => manifest.assetFor(target: target),
      );
      yield* service.install(
        environment: environment,
        stateDirectory: stateDirectory,
        startAborted: startAborted,
      );
    } finally {
      httpClient.close();
    }
  }

  @override
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    const manifest = PiRuntimeManifest();
    final explicitBin = _explicitBin(config);
    final selection =
        await ManagedRuntimeSelectionService(
          manifest: manifest,
          versionValidator: _versionValidator(processes: processes),
        ).select(
          explicitExecutablePath: explicitBin,
          fallbackExecutableCandidates: const [],
          environment: environment,
          stateDirectory: stateDirectory,
          abortSignal: StartAbortSignal.never,
          managedVersionPolicy: ManagedRuntimeVersionPolicy.exact,
        );
    if (selection is ManagedRuntimeSelected) return const PluginSetupReady();
    final notSelected = selection as ManagedRuntimeNotSelected;
    if (explicitBin != null) {
      return switch (notSelected.primaryRejection) {
        ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) => const PluginSetupRuntimeMissing(
          actionHint: "Fix the configured Pi CLI path, then restart the bridge.",
        ),
        ManagedRuntimeVersionRejected() => const PluginSetupUnavailable(
          actionHint: "Update the configured Pi CLI, then restart the bridge.",
        ),
        ManagedRuntimeProbeRejected() => const PluginSetupUnknown(
          actionHint: "Pi setup could not be determined. Verify the configured CLI and retry.",
        ),
      };
    }
    final automatic = notSelected as ManagedRuntimeAutomaticNotSelected;
    if (_isUnknownRejection(automatic.primaryRejection) || _isUnknownRejection(automatic.managedRejection)) {
      return const PluginSetupUnknown(
        actionHint: "Pi setup could not be determined. Verify the local CLI and retry.",
      );
    }
    return PluginSetupRuntimeMissing(
      actionHint: _supportsManagedInstall(config: config)
          ? "Install Pi from Sesori, or install it locally and retry setup detection."
          : "Install Pi locally, then retry setup detection.",
    );
  }

  bool _isUnknownRejection(ManagedRuntimeRejection rejection) {
    return switch (rejection) {
      ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) || ManagedRuntimeVersionRejected() => false,
      ManagedRuntimeProbeRejected() => true,
    };
  }

  RuntimeVersionValidator _versionValidator({required HostProcessService processes}) => RuntimeVersionValidator(
    commandExecutor: HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: 64 * 1024,
    ),
    manifest: const PiRuntimeManifest(),
    probeTimeout: _versionProbeTimeout,
  );

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    const manifest = PiRuntimeManifest();
    final binaryPath = _explicitBin(host.config) ?? host.provisionedRuntimePath ?? manifest.pathExecutableName;
    final processFactory = HostPiProcessFactory(processes: host.processes);
    final commandExecutor = HostProcessCommandExecutor(
      processes: host.processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: 64 * 1024,
    );
    final PiPlugin plugin;
    try {
      plugin = _buildPlugin(
        binaryPath: binaryPath,
        storageEnvironment: host.environment,
        processEnvironment: const {},
        processFactory: processFactory.spawn,
        commandExecutor: commandExecutor,
        clock: host.clock,
        launchDirectory: io.Directory.current.path,
        startupExitTimeout: const Duration(seconds: 5),
        historyRpcTimeout: const Duration(minutes: 2),
        catalogTimeout: const Duration(seconds: 30),
        healthTimeout: const Duration(seconds: 10),
        resolveIdleTimeout: () => host.pluginIdleTimeout,
        editorTimeout: const Duration(minutes: 30),
        agentToolServices: host.agentToolServices,
      );
    } on Object {
      await processFactory.dispose();
      rethrow;
    }
    final bridgePlugin = PiBridgePlugin(
      plugin: plugin,
      processFactory: processFactory,
      clock: host.clock,
      statusDebounce: _statusDebounce,
    );
    if (!host.startAborted.isAborted) return bridgePlugin;
    try {
      await bridgePlugin.shutdown(budget: null);
    } on Object catch (error, stackTrace) {
      Log.e("[pi] rollback after aborted start failed", error, stackTrace);
    }
    throw const PluginStartAbortedException();
  }
}
