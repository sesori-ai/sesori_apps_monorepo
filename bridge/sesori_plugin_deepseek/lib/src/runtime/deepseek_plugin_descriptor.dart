import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../api/deepseek_acp_api.dart";
import "../deepseek_binary.dart";
import "../deepseek_event_mapper.dart";
import "../deepseek_identity.dart";
import "../deepseek_message_time_parser.dart";
import "../deepseek_plugin_impl.dart";
import "../repositories/deepseek_catalog_repository.dart";
import "../repositories/deepseek_history_repository.dart";
import "../repositories/deepseek_session_repository.dart";
import "../repositories/mappers/deepseek_catalog_mapper.dart";
import "../repositories/mappers/deepseek_subagent_mapper.dart";
import "../services/deepseek_session_options_service.dart";
import "../services/deepseek_session_service.dart";
import "deepseek_runtime_manifest.dart";

const int _probeOutputLimit = 64 * 1024;

class const DeepSeekPluginDescriptor() extends BridgePluginDescriptor {
  static const String minVersion = "0.1.0";
  static const String targetVersion = DeepSeekRuntimeManifest.targetVersion;
  static const String binOption = "bin";
  static const Duration _probeTimeout = Duration(seconds: 10);
  static const Duration _connectBudget = Duration(seconds: 15);
  static const List<PluginOption> cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to the Sesori DeepSeek ACP adapter",
      defaultsTo: DeepSeekBinary.defaultBinary,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
  ];

  @override
  String get id => DeepSeekIdentity.id;

  @override
  String get displayName => DeepSeekIdentity.displayName;

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.plugin;

  @override
  bool get supportsPromptAttachments => true;

  @override
  List<PluginOption> get options => cliOptions;

  String? _explicitBin({required PluginConfig config}) {
    final value = config.value(binOption)?.trim();
    if (value == null || value.isEmpty || value == DeepSeekBinary.defaultBinary) return null;
    return value;
  }

  @override
  Set<PluginControlCapability> managementCapabilities({required PluginConfig config}) => {
    ...super.managementCapabilities(config: config),
    if (_supportsManagedInstall(config: config)) PluginControlCapability.install,
  };

  bool _supportsManagedInstall({required PluginConfig config}) {
    if (_explicitBin(config: config) != null) return false;
    try {
      return const DeepSeekRuntimeManifest().supportsManagedInstallOn(target: PlatformTarget.current());
    } on Object catch (error, stackTrace) {
      Log.w("[deepseek] platform detection failed; managed install unavailable", error, stackTrace);
      return false;
    }
  }

  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    const manifest = DeepSeekRuntimeManifest();
    yield* ManagedRuntimeProvisionService(
      manifest: manifest,
      selectionService: ManagedRuntimeSelectionService(
        manifest: manifest,
        versionValidator: _versionValidator(processes: host.processes),
      ),
      fallbackExecutableCandidates: const [],
    ).provision(
      host: host,
      explicitExecutablePath: _explicitBin(config: host.config),
    );
  }

  @override
  Stream<RuntimeProvisionProgress> installRuntime({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal startAborted,
  }) async* {
    const manifest = DeepSeekRuntimeManifest();
    final commandExecutor = _executor(processes);
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
    const manifest = DeepSeekRuntimeManifest();
    final explicit = _explicitBin(config: config);
    final selection =
        await ManagedRuntimeSelectionService(
          manifest: manifest,
          versionValidator: _versionValidator(processes: processes),
        ).select(
          explicitExecutablePath: explicit,
          fallbackExecutableCandidates: const [],
          environment: environment,
          stateDirectory: stateDirectory,
          abortSignal: StartAbortSignal.never,
          managedVersionPolicy: ManagedRuntimeVersionPolicy.exact,
        );
    switch (selection) {
      case ManagedRuntimeSelected(:final binaryPath, :final version):
        final ready = await _probeReadiness(
          binary: binaryPath,
          stateDirectory: stateDirectory,
          processes: processes,
          environment: environment,
        );
        return ready
            ? PluginSetupReady.versioned(runtimeVersion: version.raw)
            : PluginSetupUnknown.versioned(
                actionHint: "Run `sesori-deepseek-acp check --state-dir <path>` locally and complete DeepSeek provider setup, then retry.",
                runtimeVersion: version.raw,
              );
      case ManagedRuntimeExplicitNotSelected(:final primaryRejection):
        return switch (primaryRejection) {
          ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) => const PluginSetupRuntimeMissing(
            actionHint: "Fix the configured DeepSeek adapter path, then restart the bridge.",
          ),
          ManagedRuntimeVersionRejected() => const PluginSetupUnavailable(
            actionHint: "Update the configured DeepSeek adapter, then restart the bridge.",
          ),
          ManagedRuntimeProbeRejected() => const PluginSetupUnknown(
            actionHint: "The DeepSeek adapter version could not be verified. Check the configured installation.",
          ),
        };
      case ManagedRuntimeAutomaticNotSelected(:final primaryRejection, :final managedRejection):
        if (_isUnknownRejection(primaryRejection) || _isUnknownRejection(managedRejection)) {
          return const PluginSetupUnknown(
            actionHint: "The DeepSeek adapter version could not be verified. Check the local installation.",
          );
        }
        return PluginSetupRuntimeMissing(
          actionHint: _supportsManagedInstall(config: config)
              ? "Install the Sesori DeepSeek adapter from Sesori, or install it locally and retry setup detection."
              : "Install the Sesori DeepSeek adapter locally, then retry setup detection.",
        );
    }
  }

  bool _isUnknownRejection(ManagedRuntimeRejection rejection) => switch (rejection) {
    ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) || ManagedRuntimeVersionRejected() => false,
    ManagedRuntimeProbeRejected() => true,
  };

  Future<bool> _probeReadiness({
    required String binary,
    required String stateDirectory,
    required HostProcessService processes,
    required Map<String, String> environment,
  }) async {
    try {
      final result = await _executor(processes).run(
        binary,
        ["check", "--state-dir", stateDirectory],
        environment: environment,
        timeout: _probeTimeout,
      );
      return result.exitCode == 0;
    } on Object catch (error, stackTrace) {
      Log.w("[deepseek] adapter readiness probe failed", error, stackTrace);
      return false;
    }
  }

  HostProcessCommandExecutor _executor(HostProcessService processes) => HostProcessCommandExecutor(
    processes: processes,
    runInShell: io.Platform.isWindows,
    maxCapturedOutputCharactersPerStream: _probeOutputLimit,
  );

  RuntimeVersionValidator _versionValidator({required HostProcessService processes}) => RuntimeVersionValidator(
    commandExecutor: _executor(processes),
    manifest: const DeepSeekRuntimeManifest(),
    probeTimeout: _probeTimeout,
  );

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    final binary = _explicitBin(config: host.config) ?? host.provisionedRuntimePath ?? DeepSeekBinary.defaultBinary;
    final cwd = io.Directory.current.path;
    final processFactory = hostProcessAcpFactory(processes: host.processes, environment: host.environment);
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
    final childSessionTracker = AcpChildSessionTracker();
    const api = DeepSeekAcpApi(pluginId: DeepSeekIdentity.id);
    const messageTimeParser = DeepSeekMessageTimeParser();
    const subagentMapper = DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id);
    final mapper = DeepSeekEventMapper(
      launchDirectory: cwd,
      pluginId: DeepSeekIdentity.id,
      configurationTracker: configurationTracker,
      childSessions: childSessionTracker,
      api: api,
      messageTimeParser: messageTimeParser,
      subagentMapper: subagentMapper,
    );
    const catalogMapper = DeepSeekCatalogMapper();
    const catalogRepository = DeepSeekCatalogRepository(api: api, mapper: catalogMapper);
    final deepSeekOptions = DeepSeekSessionOptionsService(
      repository: catalogRepository,
      configurationTracker: configurationTracker,
      pluginId: DeepSeekIdentity.id,
      discoveryTimeout: const Duration(seconds: 30),
    );
    final plugin = DeepSeekPlugin(
      launchSpec: DeepSeekBinary.launchSpec(
        binary: binary,
        cwd: cwd,
        stateDirectory: host.stateDirectory,
        environment: const {},
      ),
      launchDirectory: cwd,
      childSessionTracker: childSessionTracker,
      mapper: mapper,
      api: api,
      historyRepository: DeepSeekHistoryRepository(
        api: api,
        eventMapper: mapper,
        pluginId: DeepSeekIdentity.id,
        messageTimeParser: messageTimeParser,
        subagentMapper: subagentMapper,
      ),
      deepSeekSessionService: DeepSeekSessionService(
        repository: const DeepSeekSessionRepository(api: api),
        childSessions: childSessionTracker,
      ),
      deepSeekSessionOptionsService: deepSeekOptions,
      commandTracker: commandTracker,
      sessionOptionsService: AcpSessionOptionsService(
        configurationTracker: configurationTracker,
        commandTracker: commandTracker,
        pluginId: DeepSeekIdentity.id,
        agentDisplayName: DeepSeekIdentity.displayName,
      ),
      processFactory: processFactory,
    );
    return await AcpBridgePlugin.start(plugin: plugin, host: host, connectBudget: _connectBudget);
  }
}
