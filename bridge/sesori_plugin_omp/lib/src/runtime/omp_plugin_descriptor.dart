import "dart:async";
import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../api/omp_linux_libc_probe_api.dart";
import "../omp_binary.dart";
import "../omp_identity.dart";
import "../omp_plugin_impl.dart";
import "../repositories/omp_runtime_asset_repository.dart";
import "../services/omp_runtime_asset_service.dart";
import "omp_runtime_manifest.dart";

typedef OmpPluginFactory = OmpPlugin Function({
  required String binaryPath,
  required String launchDirectory,
  required String? scratchDirectory,
  required AcpProcessFactory processFactory,
});

typedef OmpRuntimeAssetServiceFactory = OmpRuntimeAssetService Function({
  required CommandExecutor commandExecutor,
  required Duration probeTimeout,
});

OmpRuntimeAssetService _defaultRuntimeAssetService({
  required CommandExecutor commandExecutor,
  required Duration probeTimeout,
}) {
  const manifest = OmpRuntimeManifest();
  return OmpRuntimeAssetService(
    repository: OmpRuntimeAssetRepository(
      api: OmpLinuxLibcProbeApi(
        commandExecutor: commandExecutor,
        alpineMarkerPath: "/etc/alpine-release",
        timeout: probeTimeout,
      ),
      manifest: manifest,
    ),
    manifest: manifest,
  );
}

OmpPlugin _buildOmpPlugin({
  required String binaryPath,
  required String launchDirectory,
  required String? scratchDirectory,
  required AcpProcessFactory processFactory,
}) => OmpPlugin(
  binaryPath: binaryPath,
  launchDirectory: launchDirectory,
  scratchDirectory: scratchDirectory,
  processFactory: processFactory,
);

final class const OmpPluginDescriptor({
  required final OmpPluginFactory _buildPlugin,
  required final OmpRuntimeAssetServiceFactory _buildRuntimeAssetService,
  required final Duration _connectBudget,
  required final Duration _versionProbeTimeout,
}) extends BridgePluginDescriptor {
  factory production() => const OmpPluginDescriptor(
    buildPlugin: _buildOmpPlugin,
    buildRuntimeAssetService: _defaultRuntimeAssetService,
    connectBudget: Duration(seconds: 15),
    versionProbeTimeout: Duration(seconds: 10),
  );

  static const String binOption = "bin";
  static const List<PluginOption> cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to the Oh My Pi CLI binary (omp)",
      defaultsTo: OmpBinary.defaultBinary,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
  ];

  @override
  String get id => OmpPluginIdentity.id;

  @override
  String get displayName => OmpPluginIdentity.displayName;

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.project;

  @override
  bool get supportsPromptAttachments => true;

  @override
  List<PluginOption> get options => cliOptions;

  String? _explicitBin(PluginConfig config) {
    final value = config.value(binOption)?.trim();
    if (value == null || value.isEmpty || value == OmpBinary.defaultBinary) return null;
    return value;
  }

  @override
  Set<PluginControlCapability> managementCapabilities({required PluginConfig config}) {
    if (_explicitBin(config) != null) return super.managementCapabilities(config: config);
    if (_supportsManagedInstall()) {
      return {...super.managementCapabilities(config: config), PluginControlCapability.install};
    }
    return super.managementCapabilities(config: config);
  }

  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    if (_explicitBin(host.config) != null) return;
    const manifest = OmpRuntimeManifest();
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
    const manifest = OmpRuntimeManifest();
    final commandExecutor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: 64 * 1024,
    );
    final runtimeAssetService = _buildRuntimeAssetService(
      commandExecutor: commandExecutor,
      probeTimeout: _versionProbeTimeout,
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
        assetResolver: runtimeAssetService.resolve,
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
    const manifest = OmpRuntimeManifest();
    final explicitBin = _explicitBin(config);
    final selection = await ManagedRuntimeSelectionService(
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
    if (selection case ManagedRuntimeSelected(:final version)) {
      return PluginSetupReady.versioned(runtimeVersion: version.raw);
    }
    final notSelected = selection as ManagedRuntimeNotSelected;
    if (explicitBin != null) {
      return switch (notSelected.primaryRejection) {
        ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) => const PluginSetupRuntimeMissing(
          actionHint: "Fix the configured Oh My Pi CLI path, then restart the bridge.",
        ),
        ManagedRuntimeVersionRejected() => const PluginSetupUnavailable(
          actionHint: "Update the configured Oh My Pi CLI, then restart the bridge.",
        ),
        ManagedRuntimeProbeRejected() => const PluginSetupUnknown(
          actionHint: "Oh My Pi setup could not be determined. Verify the configured CLI and retry.",
        ),
      };
    }
    if (_isUnknownRejection(notSelected.primaryRejection) ||
        _isUnknownRejection(notSelected.managedRejection)) {
      return const PluginSetupUnknown(
        actionHint: "Oh My Pi setup could not be determined. Verify the local CLI and retry.",
      );
    }
    return PluginSetupRuntimeMissing(
      actionHint: _supportsManagedInstall()
          ? "Install Oh My Pi from Sesori, or install it locally and retry setup detection."
          : "Install Oh My Pi locally, then retry setup detection.",
    );
  }

  bool _isUnknownRejection(ManagedRuntimeRejection? rejection) {
    return switch (rejection) {
      ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) || ManagedRuntimeVersionRejected() || null => false,
      ManagedRuntimeProbeRejected() => true,
    };
  }

  bool _supportsManagedInstall() {
    try {
      return const OmpRuntimeManifest().supportsManagedInstallOn(target: PlatformTarget.current());
    } on Object catch (error, stackTrace) {
      Log.w("[omp] platform detection failed; managed install unavailable", error, stackTrace);
      return false;
    }
  }

  RuntimeVersionValidator _versionValidator({required HostProcessService processes}) => RuntimeVersionValidator(
    commandExecutor: HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: 64 * 1024,
    ),
    manifest: const OmpRuntimeManifest(),
    probeTimeout: _versionProbeTimeout,
  );

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    final binaryPath = _explicitBin(host.config) ?? host.provisionedRuntimePath ?? OmpBinary.defaultBinary;
    final omp = _buildPlugin(
      binaryPath: binaryPath,
      launchDirectory: io.Directory.current.path,
      scratchDirectory: null,
      processFactory: hostProcessAcpFactory(processes: host.processes, environment: host.environment),
    );
    return await AcpBridgePlugin.start(plugin: omp, host: host, connectBudget: _connectBudget);
  }
}
