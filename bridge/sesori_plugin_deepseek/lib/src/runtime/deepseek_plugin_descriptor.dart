import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/deepseek_acp_api.dart";
import "../deepseek_binary.dart";
import "../deepseek_event_mapper.dart";
import "../deepseek_identity.dart";
import "../deepseek_plugin_impl.dart";
import "../repositories/deepseek_catalog_repository.dart";
import "../repositories/deepseek_history_repository.dart";
import "../repositories/deepseek_session_repository.dart";
import "../repositories/mappers/deepseek_catalog_mapper.dart";
import "../services/deepseek_session_options_service.dart";
import "../services/deepseek_session_service.dart";

const int _probeOutputLimit = 64 * 1024;

class const DeepSeekPluginDescriptor() extends BridgePluginDescriptor {
  static const String minVersion = "0.1.0-dev.1";
  static const String targetVersion = "0.1.0-dev.1";
  static const String binOption = "bin";
  static const Duration _probeTimeout = Duration(seconds: 10);
  static const Duration _connectBudget = Duration(seconds: 15);
  static final SemanticVersion _minimum = SemanticVersion.parse(value: minVersion);

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
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    final binary = _explicitBin(config: host.config) ?? DeepSeekBinary.defaultBinary;
    final probe = await _probeRuntime(
      binary: binary,
      processes: host.processes,
      environment: host.environment,
    );
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    switch (probe) {
      case _RuntimeReady():
        yield ProvisionReady(binaryPath: binary);
      case _RuntimeMissing():
        yield const ProvisionFailed(
          message: "The DeepSeek adapter is not installed. Configure an adapter path, then retry.",
        );
      case _RuntimeOutdated():
        yield const ProvisionFailed(message: "The DeepSeek adapter is too old. Update it, then retry.");
      case _RuntimeUnknown():
        yield const ProvisionFailed(
          message: "The DeepSeek adapter could not be verified. Check the local installation, then retry.",
        );
    }
  }

  @override
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    final explicit = _explicitBin(config: config);
    final binary = explicit ?? DeepSeekBinary.defaultBinary;
    final probe = await _probeRuntime(binary: binary, processes: processes, environment: environment);
    switch (probe) {
      case _RuntimeMissing():
        return PluginSetupRuntimeMissing(
          actionHint: explicit == null
              ? "Install the Sesori DeepSeek adapter or configure its binary path."
              : "Fix the configured DeepSeek adapter path, then restart the bridge.",
        );
      case _RuntimeOutdated():
        return const PluginSetupUnavailable(
          actionHint: "Update the Sesori DeepSeek adapter to a supported version, then restart the bridge.",
        );
      case _RuntimeUnknown():
        return const PluginSetupUnknown(
          actionHint: "The DeepSeek adapter version could not be verified. Check the local installation.",
        );
      case _RuntimeReady(:final version):
        final ready = await _probeReadiness(
          binary: binary,
          stateDirectory: stateDirectory,
          processes: processes,
          environment: environment,
        );
        return ready
            ? PluginSetupReady.versioned(runtimeVersion: version)
            : PluginSetupUnknown.versioned(
                actionHint: "Run `sesori-deepseek-acp check --state-dir <path>` locally and complete DeepSeek provider setup, then retry.",
                runtimeVersion: version,
              );
    }
  }

  Future<_RuntimeProbe> _probeRuntime({
    required String binary,
    required HostProcessService processes,
    required Map<String, String> environment,
  }) async {
    final executor = _executor(processes);
    try {
      final result = await executor.run(binary, const ["--version"], environment: environment, timeout: _probeTimeout);
      if (result.exitCode != 0) {
        return _looksMissing(result.stderr) ? const _RuntimeMissing() : const _RuntimeUnknown();
      }
      final match = RegExp(
        r"^sesori-deepseek-acp/(\S+) deepseek-harness/(\S+) acp/1$",
      ).firstMatch(result.stdout.trim());
      if (match == null) return const _RuntimeUnknown();
      final version = match.group(1)!;
      final parsed = SemanticVersion.tryParse(value: version);
      if (parsed == null) return const _RuntimeUnknown();
      return parsed.compareTo(_minimum) < 0 ? const _RuntimeOutdated() : _RuntimeReady(version: version);
    } on io.ProcessException {
      return const _RuntimeMissing();
    } on Object catch (error, stackTrace) {
      Log.w("[deepseek] adapter version probe failed", error, stackTrace);
      return const _RuntimeUnknown();
    }
  }

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

  bool _looksMissing(String value) => RegExp(
    "(not recognized|not found|no such file)",
    caseSensitive: false,
  ).hasMatch(value);

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    final binary = _explicitBin(config: host.config) ?? host.provisionedRuntimePath ?? DeepSeekBinary.defaultBinary;
    final cwd = io.Directory.current.path;
    final processFactory = hostProcessAcpFactory(processes: host.processes, environment: host.environment);
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
    const api = DeepSeekAcpApi(pluginId: DeepSeekIdentity.id);
    final mapper = DeepSeekEventMapper(
      launchDirectory: cwd,
      pluginId: DeepSeekIdentity.id,
      configurationTracker: configurationTracker,
      api: api,
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
      mapper: mapper,
      api: api,
      historyRepository: DeepSeekHistoryRepository(
        api: api,
        eventMapper: mapper,
        pluginId: DeepSeekIdentity.id,
      ),
      deepSeekSessionService: const DeepSeekSessionService(
        repository: DeepSeekSessionRepository(api: api),
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

sealed class const _RuntimeProbe();

final class const _RuntimeReady({required final String version}) extends _RuntimeProbe;

final class const _RuntimeMissing() extends _RuntimeProbe;

final class const _RuntimeOutdated() extends _RuntimeProbe;

final class const _RuntimeUnknown() extends _RuntimeProbe;
