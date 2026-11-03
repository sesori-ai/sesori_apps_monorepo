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
    return {
      ...super.managementCapabilities(config: config),
      if (_explicitBin(config) == null && _supportsManagedInstall()) PluginControlCapability.install,
    };
  }

  @override
  Future<bool> needsManagedRuntimeUpgrade({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    if (!managementCapabilities(config: config).contains(PluginControlCapability.install)) return false;
    const manifest = OmpRuntimeManifest();
    return await const ManagedRuntimeComposition()
        .createUpgradeService(
          manifest: manifest,
          versionValidator: _versionValidator(processes: processes),
        )
        .shouldUpgrade(environment: environment, stateDirectory: stateDirectory);
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
    final commandExecutor = _commandExecutor(processes: processes);
    final runtimeAssetService = _buildRuntimeAssetService(
      commandExecutor: commandExecutor,
      probeTimeout: _versionProbeTimeout,
    );
    final versionValidator = _versionValidator(processes: processes);
    final httpClient = http.Client();
    try {
      final service = const ManagedRuntimeComposition().createInstaller(
        manifest: manifest,
        commandExecutor: commandExecutor,
        downloadClient: BinaryDownloadClient(httpClient: httpClient),
        candidateValidator: versionValidator,
        pathAuthority: RuntimeVersionManagedRuntimePathAuthority(
          manifest: manifest,
          versionValidator: versionValidator,
        ),
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
    return switch (selection) {
      ManagedRuntimeSelected(:final binaryPath, :final version) => await _inspectAuthentication(
        binaryPath: binaryPath,
        processes: processes,
        environment: environment,
        runtimeVersion: version.raw,
      ),
      ManagedRuntimeNotSelected() => const ManagedRuntimeSetupStatusMapper().map(
        manifest: manifest,
        notSelected: selection,
        supportsManagedInstall: _supportsManagedInstall(),
      ),
    };
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
    final commandExecutor = _commandExecutor(processes: processes);
    final CommandResult result;
    try {
      result = await commandExecutor.run(
        executable: binaryPath,
        arguments: const ["models", "--json"],
        workingDirectory: null,
        environment: environment,
        timeout: _versionProbeTimeout,
      );
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

  bool _supportsManagedInstall() {
    try {
      return const OmpRuntimeManifest().supportsManagedInstallOn(target: PlatformTarget.current());
    } on Object catch (error, stackTrace) {
      Log.w("[omp] platform detection failed; managed install unavailable", error, stackTrace);
      return false;
    }
  }

  HostProcessCommandExecutor _commandExecutor({required HostProcessService processes}) => HostProcessCommandExecutor(
    includeParentEnvironment: true,
    processes: processes,
    runInShell: io.Platform.isWindows,
    maxCapturedOutputCharactersPerStream: 64 * 1024,
  );

  RuntimeVersionValidator _versionValidator({required HostProcessService processes}) => RuntimeVersionValidator(
    commandExecutor: _commandExecutor(processes: processes),
    manifest: const OmpRuntimeManifest(),
    probeTimeout: _versionProbeTimeout,
    executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
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
