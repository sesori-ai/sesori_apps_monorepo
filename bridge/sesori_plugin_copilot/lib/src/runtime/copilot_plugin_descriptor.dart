import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../copilot_binary.dart";
import "../copilot_identity.dart";
import "../copilot_plugin_impl.dart";
import "copilot_runtime_manifest.dart";
import "copilot_runtime_version_validator.dart";

const int _setupProbeOutputLimit = 64 * 1024;

typedef CopilotPluginFactory = CopilotPlugin Function({
  required String binaryPath,
  required String launchDirectory,
  required String catalogConfigDirectory,
  required Map<String, String> environment,
  required AcpProcessFactory processFactory,
});

CopilotPlugin _buildCopilotPlugin({
  required String binaryPath,
  required String launchDirectory,
  required String catalogConfigDirectory,
  required Map<String, String> environment,
  required AcpProcessFactory processFactory,
}) => CopilotPlugin(
  binaryPath: binaryPath,
  launchDirectory: launchDirectory,
  catalogConfigDirectory: catalogConfigDirectory,
  environment: environment,
  processFactory: processFactory,
);

final class const CopilotPluginDescriptor({
  required final CopilotPluginFactory _buildPlugin,
  required final Duration _connectBudget,
  required final Duration _versionProbeTimeout,
}) extends BridgePluginDescriptor {
  factory production() => const CopilotPluginDescriptor(
    buildPlugin: _buildCopilotPlugin,
    connectBudget: Duration(seconds: 15),
    versionProbeTimeout: Duration(seconds: 10),
  );

  static const String binOption = "bin";

  static const List<PluginOption> cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to the GitHub Copilot CLI binary (copilot)",
      defaultsTo: CopilotBinary.defaultBinary,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
  ];

  @override
  String get id => CopilotPluginIdentity.id;

  @override
  String get displayName => CopilotPluginIdentity.displayName;

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
    if (value == null || value.isEmpty || value == CopilotBinary.defaultBinary) return null;
    return value;
  }

  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    const manifest = CopilotRuntimeManifest();
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
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    const manifest = CopilotRuntimeManifest();
    final explicitBin = _explicitBin(config: config);
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
    return switch (selection) {
      ManagedRuntimeSelected(:final version) => PluginSetupReady.versioned(runtimeVersion: version.raw),
      ManagedRuntimeExplicitNotSelected(:final primaryRejection) => _explicitSetupStatus(
        rejection: primaryRejection,
      ),
      ManagedRuntimeAutomaticNotSelected(:final primaryRejection, :final managedRejection) => _automaticSetupStatus(
        primaryRejection: primaryRejection,
        managedRejection: managedRejection,
      ),
    };
  }

  PluginSetupStatus _explicitSetupStatus({required ManagedRuntimeRejection rejection}) {
    return switch (rejection) {
      ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) => const PluginSetupRuntimeMissing(
        actionHint: "Fix the configured GitHub Copilot CLI path, then restart the bridge.",
      ),
      ManagedRuntimeVersionRejected() => const PluginSetupUnavailable(
        actionHint: "Update the configured GitHub Copilot CLI, then restart the bridge.",
      ),
      ManagedRuntimeProbeRejected() => const PluginSetupUnknown(
        actionHint: "GitHub Copilot setup could not be determined. Verify the configured CLI and retry.",
      ),
    };
  }

  PluginSetupStatus _automaticSetupStatus({
    required ManagedRuntimeRejection primaryRejection,
    required ManagedRuntimeRejection managedRejection,
  }) {
    if (_isUnknownRejection(primaryRejection) || _isUnknownRejection(managedRejection)) {
      return const PluginSetupUnknown(
        actionHint: "GitHub Copilot setup could not be determined. Verify the local CLI and retry.",
      );
    }
    return const PluginSetupRuntimeMissing(
      actionHint: "Install GitHub Copilot CLI locally, authenticate with `copilot login`, then retry setup detection.",
    );
  }

  bool _isUnknownRejection(ManagedRuntimeRejection rejection) {
    return switch (rejection) {
      ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) || ManagedRuntimeVersionRejected() => false,
      ManagedRuntimeProbeRejected() => true,
    };
  }

  RuntimeVersionValidator _versionValidator({required HostProcessService processes}) => CopilotRuntimeVersionValidator(
    commandExecutor: HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    ),
    probeTimeout: _versionProbeTimeout,
  );

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    final binaryPath = host.provisionedRuntimePath;
    if (binaryPath == null) {
      throw const PluginStartException(
        "No supported GitHub Copilot CLI is available. Install or update Copilot CLI, then restart the bridge.",
        cause: null,
      );
    }
    final copilot = _buildPlugin(
      binaryPath: binaryPath,
      launchDirectory: io.Directory.current.path,
      catalogConfigDirectory: "${host.stateDirectory}${io.Platform.pathSeparator}catalog",
      // hostProcessAcpFactory contributes the host environment once at spawn.
      environment: const {},
      processFactory: hostProcessAcpFactory(
        processes: host.processes,
        environment: host.environment,
      ),
    );
    return await AcpBridgePlugin.start(plugin: copilot, host: host, connectBudget: _connectBudget);
  }
}
