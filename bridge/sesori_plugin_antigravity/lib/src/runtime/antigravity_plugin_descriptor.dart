import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:http/http.dart" as http;
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../api/antigravity_acp_api.dart";
import "../builders/antigravity_environment_builder.dart";
import "../builders/antigravity_launch_spec_builder.dart";
import "../foundation/antigravity_authentication_budget.dart";
import "../foundation/antigravity_identity.dart";
import "../foundation/antigravity_release.dart";
import "../models/antigravity_profile.dart";
import "../models/antigravity_runtime_resolution.dart";
import "../repositories/antigravity_profile_inspection_repository.dart";
import "../repositories/antigravity_profile_repository.dart";
import "../repositories/antigravity_runtime_repository.dart";
import "../repositories/antigravity_runtime_version_repository.dart";
import "../repositories/mappers/antigravity_stderr_mapper.dart";
import "../services/antigravity_managed_runtime_path_authority.dart";
import "../services/antigravity_profile_inspection_service.dart";
import "../services/antigravity_profile_service.dart";
import "../services/antigravity_runtime_service.dart";
import "../services/antigravity_setup_service.dart";
import "../storage/antigravity_profile_inspection_storage.dart";
import "../storage/antigravity_profile_storage.dart";
import "../storage/antigravity_runtime_storage.dart";
import "antigravity_authentication_composer.dart";
import "antigravity_plugin_composer.dart";
import "antigravity_runtime_manifest.dart";
import "antigravity_runtime_version_validator.dart";

