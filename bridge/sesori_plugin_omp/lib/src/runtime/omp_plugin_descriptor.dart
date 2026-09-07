import "dart:async";
import "dart:convert";
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

const int _setupProbeOutputLimit = 64 * 1024;

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
  bool needsManagedRuntimeUpgrade({required PluginConfig config, required String stateDirectory}) {
    if (!managementCapabilities(config: config).contains(PluginControlCapability.install)) return false;
    return const ManagedRuntimeInventory(
      manifest: OmpRuntimeManifest(),
    ).hasSupersededVersion(stateDirectory: stateDirectory);
  }

  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    if (_explicitBin(host.config) != null) return;
    const manifest = OmpRuntimeManifest();
    yield* const ManagedRuntimeComposition()
        .createProvisioner(
          manifest: manifest,
          versionValidator: _versionValidator(processes: host.processes),
          fallbackExecutableCandidates: const [],
        )
        .provision(host: host, explicitExecutablePath: null);
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
      final service = const ManagedRuntimeComposition().createInstaller(
        manifest: manifest,
        commandExecutor: commandExecutor,
        downloadClient: BinaryDownloadClient(httpClient: httpClient),
        versionValidator: _versionValidator(processes: processes),
        assetResolver: runtimeAssetService.resolve,
      );
      yield* service.install(
        environment: environment,
        stateDirectory: stateDirectory,
        startAborted: startAborted,
        runtimeInUse: runtimeInUse,
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
    final selection =
        await ManagedRuntimeSelectionService(
          manifest: manifest,
          versionValidator: _versionValidator(processes: processes),
          inventory: const ManagedRuntimeInventory(manifest: manifest),
        ).select(
          explicitExecutablePath: explicitBin,
          fallbackExecutableCandidates: const [],
          environment: environment,
          stateDirectory: stateDirectory,
          abortSignal: StartAbortSignal.never,
        );
    if (selection case ManagedRuntimeSelected(:final binaryPath, :final version)) {
      return await _inspectAuthentication(
        binaryPath: binaryPath,
        processes: processes,
        environment: environment,
        runtimeVersion: version.raw,
      );
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
    final automatic = notSelected as ManagedRuntimeAutomaticNotSelected;
    if (_isUnknownRejection(automatic.primaryRejection) || _isUnknownRejection(automatic.managedRejection)) {
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

  /// Asks Oh My Pi which models it can actually use.
  ///
  /// OMP resolves credentials from its auth broker, its profile settings, and
  /// the environment, so only OMP itself can answer whether any provider is
  /// usable. Listing models neither starts a backend nor initiates
  /// authentication.
  Future<PluginSetupStatus> _inspectAuthentication({
    required String binaryPath,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String runtimeVersion,
  }) async {
    final CommandResult result;
    try {
      result = await HostProcessCommandExecutor(
        processes: processes,
        runInShell: io.Platform.isWindows,
        maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
      ).run(binaryPath, const ["models", "--json"], environment: environment, timeout: _versionProbeTimeout);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[${OmpPluginIdentity.id}] model listing probe failed for '$binaryPath models --json'",
        error,
        stackTrace,
      );
      return PluginSetupUnknown.versioned(
        actionHint: "Oh My Pi could not list its available models. Verify the local CLI and retry.",
        runtimeVersion: runtimeVersion,
      );
    }
    if (!_listedNoModels(result)) return PluginSetupReady.versioned(runtimeVersion: runtimeVersion);
    return PluginSetupAuthenticationRequired.versioned(
      actionHint: "Run `omp` on this machine and log into a provider, then retry setup detection.",
      runtimeVersion: runtimeVersion,
    );
  }

  /// Whether the listing positively reported an empty catalog.
  ///
  /// Only a listing that parses and reports no models counts as logged out.
  /// Supported releases predate the pinned target and `models --json` is not
  /// guaranteed across that range, so an unrecognized listing leaves setup
  /// ready rather than downgrading a working install on evidence that is not
  /// there.
  bool _listedNoModels(CommandResult result) {
    if (result.exitCode != 0) return false;
    final Object? decoded;
    try {
      decoded = jsonDecode(result.stdout);
    } on FormatException {
      return false;
    }
    return switch (decoded) {
      {"models": final List<Object?> models} => models.isEmpty,
      _ => false,
    };
  }

  bool _isUnknownRejection(ManagedRuntimeRejection rejection) {
    return switch (rejection) {
      ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) || ManagedRuntimeVersionRejected() => false,
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
