import "dart:async";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/antigravity_acp_api.dart";
import "../builders/antigravity_launch_spec_builder.dart";
import "../foundation/antigravity_authentication_budget.dart";
import "../foundation/antigravity_identity.dart";
import "../foundation/antigravity_release.dart";
import "../models/antigravity_profile.dart";
import "../models/antigravity_runtime_resolution.dart";
import "../repositories/antigravity_profile_inspection_repository.dart";
import "../repositories/antigravity_profile_repository.dart";
import "../repositories/antigravity_runtime_repository.dart";
import "../repositories/mappers/antigravity_stderr_mapper.dart";
import "../services/antigravity_profile_inspection_service.dart";
import "../services/antigravity_profile_service.dart";
import "../services/antigravity_runtime_service.dart";
import "../services/antigravity_setup_service.dart";
import "../storage/antigravity_profile_inspection_storage.dart";
import "../storage/antigravity_profile_storage.dart";
import "../storage/antigravity_runtime_storage.dart";
import "antigravity_authentication_composer.dart";
import "antigravity_plugin_composer.dart";

/// Unregistered composition root for Google's official Antigravity ACP pair.
/// Bridge activation and managed installation remain later plan gates.
class const AntigravityPluginDescriptor({
  final PlatformTarget? target,
  final String? browserExecutable,
  final List<String>? browserPrefixArguments,
  final String? launchDirectory,
  final HttpClient Function()? callbackHttpClientFactory,
  final Duration operationTimeout = const Duration(minutes: 2),
  final Duration connectBudget = const Duration(seconds: 15),
}) extends BridgePluginDescriptor implements InteractivePluginAuthenticationDescriptor {
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
  };

  String? _explicitServerPath({required PluginConfig config}) {
    final value = config.value(binOption)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  PlatformTarget _target() => target ?? PlatformTarget.current();
  String _geminiHome({required String stateDirectory}) => p.join(stateDirectory, "profile");
  String _managedServerPath({required String stateDirectory, required PlatformTarget target}) => p.join(
    stateDirectory,
    AntigravityIdentity.pluginId,
    AntigravityRelease.agentVersion,
    AntigravityRelease.serverFileName(target: target),
  );

  ({String executable, List<String> arguments}) _browserInvocation() {
    final injectedExecutable = browserExecutable;
    if (injectedExecutable != null) {
      return (executable: injectedExecutable, arguments: List.unmodifiable(browserPrefixArguments ?? const []));
    }
    final packageConfig = Platform.packageConfig;
    final packageConfigPath = packageConfig == null ? null : Uri.parse(packageConfig).toFilePath();
    return (
      executable: Platform.resolvedExecutable,
      arguments: packageConfigPath == null
          ? const []
          : List.unmodifiable(["--packages=$packageConfigPath", Platform.script.toFilePath()]),
    );
  }

  AntigravityRuntimeService _runtime({
    required HostProcessService processes,
    required Map<String, String> environment,
  }) {
    const stderrMapper = AntigravityStderrMapper();
    return AntigravityRuntimeService(
      runtimeRepository: AntigravityRuntimeRepository(
        runtimeStorage: const AntigravityRuntimeStorage(),
        acpApi: AntigravityAcpApi(
          processFactory: hostProcessAcpFactory(processes: processes, environment: environment),
          stderrInterceptor: AcpOutputInterceptor(maxLineBytes: 65536, consumeLine: stderrMapper.consumeLine),
        ),
        launchSpecBuilder: const AntigravityLaunchSpecBuilder(),
      ),
    );
  }

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
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    final selectedTarget = _target();
    return AntigravitySetupService(
      runtime: _runtime(processes: processes, environment: environment),
      profile: AntigravityProfileInspectionService(
        repository: AntigravityProfileInspectionRepository(
          storage: const AntigravityProfileInspectionStorage(),
        ),
      ),
    ).inspect(
      explicitServerPath: _explicitServerPath(config: config),
      managedServerPath: _managedServerPath(stateDirectory: stateDirectory, target: selectedTarget),
      environment: environment,
      target: selectedTarget,
      geminiHome: _geminiHome(stateDirectory: stateDirectory),
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
    } on TimeoutException {
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
      callbackHttpClient: callbackHttpClientFactory?.call() ?? HttpClient(),
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
