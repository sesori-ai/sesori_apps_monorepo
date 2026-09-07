import "dart:async";
import "dart:io" as io;
import "dart:math";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../api/claude_process_factory.dart";
import "../api/claude_transcript_api.dart";
import "../api/models/claude_auth_status_dto.dart";
import "../claude_approval_registry.dart";
import "../claude_event_dispatcher.dart";
import "../claude_history_mapper.dart";
import "../claude_plugin_impl.dart";
import "../repositories/claude_backend_catalog_repository.dart";
import "../repositories/claude_session_process_repository.dart";
import "../repositories/claude_transcript_catalog_repository.dart";
import "../repositories/mappers/claude_content_mapper.dart";
import "../repositories/trackers/claude_tool_tracker.dart";
import "../services/claude_catalog_service.dart";
import "../services/claude_session_service.dart";
import "claude_bridge_plugin.dart";

const int _setupProbeOutputLimit = 64 * 1024;

typedef ClaudeBridgePluginFactory = ClaudeBridgePlugin Function({
  required ClaudePlugin plugin,
  required ClaudeSessionService sessions,
  required HostClaudeProcessFactory processFactory,
  required ServerClock clock,
  required Duration statusDebounce,
});

ClaudeBridgePlugin _defaultBuildBridgePlugin({
  required ClaudePlugin plugin,
  required ClaudeSessionService sessions,
  required HostClaudeProcessFactory processFactory,
  required ServerClock clock,
  required Duration statusDebounce,
}) => ClaudeBridgePlugin(
  plugin: plugin,
  sessions: sessions,
  processFactory: processFactory,
  clock: clock,
  statusDebounce: statusDebounce,
);