/// Composition root for Google's official local or Sesori-managed ACP pair.
class const AntigravityPluginDescriptor({
  final PlatformTarget? target,
  final String? browserExecutable,
  final List<String>? browserPrefixArguments,
  final String? launchDirectory,
  required final HttpClient Function() callbackHttpClientFactory,
  required final http.Client Function() runtimeDownloadHttpClientFactory,
  final Duration operationTimeout = const Duration(minutes: 2),
  final Duration connectBudget = const Duration(seconds: 15),
}) extends BridgePluginDescriptor implements InteractivePluginAuthenticationDescriptor {
  factory production() => const AntigravityPluginDescriptor(
    callbackHttpClientFactory: HttpClient.new,
    runtimeDownloadHttpClientFactory: http.Client.new,
  );
  static const binOption = "bin";
  static const cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to Google's official Antigravity ACP server",
      defaultsTo: null,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
  ];

  @override
  String get id => AntigravityIdentity.pluginId;
  @override
  String get displayName => AntigravityIdentity.displayName;
  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;
  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.plugin;
  @override
  bool get supportsPromptAttachments => true;
  @override
  List<PluginOption> get options => cliOptions;

  @override
  Set<PluginControlCapability> managementCapabilities({required PluginConfig config}) => {
    ...super.managementCapabilities(config: config),
    PluginControlCapability.authentication,
    if (_supportsManagedInstall(config: config)) PluginControlCapability.install,
  };

  bool _supportsManagedInstall({required PluginConfig config}) {
    if (_explicitServerPath(config: config) != null) return false;
    return const AntigravityRuntimeManifest().supportsManagedInstallOn(target: _target());
  }

  @override
  Future<bool> needsManagedRuntimeUpgrade({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    if (!_supportsManagedInstall(config: config)) return false;
    final selectedTarget = _target();
    return await ManagedRuntimeUpgradeService(
      pathAuthority: _pathAuthority(
        processes: processes,
        environment: environment,
        target: selectedTarget,
      ),
      inventory: const ManagedRuntimeInventory(manifest: AntigravityRuntimeManifest()),
    ).shouldUpgrade(environment: environment, stateDirectory: stateDirectory);
  }

  String? _explicitServerPath({required PluginConfig config}) {
    final value = config.value(binOption)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  PlatformTarget _target() => target ?? PlatformTarget.current();
  String _geminiHome({required String stateDirectory}) => p.join(stateDirectory, "profile");
  String? _managedServerPath({required String stateDirectory, required PlatformTarget target}) {
    if (!AntigravityRelease.supportsTarget(target: target)) return null;
    return const AntigravityRuntimeManifest().managedServerPath(
      stateDirectory: stateDirectory,
      target: target,
    );
  }

  ({String executable, List<String> arguments}) _browserInvocation() {
    final injectedExecutable = browserExecutable;
    if (injectedExecutable != null) {
      return (executable: injectedExecutable, arguments: List.unmodifiable(browserPrefixArguments ?? const []));
    }
    final packageConfig = Platform.packageConfig;
    final packageConfigPath = packageConfig == null ? null : Uri.parse(packageConfig).toFilePath();
    // Package discovery may be implicit in Dart-hosted source/snapshot runs.
    // Native bundles use their invoked executable as the script, including
    // relative/PATH invocations; do not compare with the resolved symlink path.
    final executableScript = Uri.base.resolveUri(Uri.file(Platform.executable));
    return (
      executable: Platform.resolvedExecutable,
      arguments: List.unmodifiable([
        if (packageConfigPath != null) "--packages=$packageConfigPath",
        if (Platform.script != executableScript) Platform.script.toFilePath(),
      ]),
    );
  }

  AntigravityAcpApi _api({
    required HostProcessService processes,
    required Map<String, String> environment,
  }) {
    const stderrMapper = AntigravityStderrMapper();
    return AntigravityAcpApi(
      processFactory: hostProcessAcpFactory(processes: processes, environment: environment),
      stderrInterceptor: AcpOutputInterceptor(maxLineBytes: 65536, consumeLine: stderrMapper.consumeLine),
      commands: HostProcessCommandExecutor(
        processes: processes,
        runInShell: false,
        includeParentEnvironment: false,
        maxCapturedOutputCharactersPerStream: 4096,
      ),
    );
  }

  AntigravityRuntimeRepository _runtimeRepository({
    required HostProcessService processes,
    required Map<String, String> environment,
  }) => AntigravityRuntimeRepository(
    runtimeStorage: const AntigravityRuntimeStorage(),
    acpApi: _api(processes: processes, environment: environment),
    launchSpecBuilder: const AntigravityLaunchSpecBuilder(),
  );

  AntigravityRuntimeService _runtime({
    required HostProcessService processes,
    required Map<String, String> environment,
  }) => AntigravityRuntimeService(
    runtimeRepository: _runtimeRepository(processes: processes, environment: environment),
  );

  AntigravityManagedRuntimePathAuthority _pathAuthority({
    required HostProcessService processes,
    required Map<String, String> environment,
    required PlatformTarget target,
  }) => AntigravityManagedRuntimePathAuthority(
    runtimeRepository: _runtimeRepository(processes: processes, environment: environment),
    target: target,
  );

  AntigravityProfileService _profile({
    required HostProcessService processes,
    required HostJsonStore store,
    required String stateDirectory,
    required PlatformTarget target,
  }) {
    final browser = _browserInvocation();
    return AntigravityProfileService(
      repository: AntigravityProfileRepository(
        storage: AntigravityProfileStorage(
          geminiHome: _geminiHome(stateDirectory: stateDirectory),
          settingsStore: store.scope(directoryName: "profile").scope(directoryName: "antigravity-acp"),
          commands: HostProcessCommandExecutor(
            processes: processes,
            runInShell: false,
            includeParentEnvironment: false,
            maxCapturedOutputCharactersPerStream: 4096,
          ),
          target: target,
        ),
      ),
      target: target,
      browserExecutable: browser.executable,
      browserPrefixArguments: browser.arguments,
    );
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
    if (!_supportsManagedInstall(config: config)) {
      yield const ProvisionFailed(
        message: "Antigravity managed installation is unavailable with this configuration or platform.",
      );
      return;
    }

    const manifest = AntigravityRuntimeManifest();
    final commandExecutor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: Platform.isWindows,
      includeParentEnvironment: true,
      maxCapturedOutputCharactersPerStream: null,
    );
    if (startAborted.isAborted) throw const PluginStartAbortedException();
    if (_target().os == PlatformOs.linux) {
      final extractorAvailable = await _hasLinuxZipExtractor(commands: commandExecutor, environment: environment);
      if (startAborted.isAborted) throw const PluginStartAbortedException();
      if (!extractorAvailable) {
        yield const ProvisionFailed(
          message:
              "Antigravity installation requires Info-ZIP unzip with ZipInfo support on Linux. "
              "Install your distribution's unzip package, then retry.",
        );
        return;
      }
    }
    final httpClient = runtimeDownloadHttpClientFactory();
    try {
      final runtimeService = _runtime(processes: processes, environment: environment);
      final installer = const ManagedRuntimeComposition().createInstaller(
        manifest: manifest,
        commandExecutor: commandExecutor,
        downloadClient: BinaryDownloadClient(httpClient: httpClient),
        candidateValidator: AntigravityRuntimeVersionValidator(runtimeService: runtimeService),
        pathAuthority: _pathAuthority(
          processes: processes,
          environment: environment,
          target: _target(),
        ),
        assetResolver: ({required target}) async => manifest.assetFor(target: target),
      );
      yield* installer.install(
        environment: environment,
        stateDirectory: stateDirectory,
        startAborted: startAborted,
        runtimeInUse: runtimeInUse,
      );
    } finally {
      httpClient.close();
    }
  }

  Future<bool> _hasLinuxZipExtractor({
    required CommandExecutor commands,
    required Map<String, String> environment,
  }) async {
    try {
      final result = await commands.run(
        "unzip",
        const ["-Z", "-h"],
        environment: environment,
        timeout: const Duration(seconds: 10),
      );
      if (result.exitCode == 0) return true;
      Log.w("[antigravity] Linux unzip ZipInfo preflight failed", result);
      return false;
    } on PluginStartAbortedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Log.w("[antigravity] Linux unzip ZipInfo preflight failed", error, stackTrace);
      return false;
    }
  }

  @override
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    final selectedTarget = _target();
    final geminiHome = _geminiHome(stateDirectory: stateDirectory);
    return await AntigravitySetupService(
      runtime: _runtime(processes: processes, environment: environment),
      runtimeVersions: AntigravityRuntimeVersionRepository(
        api: _api(processes: processes, environment: environment),
      ),
      profile: AntigravityProfileInspectionService(
        repository: AntigravityProfileInspectionRepository(
          storage: const AntigravityProfileInspectionStorage(),
        ),
      ),
    ).inspect(
      explicitServerPath: _explicitServerPath(config: config),
      managedServerPath: _managedServerPath(stateDirectory: stateDirectory, target: selectedTarget),
      pathEnvironment: environment,
      probeEnvironment: const AntigravityEnvironmentBuilder().build(
        hostEnvironment: environment,
        geminiHome: geminiHome,
        additions: const {},
      ),
      target: selectedTarget,
      geminiHome: geminiHome,
      managedInstallAvailable: _supportsManagedInstall(config: config),
      timeout: operationTimeout,
    );
  }

  Future<({AntigravityPreparedProfile profile, AntigravityRuntimeSelected runtime})> _prepareAndResolve({
    required PluginConfig config,
    required HostProcessService processes,
    required HostJsonStore store,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal aborted,
    required String? selectedServerPath,
  }) async {
    final selectedTarget = _target();
    final budget = AntigravityAuthenticationBudget(timeout: operationTimeout, abortSignal: aborted);
    final profile = await _profile(
      processes: processes,
      store: store,
      stateDirectory: stateDirectory,
      target: selectedTarget,
    ).prepare(hostEnvironment: environment, budget: budget);
    final resolution = await _runtime(processes: processes, environment: profile.environment).resolve(
      explicitServerPath: selectedServerPath ?? _explicitServerPath(config: config),
      managedServerPath: selectedServerPath == null
          ? _managedServerPath(stateDirectory: stateDirectory, target: selectedTarget)
          : null,
      pathEnvironment: profile.environment,
      probeEnvironment: profile.environment,
      target: selectedTarget,
      timeout: budget.remaining,
      abortSignal: aborted,
    );
    if (resolution case final AntigravityRuntimeSelected selected) return (profile: profile, runtime: selected);
    _throwRuntimeFailure(resolution: resolution);
  }

  Never _throwRuntimeFailure({required AntigravityRuntimeResolution resolution}) {
    final error = PluginStartException("No validated Antigravity runtime pair is available.", cause: resolution);
    switch (resolution) {
      case AntigravityRuntimeStorageFailed(:final stackTrace):
        Error.throwWithStackTrace(error, stackTrace);
      case AntigravityRuntimeProbeFailed(:final stackTrace):
        Error.throwWithStackTrace(error, stackTrace);
      case AntigravityRuntimeSelected() ||
          AntigravityRuntimeMissing() ||
          AntigravityRuntimePairRejected() ||
          AntigravityRuntimeContractRejected() ||
          AntigravityRuntimeUnsupported():
        throw error;
    }
  }

  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    try {
      final prepared = await _prepareAndResolve(
        config: host.config,
        processes: host.processes,
        store: host.store,
        environment: host.environment,
        stateDirectory: host.stateDirectory,
        aborted: host.startAborted,
        selectedServerPath: null,
      );
      yield ProvisionReady(binaryPath: prepared.runtime.pair.serverPath);
    } on PluginStartAbortedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      _logPreparationFailure(error: error, stackTrace: stackTrace);
      yield const ProvisionFailed(
        message: "Antigravity runtime validation failed. Check the official runtime pair and retry.",
      );
    }
  }

  void _logPreparationFailure({required Object error, required StackTrace stackTrace}) {
    switch (error) {
      case PluginStartException(cause: AntigravityRuntimeStorageFailed(:final cause, :final stackTrace)):
        Log.w("[antigravity] runtime inspection failed", cause, stackTrace);
      case PluginStartException(cause: AntigravityRuntimeProbeFailed(:final cause, :final stackTrace)):
        Log.w("[antigravity] runtime validation failed", cause, stackTrace);
      case AntigravityProfileException(:final cause?):
        Log.w("[antigravity] isolated profile preparation failed", cause, stackTrace);
      default:
        Log.w("[antigravity] runtime preparation failed", error, stackTrace);
    }
  }

  @override
  PluginAuthenticationOperation authenticate({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required HostJsonStore store,
    required StartAbortSignal aborted,
  }) {
    final selectedTarget = _target();
    final browser = _browserInvocation();
    return const AntigravityAuthenticationComposer().compose(
      processes: processes,
      store: store,
      callbackHttpClient: callbackHttpClientFactory(),
      stateDirectory: stateDirectory,
      environment: environment,
      target: selectedTarget,
      browserExecutable: browser.executable,
      browserPrefixArguments: browser.arguments,
      explicitServerPath: _explicitServerPath(config: config),
      managedServerPath: _managedServerPath(stateDirectory: stateDirectory, target: selectedTarget),
      aborted: aborted,
      timeout: operationTimeout,
    );
  }

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    final prepared = await _prepareAndResolve(
      config: host.config,
      processes: host.processes,
      store: host.store,
      environment: host.environment,
      stateDirectory: host.stateDirectory,
      aborted: host.startAborted,
      selectedServerPath: host.provisionedRuntimePath,
    );
    final plugin = const AntigravityPluginComposer().compose(
      pair: prepared.runtime.pair,
      profile: prepared.profile,
      launchDirectory: launchDirectory ?? Directory.current.path,
      processFactory: hostProcessAcpFactory(processes: host.processes, environment: prepared.profile.environment),
    );
    return await AcpBridgePlugin.start(plugin: plugin, host: host, connectBudget: connectBudget);
  }
}