/// Descriptor and composition root for the local Claude Code CLI plugin.
final class const ClaudePluginDescriptor({
  final Duration _probeTimeout = const Duration(seconds: 10),
  final Duration _statusDebounce = const Duration(seconds: 5),
  final ClaudeBridgePluginFactory? _buildBridgePlugin,
}) extends BridgePluginDescriptor {
  static const String binOption = "bin";
  static const String defaultBinary = "claude";

  /// Oldest Claude Code release with the CLI behavior this plugin requires.
  static const String minVersion = "2.1.221";

  /// Latest stable Claude Code release validated against this plugin.
  static const String targetVersion = "2.1.237";

  static final Random _secureRandom = Random.secure();

  static const List<PluginOption> cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to the Claude Code CLI binary",
      defaultsTo: defaultBinary,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
  ];

  @override
  String get id => ClaudePlugin.pluginId;

  @override
  String get displayName => "Claude Code";

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.plugin;

  @override
  bool get supportsPromptAttachments => true;

  /// Claude owns idle reclamation per session: the service reaps individual
  /// CLI child processes on the user-configured idle timeout
  /// ([PluginHost.pluginIdleTimeout]) and resumes them transparently with
  /// `--resume`. Whole-plugin suspension would add nothing (an all-reaped
  /// plugin holds no processes, timers, or ports) and would silently kill any
  /// pending in-process `ScheduleWakeup` timer, so the bridge-level idle
  /// suspension must never arm.
  @override
  PluginResidencyPolicy residencyPolicy({required PluginConfig config}) => PluginResidencyPolicy.resident;

  @override
  List<PluginOption> get options => cliOptions;

  @override
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    final executable = _binary(config);
    final executor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );
    final CommandResult versionResult;
    try {
      versionResult = await executor.run(
        executable,
        const ["--version"],
        environment: environment,
        timeout: _probeTimeout,
      );
    } on io.ProcessException {
      return const PluginSetupRuntimeMissing(
        actionHint: "Install Claude Code or fix the configured binary path, then retry setup detection.",
      );
    } on Object {
      return const PluginSetupUnknown(
        actionHint: "Claude Code did not answer its version check. Verify the local installation and retry.",
      );
    }
    if (versionResult.exitCode != 0) {
      return const PluginSetupUnknown(
        actionHint: "Claude Code did not answer its version check. Verify the local installation and retry.",
      );
    }
    final version = _parseVersion(versionResult.stdout);
    if (version == null) {
      return const PluginSetupUnknown(
        actionHint: "Claude Code returned an unrecognized version. Update it and retry setup detection.",
      );
    }
    final minimum = SemanticVersion.parse(value: minVersion);
    if (version.compareTo(minimum) < 0) {
      return const PluginSetupUnavailable(
        actionHint: "Update Claude Code to a supported version, then retry setup detection.",
      );
    }
    final runtimeVersion = version.toString();

    final CommandResult authResult;
    try {
      authResult = await executor.run(
        executable,
        const ["auth", "status"],
        environment: environment,
        timeout: _probeTimeout,
      );
    } on Object {
      return PluginSetupUnknown.versioned(
        actionHint: "Claude Code authentication could not be determined. Run `claude auth status` locally and retry.",
        runtimeVersion: runtimeVersion,
      );
    }
    try {
      final status = ClaudeAuthStatusDto.fromJson(jsonDecodeMap(authResult.stdout));
      return switch (status.loggedIn) {
        true => PluginSetupReady.versioned(runtimeVersion: runtimeVersion),
        false => PluginSetupAuthenticationRequired.versioned(
          actionHint: "Run `claude auth login` on this machine, then retry setup detection.",
          runtimeVersion: runtimeVersion,
        ),
        null => PluginSetupUnknown.versioned(
          actionHint: "Claude Code authentication could not be determined. Run `claude auth status` locally and retry.",
          runtimeVersion: runtimeVersion,
        ),
      };
    } on Object {
      return PluginSetupUnknown.versioned(
        actionHint: "Claude Code authentication could not be determined. Run `claude auth status` locally and retry.",
        runtimeVersion: runtimeVersion,
      );
    }
  }

  @override
  Future<ClaudeBridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();

    final binaryPath = _binary(host.config);
    final processFactory = HostClaudeProcessFactory(
      processes: host.processes,
      environment: host.environment,
    );
    final processes = ClaudeSessionProcessRepository(
      processFactory: processFactory.spawn,
      binaryPath: binaryPath,
      // The host factory already inherits this environment. Launch specs carry
      // only explicit overrides so they never shadow HOME and break keychain auth.
      environment: const {},
    );
    final eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>();
    final approvals = ClaudeApprovalRegistry(
      emit: eventBuffer.add,
      respond: processes.answerControlRequest,
    );
    final sessions = ClaudeSessionService(
      processes: processes,
      approvals: approvals,
      clock: host.clock,
      resolveIdleTimeout: () => host.pluginIdleTimeout,
      idleTimeoutChanges: host.pluginIdleTimeoutChanges,
    );
    const content = ClaudeContentMapper();
    final catalogService = ClaudeCatalogService(
      catalog: const ClaudeBackendCatalogRepository(),
      processes: processes,
      probeSessionId: _generateUuidV4(),
      discoveryDirectory: host.stateDirectory,
    );
    final plugin = ClaudePlugin(
      processes: processes,
      transcripts: ClaudeTranscriptCatalogRepository(
        transcriptApi: ClaudeTranscriptApi(environment: host.environment),
      ),
      sessions: sessions,
      catalogService: catalogService,
      approvals: approvals,
      eventDispatcher: ClaudeEventDispatcher(
        content: content,
        tools: ClaudeToolTracker(),
        catalogModelId: ({required apiModel}) => catalogService.cached?.catalogModelId(apiModel: apiModel),
      ),
      history: const ClaudeHistoryMapper(content: content),
      eventBuffer: eventBuffer,
      clock: host.clock,
      generateSessionId: _generateUuidV4,
      launchDirectory: io.Directory.current.path,
    );
    final bridgePlugin = (_buildBridgePlugin ?? _defaultBuildBridgePlugin)(
      plugin: plugin,
      sessions: sessions,
      processFactory: processFactory,
      clock: host.clock,
      statusDebounce: _statusDebounce,
    );

    if (host.startAborted.isAborted) {
      try {
        await bridgePlugin.shutdown(budget: null);
      } on Object catch (error, stackTrace) {
        Log.e("[claude] rollback after aborted start failed", error, stackTrace);
      }
      throw const PluginStartAbortedException();
    }
    return bridgePlugin;
  }

  String _binary(PluginConfig config) {
    final configured = config.value(binOption)?.trim();
    return configured == null || configured.isEmpty ? defaultBinary : configured;
  }

  static SemanticVersion? _parseVersion(String output) {
    final match = RegExp(r"(?:^|\s)(\d+\.\d+\.\d+)(?:\s|$)").firstMatch(output);
    final value = match?.group(1);
    return value == null ? null : SemanticVersion.tryParse(value: value);
  }

  static String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
    return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-"
        "${hex.substring(16, 20)}-${hex.substring(20)}";
  }
}
