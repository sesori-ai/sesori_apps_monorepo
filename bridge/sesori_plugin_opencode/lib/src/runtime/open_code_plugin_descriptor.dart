import "dart:async";
import "dart:io" as io;
import "dart:math";

import "package:http/http.dart" as http;
import "package:meta/meta.dart" show visibleForTesting;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness, StringExtensions, maxTranscriptImageCollectionBytes;

import "../api/open_code_catalog_database_api.dart";
import "../api/open_code_service_command_api.dart";
import "../api/open_code_service_registration_api.dart";
import "../message_part_mapper.dart";
import "../opencode_plugin_impl.dart";
import "../plugin_model_mapper.dart";
import "../repositories/open_code_catalog_repository.dart";
import "../repositories/open_code_catalog_snapshot_mapper.dart";
import "../repositories/open_code_shared_server_repository.dart";
import "../services/open_code_shared_server_service.dart";
import "../v2/opencode_v2_plugin.dart";
import "open_code_managed_api.dart";
import "open_code_ownership_record.dart";
import "open_code_protocol.dart";
import "open_code_record_mapper.dart";
import "open_code_runtime_manifest.dart";
import "open_code_runtime_policy.dart";
import "open_code_shared_server_endpoint.dart";

const int _setupProbeOutputLimit = 64 * 1024;

/// How the plugin reached its server; `name` is the diagnostics `mode` value.
enum _OpenCodeServerMode() {
  attached,
  shared,
  managed,
}

abstract final class _OpenCodeConfigKey() {
  static const String port = "port";
  static const String host = "host";
  static const String noAutoStart = "no-auto-start";
  static const String password = "password";
  static const String noPassword = "no-password";
  static const String binary = "bin";
  static const String noSharedService = "no-shared-service";
}

/// Builds the [OpenCodeManagedApi] for a resolved server. The descriptor awaits
/// [OpenCodeManagedApi.initialize] explicitly; tests inject a fake.
typedef OpenCodeManagedApiFactory = OpenCodeManagedApi Function({
  required OpenCodeProtocol protocol,
  required String serverUrl,
  required String? password,
  required void Function() onConnected,
  required void Function() onDisconnected,
});

typedef OpenCodeCatalogSnapshotReader = Future<PluginCatalogSnapshotResult> Function({
  required PluginConfig config,
  required Map<String, String> environment,
  required PluginCatalogCancellationSignal cancellation,
});

OpenCodeManagedApi _buildProductionApi({
  required OpenCodeProtocol protocol,
  required String serverUrl,
  required String? password,
  required void Function() onConnected,
  required void Function() onDisconnected,
}) => switch (protocol) {
  OpenCodeProtocolV1() => OpenCodePlugin(
    serverUrl: serverUrl,
    password: password,
    onConnected: onConnected,
    onDisconnected: onDisconnected,
  ),
  OpenCodeProtocolV2() => OpenCodeV2Plugin(
    serverUrl: serverUrl,
    password: password,
    onConnected: onConnected,
    onDisconnected: onDisconnected,
  ),
};

/// The real, const OpenCode plugin descriptor: it owns the full OpenCode runtime
/// lifecycle (stale cleanup, start-or-attach, health, ownership persistence,
/// exit monitoring, bounded crash-restart) over the [PluginHost] and the
/// `sesori_plugin_runtime` supervisor.
///
/// Registered in the bridge plugin registry, with the hardened policy knobs
/// active: deadline-paced health confirmation, pre-probed explicit ports, early
/// child exits treated as authoritative failure, and bounded restart pinned to
/// the original port.
///
/// Production registration uses [production]; tests pass fakes for the API,
/// probe client and catalog, and fixed port and random sources.
class const OpenCodePluginDescriptor({
  required final OpenCodeManagedApiFactory _buildApi,
  required final http.Client Function() _probeClientFactory,

  /// Dynamic port candidates to try. Production passes null and draws random
  /// ports from the dynamic range.
  required final Iterable<int>? _candidatePorts,

  /// Source for port draws and generated passwords. Production passes null,
  /// which uses [Random.secure].
  required final Random? _random,
  required final Duration _coldStartBudget,
  required final OpenCodeCatalogSnapshotReader _catalogSnapshotReader,
}) extends BridgePluginDescriptor {
  static OpenCodePluginDescriptor production() {
    return const OpenCodePluginDescriptor(
      buildApi: _buildProductionApi,
      probeClientFactory: http.Client.new,
      candidatePorts: null,
      random: null,
      coldStartBudget: openCodeColdStartBudget,
      catalogSnapshotReader: _readProductionCatalogSnapshot,
    );
  }

  static Future<PluginCatalogSnapshotResult> _readProductionCatalogSnapshot({
    required PluginConfig config,
    required Map<String, String> environment,
    required PluginCatalogCancellationSignal cancellation,
  }) {
    final operatingSystem = PlatformTarget.current().os;
    return OpenCodeCatalogRepository(
      databaseApi: OpenCodeCatalogDatabaseApi.production(),
      snapshotMapper: OpenCodeCatalogSnapshotMapper(
        modelMapper: const PluginModelMapper(
          messagePartMapper: MessagePartMapper(),
          maxTranscriptAttachmentBytes: maxTranscriptImageCollectionBytes,
        ),
        operatingSystem: operatingSystem,
      ),
      operatingSystem: operatingSystem,
      fileExists: openCodeCatalogFileExists,
      // Ordinary PATH/managed selection targets OpenCode's public latest
      // channel. An explicit binary can carry a custom compile-time channel,
      // so it must use OPENCODE_DB or disable channel-specific databases.
      trustedInstallationChannel: switch (config.value(_OpenCodeConfigKey.binary)?.trim()) {
        null || "" => "latest",
        _ => null,
      },
    ).read(environment: environment, cancellation: cancellation);
  }

  @override
  bool get supportsPromptAttachments => true;

  @override
  Set<PluginMcpCapability> get mcpCapabilities => const {
    PluginMcpCapability.management,
    PluginMcpCapability.authentication,
  };

  /// MCP is read from a project or session directory; harness scope has none
  /// and answers unsupported scope.
  @override
  Set<PluginMcpScopeKind> get mcpScopes => const {PluginMcpScopeKind.project, PluginMcpScopeKind.session};

  /// Frozen ownership filename in the legacy shared runtime directory.
  static const String ownershipFileName = "opencode-processes.json";

  /// The OpenCode CLI options the bridge declares for this plugin. Names are
  /// bare; the bridge namespaces them to `--opencode-<name>`.
  static const List<PluginOption> cliOptions = [
    PluginValueOption.integer(
      name: _OpenCodeConfigKey.port,
      help: "Port for opencode server to listen on",
      defaultsTo: null,
      valueHelp: null,
    ),
    PluginValueOption(
      name: _OpenCodeConfigKey.host,
      help:
          "Host the opencode server binds to (auto-start) or is reached at "
          "(--opencode-no-auto-start). Defaults to 127.0.0.1. Use 0.0.0.0 to "
          "expose the server on all interfaces, e.g. inside a Docker container. "
          "Warning: 0.0.0.0 exposes the server (Basic-auth only) to your whole "
          "network.",
      defaultsTo: openCodeLoopbackHost,
      allowedValues: null,
      valueHelp: "host",
      validate: null,
    ),
    PluginFlagOption(
      name: _OpenCodeConfigKey.noAutoStart,
      help: "Skip auto-starting opencode server (use existing server)",
      defaultsTo: false,
      negatable: true,
    ),
    PluginValueOption(
      name: _OpenCodeConfigKey.password,
      help: "Override server password (auto-generated if not set)",
      defaultsTo: null,
      allowedValues: null,
      valueHelp: null,
      validate: null,
    ),
    PluginFlagOption(
      name: _OpenCodeConfigKey.noPassword,
      help:
          "Disable OpenCode server authentication (OpenCode 1 only; OpenCode 2 always requires a password, and "
          "its shared service brings its own)",
      defaultsTo: false,
      negatable: false,
    ),
    PluginValueOption(
      name: _OpenCodeConfigKey.binary,
      help: "Path to opencode binary",
      defaultsTo: null,
      allowedValues: null,
      valueHelp: null,
      validate: null,
    ),
    PluginFlagOption(
      name: _OpenCodeConfigKey.noSharedService,
      help:
          "Always start a private opencode server instead of using OpenCode 2's shared background "
          "service when it is running",
      defaultsTo: false,
      negatable: false,
    ),
  ];

  static const _attachWithoutPort = PluginConfigException(
    "The --opencode-no-auto-start flag requires --opencode-port to be set.",
  );

  /// Static counterpart of [validateConfig] for argument-parse-time callers.
  static void validateConfigValues(PluginConfig config) {
    if (config.flag(_OpenCodeConfigKey.noAutoStart) && config.intValue(_OpenCodeConfigKey.port) == null) {
      throw _attachWithoutPort;
    }
    if (config.flag(_OpenCodeConfigKey.noPassword) && config.value(_OpenCodeConfigKey.password) != null) {
      throw const PluginConfigException("The --opencode-no-password flag cannot be used with --opencode-password.");
    }
    // The host is used in both modes (bind target when managed, connect target
    // when attaching), so validate it up front — a malformed value would
    // otherwise only fail deep in start(), after the startup mutex has run and
    // the single-live-bridge replacement may have stopped a healthy resident.
    final host = config.value(_OpenCodeConfigKey.host)?.trim();
    if (host == null || host.isEmpty) {
      throw const PluginConfigException("The --opencode-host option cannot be empty.");
    }
    // Reject anything that isn't a bare host or IP literal: the value is built
    // into server URLs. A scheme/path/port typo like "http://127.0.0.1" throws
    // a FormatException; a value with an escapable delimiter (e.g. internal
    // whitespace) instead percent-escapes silently, so also require the parsed
    // host to round-trip unchanged.
    if (!_isWellFormedHost(host)) {
      throw PluginConfigException("The --opencode-host option must be a bare host or IP, got '$host'.");
    }
    // A non-loopback managed bind with auth disabled would expose an
    // unauthenticated OpenCode server on the network. Block that combination;
    // a wildcard/LAN bind with the default Basic-auth password stays allowed,
    // and --opencode-no-password on a loopback host stays allowed.
    if (!config.flag(_OpenCodeConfigKey.noAutoStart) &&
        config.flag(_OpenCodeConfigKey.noPassword) &&
        !_isLoopbackHost(host)) {
      throw PluginConfigException(
        "The --opencode-no-password flag cannot be combined with a non-loopback --opencode-host "
        "('$host') when auto-starting: it would expose an unauthenticated OpenCode server on the "
        "network. Use a loopback host or keep authentication enabled.",
      );
    }
  }

  /// The warning for an attach-mode server that did not answer at start. The
  /// bridge then keeps retrying with the OpenCode 1 adapter, so a 1.x server is
  /// picked up when it appears; a 2.x server is only recognised at start.
  @visibleForTesting
  static String attachUnreachableWarning({required int port, required String reason, required bool hasPassword}) {
    final passwordHint = hasPassword
        ? ""
        : " OpenCode 2.x always requires a password: pass it with --opencode-password.";
    return "[opencode] cannot reach OpenCode at port $port (auto-start disabled): $reason. "
        "The bridge starts degraded. Start the OpenCode server on that port: an OpenCode 1.x server is "
        "picked up automatically, and for OpenCode 2.x restart the bridge afterwards so it detects the "
        "version. Do not downgrade OpenCode.$passwordHint";
  }

  /// Whether [host] is a bare host or IP literal usable in a URL authority —
  /// i.e. it parses as a URI host and round-trips unchanged (case-insensitively).
  ///
  /// The round-trip catches values that `Uri` percent-escapes instead of
  /// rejecting (e.g. internal whitespace), which would otherwise pass and fail
  /// only later when a connection is attempted.
  static bool _isWellFormedHost(String host) {
    final Uri probe;
    try {
      probe = Uri(scheme: "http", host: host, port: 1);
    } on FormatException {
      return false;
    }
    return probe.host.toLowerCase() == host.toLowerCase();
  }

  /// Whether [host] only accepts connections from the local machine, so
  /// disabling authentication does not expose the server to the network.
  ///
  /// Uses [io.InternetAddress] loopback detection (the full `127.0.0.0/8` range
  /// and `::1`) rather than a string prefix, so a DNS name like `127.evil.com`
  /// is correctly treated as non-loopback. `localhost` is matched explicitly
  /// since it is a name, not a parseable IP literal.
  static bool _isLoopbackHost(String host) {
    if (host == "localhost") {
      return true;
    }
    return io.InternetAddress.tryParse(host)?.isLoopback ?? false;
  }

  @override
  String get id => Harness.opencode.name;

  @override
  String get displayName => "OpenCode";

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.native;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.project;

  @override
  PluginStateStorage get stateStorage => PluginStateStorage.legacySharedRuntime;

  @override
  List<PluginOption> get options => cliOptions;

  @override
  void validateConfig(PluginConfig config) => validateConfigValues(config);

  @override
  PluginResidencyPolicy residencyPolicy({required PluginConfig config}) {
    return config.flag(_OpenCodeConfigKey.noAutoStart)
        ? PluginResidencyPolicy.resident
        : PluginResidencyPolicy.transient;
  }

  @override
  PluginActivationPolicy activationPolicy({required PluginConfig config}) {
    return config.flag(_OpenCodeConfigKey.noAutoStart) ? PluginActivationPolicy.eager : PluginActivationPolicy.onDemand;
  }

  @override
  Set<PluginControlCapability> managementCapabilities({required PluginConfig config}) {
    if (config.flag(_OpenCodeConfigKey.noAutoStart)) {
      return const {PluginControlCapability.setupRefresh};
    }
    return {
      ...super.managementCapabilities(config: config),
      if (_supportsManagedInstall(config: config)) PluginControlCapability.install,
    };
  }

  /// Whether a managed start first looks for OpenCode 2's shared background
  /// server. Attach mode already names its server, and an explicit binary may
  /// belong to another OpenCode channel whose service file has another name.
  bool _sharesServer(PluginConfig config) {
    return !config.flag(_OpenCodeConfigKey.noAutoStart) &&
        !config.flag(_OpenCodeConfigKey.noSharedService) &&
        _explicitBin(config) == null;
  }

  /// OpenCode 2's shared background server: the running one, or one OpenCode
  /// starts from the provisioned binary. Using it keeps the bridge, the TUI and
  /// the desktop app on one server instead of two colliding on one database.
  /// `null` means the caller spawns a private server.
  ///
  /// A private server left by a replaced or crashed bridge is never reused, so
  /// it is reclaimed first, before a service can start on the same database.
  /// The private start reclaims it the same way.
  Future<OpenCodeSharedServerEndpoint?> _acquireSharedServer({
    required PluginHost host,
    required ManagedProcessService<OpenCodeOwnershipRecord> service,
  }) async {
    await service.cleanupStaleOwnedRuntimes(terminatedBridgeIdentities: host.bridge.terminatedBridgeIdentities);
    return await OpenCodeSharedServerService(
      repository: OpenCodeSharedServerRepository(
        registrationApi: const OpenCodeServiceRegistrationApi(),
        commandApi: OpenCodeServiceCommandApi(
          executor: HostProcessCommandExecutor(
            includeParentEnvironment: true,
            processes: host.processes,
            runInShell: io.Platform.isWindows,
            maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
          ),
        ),
        probeClientFactory: _probeClientFactory,
      ),
    ).acquire(binary: host.provisionedRuntimePath, environment: host.environment, startAborted: host.startAborted);
  }

  /// OpenCode 2 generates a password when none is set, so a private server
  /// started for `--opencode-no-password` would reject every bridge request
  /// until the health deadline on every port. Fails fast instead. A binary
  /// whose version cannot be read keeps the OpenCode 1 behaviour.
  Future<void> _rejectPasswordlessOpenCode2({required PluginHost host, required String executable}) async {
    const manifest = OpenCodeRuntimeManifest();
    final outcome = await RuntimeVersionValidator(
      commandExecutor: HostProcessCommandExecutor(
        includeParentEnvironment: true,
        processes: host.processes,
        runInShell: io.Platform.isWindows,
        maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
      ),
      manifest: manifest,
      probeTimeout: openCodeVersionProbeTimeout,
      executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
    ).probe(executable: executable, environment: host.environment);
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }
    if (outcome case RuntimeProbeReady(version: final SemanticRuntimeVersion runtimeVersion)
        when runtimeVersion.version.major >= 2) {
      throw PluginStartException.userFacing(
        "OpenCode ${runtimeVersion.raw} always requires a password, so --opencode-no-password works only with "
        "OpenCode 1. Remove the flag to let the bridge generate a password, or set one with --opencode-password.",
        cause: null,
      );
    }
  }

  String? _explicitBin(PluginConfig config) {
    final value = config.value(_OpenCodeConfigKey.binary)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Whether the pinned managed OpenCode runtime can be installed on request:
  /// no explicit binary override (that binary is authoritative) and a
  /// published release asset for this platform.
  bool _supportsManagedInstall({required PluginConfig config}) {
    if (_explicitBin(config) != null) return false;
    final PlatformTarget target;
    try {
      target = PlatformTarget.current();
    } on Object catch (error, stackTrace) {
      Log.w("[opencode] platform detection failed; managed install unavailable", error, stackTrace);
      return false;
    }
    return const OpenCodeRuntimeManifest().supportsManagedInstallOn(target: target);
  }

  @override
  Future<bool> needsManagedRuntimeUpgrade({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    if (!managementCapabilities(config: config).contains(PluginControlCapability.install)) return false;
    const manifest = OpenCodeRuntimeManifest();
    final executor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );
    return await const ManagedRuntimeComposition()
        .createUpgradeService(
          manifest: manifest,
          versionValidator: RuntimeVersionValidator(
            commandExecutor: executor,
            manifest: manifest,
            probeTimeout: openCodeVersionProbeTimeout,
            executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
          ),
        )
        .shouldUpgrade(environment: environment, stateDirectory: stateDirectory);
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
    const manifest = OpenCodeRuntimeManifest();
    final commandExecutor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: null,
    );
    final pathVersionValidator = RuntimeVersionValidator(
      commandExecutor: HostProcessCommandExecutor(
        includeParentEnvironment: true,
        processes: processes,
        runInShell: io.Platform.isWindows,
        maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
      ),
      manifest: manifest,
      probeTimeout: openCodeVersionProbeTimeout,
      executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
    );
    final httpClient = http.Client();
    try {
      final installService = const ManagedRuntimeComposition().createInstaller(
        manifest: manifest,
        commandExecutor: commandExecutor,
        downloadClient: BinaryDownloadClient(httpClient: httpClient),
        candidateValidator: RuntimeVersionValidator(
          commandExecutor: commandExecutor,
          manifest: manifest,
          probeTimeout: openCodeVersionProbeTimeout,
          executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
        ),
        pathAuthority: RuntimeVersionManagedRuntimePathAuthority(
          manifest: manifest,
          versionValidator: pathVersionValidator,
        ),
        assetResolver: ({required target}) async => manifest.assetFor(target: target),
      );
      yield* installService.install(
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
    if (config.flag(_OpenCodeConfigKey.noAutoStart)) {
      return const PluginSetupReady();
    }

    final explicitBin = _explicitBin(config);
    const manifest = OpenCodeRuntimeManifest();
    final executor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );

    /// What to tell the user when no usable runtime was found and Sesori can
    /// install one: a superseded managed install needs updating, anything else
    /// needs a first install.
    String missingRuntimeHint() {
      const inventory = ManagedRuntimeInventory(manifest: manifest);
      return inventory.hasOutdatedVersion(stateDirectory: stateDirectory)
          ? "This bridge needs a newer OpenCode. Install it from Sesori to update the managed runtime."
          : "Install OpenCode from Sesori, or install it locally and retry setup detection.";
    }

    final selection =
        await ManagedRuntimeSelectionService(
          manifest: manifest,
          versionValidator: RuntimeVersionValidator(
            commandExecutor: executor,
            manifest: manifest,
            probeTimeout: openCodeVersionProbeTimeout,
            executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
          ),
          inventory: const ManagedRuntimeInventory(manifest: manifest),
        ).select(
          explicitExecutablePath: explicitBin,
          fallbackExecutableCandidates: const [],
          environment: environment,
          stateDirectory: stateDirectory,
          abortSignal: StartAbortSignal.never,
        );
    final ManagedRuntimeRejection rejection;
    switch (selection) {
      case ManagedRuntimeSelected(:final version):
        return PluginSetupReady.versioned(runtimeVersion: version.raw);
      case ManagedRuntimeNotSelected(:final primaryRejection):
        rejection = primaryRejection;
    }
    if (selection is ManagedRuntimePathNotSelected) {
      return switch (rejection) {
        ManagedRuntimeVersionRejected(:final version) => PluginSetupRuntimeOutdated(
          actionHint: "Update the global OpenCode installation to ${manifest.minPathVersion.raw} or newer.",
          runtimeVersion: version.raw,
        ),
        ManagedRuntimeProbeRejected() => const PluginSetupUnknown(
          actionHint:
              "The global OpenCode installation could not be verified. Check it locally and retry setup detection.",
        ),
      };
    }
    return switch (rejection) {
      ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) => PluginSetupRuntimeMissing(
        actionHint: explicitBin == null
            ? missingRuntimeHint()
            : "Fix the configured OpenCode binary path, then restart the bridge.",
      ),
      ManagedRuntimeVersionRejected() when explicitBin == null => PluginSetupRuntimeMissing(
        actionHint: missingRuntimeHint(),
      ),
      ManagedRuntimeVersionRejected() => const PluginSetupUnavailable(
        actionHint: "The configured OpenCode binary is too old. Update it and restart the bridge.",
      ),
      ManagedRuntimeProbeRejected(outcome: RuntimeProbeNonZeroExit()) when explicitBin == null =>
        PluginSetupRuntimeMissing(actionHint: missingRuntimeHint()),
      ManagedRuntimeProbeRejected(outcome: RuntimeProbeNonZeroExit() || RuntimeProbeTimedOut()) =>
        const PluginSetupUnknown(
          actionHint: "OpenCode did not answer its setup check. Verify the local installation and retry.",
        ),
      ManagedRuntimeProbeRejected(outcome: RuntimeProbeUnrecognized()) => const PluginSetupUnknown(
        actionHint: "OpenCode returned an unrecognized version. Update OpenCode and retry.",
      ),
      ManagedRuntimeProbeRejected(outcome: RuntimeProbeFailed()) => const PluginSetupUnknown(
        actionHint: "OpenCode setup could not be determined. Verify the local installation and retry.",
      ),
    };
  }

  @override
  Future<PluginCatalogSnapshotResult> readCatalogSnapshot({
    required PluginConfig config,
    required Map<String, String> environment,
    required PluginCatalogCancellationSignal cancellation,
  }) {
    if (config.flag(_OpenCodeConfigKey.noAutoStart)) {
      return Future.value(const PluginCatalogSnapshotUnavailable());
    }
    return _catalogSnapshotReader(
      config: config,
      environment: environment,
      cancellation: cancellation,
    );
  }

  /// Resolves an existing OpenCode runtime (a recent-enough PATH install or the
  /// pinned managed runtime when already installed). Skipped in attach mode and when an
  /// explicit `--opencode-bin` is set (both already have their binary). The
  /// resolved launch path is surfaced via [ProvisionReady]; a failure is
  /// non-fatal and `start()` degrades.
  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    final config = host.config;
    if (config.flag(_OpenCodeConfigKey.noAutoStart)) {
      return;
    }
    if (_explicitBin(config) != null) {
      return;
    }

    yield* _buildProvisionService(host: host).provision(host: host, explicitExecutablePath: null);
  }

  /// Assembles the resolver from the host's process service so helper
  /// commands go through the host, never a raw spawn.
  ManagedRuntimeProvisionService _buildProvisionService({
    required PluginHost host,
  }) {
    const manifest = OpenCodeRuntimeManifest();
    final commandExecutor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: host.processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: null,
    );
    return const ManagedRuntimeComposition().createProvisioner(
      manifest: manifest,
      versionValidator: RuntimeVersionValidator(
        commandExecutor: commandExecutor,
        manifest: manifest,
        probeTimeout: openCodeVersionProbeTimeout,
        executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
      ),
      // OpenCode has no desktop app bundling a CLI.
      fallbackExecutableCandidates: const [],
    );
  }

  @override
  Future<ManagedRuntimeBridgePlugin<OpenCodeOwnershipRecord, OpenCodeManagedApi>> start(PluginHost host) async {
    // The OpenCode database is intentionally left untouched. Previous
    // auto-vacuum maintenance has been removed because it interfered with
    // the database while OpenCode was running.
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    final config = host.config;
    final requestedPort = config.intValue(_OpenCodeConfigKey.port);
    final noPassword = config.flag(_OpenCodeConfigKey.noPassword);
    // Trim, and treat a blank value as "no password supplied" so it is
    // auto-generated rather than demanded.
    final providedPassword = config.value(_OpenCodeConfigKey.password)?.normalize();

    // The host OpenCode binds to (managed mode) or is reached at (attach mode);
    // defaults to 127.0.0.1. The connect host is what the bridge dials for
    // HTTP/SSE/health — loopback when the bind host is a non-connectable
    // wildcard (0.0.0.0 / ::), otherwise the bind host itself.
    final bindHost = (config.value(_OpenCodeConfigKey.host) ?? openCodeLoopbackHost).trim();
    final connectHost = resolveOpenCodeConnectHost(bindHost: bindHost);

    const mapper = OpenCodeRecordMapper();

    final service = ManagedProcessService<OpenCodeOwnershipRecord>(
      ownershipRepository: HostJsonRuntimeOwnershipRepository<OpenCodeOwnershipRecord>(
        store: host.store,
        mapper: mapper,
        fileName: ownershipFileName,
        clock: host.clock,
      ),
      mapper: mapper,
      processes: host.processes,
      bridge: host.bridge,
      clock: host.clock,
      isWindows: io.Platform.isWindows,
      runtimeId: "opencode",
      gracefulShutdownWait: openCodeGracefulShutdownWait,
    );

    // OpenCode 2's shared server when it applies; otherwise a private server below.
    final sharedEndpoint = _sharesServer(config) ? await _acquireSharedServer(host: host, service: service) : null;
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    late final ManagedRuntimeSpec<OpenCodeOwnershipRecord> spec;
    ManagedRuntimeHandle<OpenCodeOwnershipRecord>? handle;
    final int port;
    final String serverUrl;
    final String? apiPassword;
    final _OpenCodeServerMode mode;

    if (config.flag(_OpenCodeConfigKey.noAutoStart)) {
      mode = _OpenCodeServerMode.attached;
      // Attach mode: probe an existing server, never own or kill it.
      final attachPort = requestedPort ?? (throw _attachWithoutPort);
      port = attachPort;
      // Structured Uri so an IPv6 literal connect host is bracketed correctly.
      serverUrl = Uri(scheme: "http", host: connectHost, port: attachPort).toString();
      apiPassword = noPassword ? null : providedPassword;
      spec = buildOpenCodeManagedRuntimeSpec(
        host: host,
        executablePath: null,
        password: noPassword ? null : providedPassword,
        portPolicy: ExplicitPortPolicy(port: attachPort),
        probeClientFactory: _probeClientFactory,
        bindHost: bindHost,
        connectHost: connectHost,
      );
      try {
        handle = await service.attach(spec: spec, port: attachPort, startAborted: host.startAborted);
        Log.i("[opencode] using existing server at $serverUrl (auto-start disabled)");
      } on PluginStartAbortedException {
        rethrow;
      } on PluginStartException catch (error) {
        Log.w(
          attachUnreachableWarning(port: attachPort, reason: error.message, hasPassword: apiPassword != null),
        );
        handle = null;
      }
    } else if (sharedEndpoint != null) {
      mode = _OpenCodeServerMode.shared;
      // Shared mode: attach to OpenCode's own background server, never own,
      // kill or restart it. Everything comes from its registration, not config.
      if (noPassword) {
        Log.w(
          "[opencode] --opencode-no-password is ignored: the shared OpenCode ${sharedEndpoint.version} service "
          "brings its own password",
        );
      }
      port = sharedEndpoint.port;
      serverUrl = sharedEndpoint.url;
      apiPassword = sharedEndpoint.password;
      spec = buildOpenCodeManagedRuntimeSpec(
        host: host,
        executablePath: null,
        password: sharedEndpoint.password,
        portPolicy: ExplicitPortPolicy(port: port),
        probeClientFactory: _probeClientFactory,
        bindHost: sharedEndpoint.host,
        connectHost: sharedEndpoint.host,
      );
      try {
        handle = await service.attach(spec: spec, port: port, startAborted: host.startAborted);
        Log.i("[opencode] using the shared OpenCode ${sharedEndpoint.version} service at $serverUrl");
      } on PluginStartAbortedException {
        rethrow;
      } on PluginStartException catch (error) {
        Log.w(
          "[opencode] the shared OpenCode service at $serverUrl stopped answering: ${error.message}. "
          "Starting degraded; the next request looks for the service again.",
        );
        handle = null;
      }
    } else {
      mode = _OpenCodeServerMode.managed;
      // Managed mode: spawn and own a new server.
      final serverPassword = noPassword ? null : (providedPassword ?? generateOpenCodePassword(random: _random));
      apiPassword = serverPassword;
      // Precedence: an explicit --opencode-bin wins (trusted, no version gate),
      // else the path ensureRuntime resolved (a recent PATH install or the
      // managed download), exposed via the host.
      final resolvedExecutable = _explicitBin(config) ?? host.provisionedRuntimePath;

      if (resolvedExecutable == null) {
        // Runtime provisioning failed and no explicit binary was given. Stay
        // alive in a degraded state instead of failing the whole bridge: bind a
        // placeholder server URL the background cold-start keeps retrying,
        // exactly as the attach-unreachable path below does. A bridge restart
        // re-attempts provisioning.
        Log.w(
          "[opencode] no runnable OpenCode binary available; starting degraded. "
          "Install OpenCode or pass --opencode-bin, then restart.",
        );
        // Honor an explicit --opencode-port so the degraded cold-start keeps
        // retrying the address the user actually configured (otherwise a bridge
        // started for port 5000 would silently retry 4096).
        port = requestedPort ?? openCodeDefaultPort;
        // Structured Uri so an IPv6 literal connect host is bracketed correctly.
        serverUrl = Uri(scheme: "http", host: connectHost, port: port).toString();
        spec = buildOpenCodeManagedRuntimeSpec(
          host: host,
          executablePath: null,
          password: serverPassword,
          portPolicy: ExplicitPortPolicy(port: port),
          probeClientFactory: _probeClientFactory,
          bindHost: bindHost,
          connectHost: connectHost,
        );
        handle = null;
      } else {
        final executablePath = resolvedExecutable;
        if (noPassword) {
          await _rejectPasswordlessOpenCode2(host: host, executable: executablePath);
        }

        final RuntimePortPolicy portPolicy;
        if (requestedPort != null) {
          Log.d("[opencode] starting on port $requestedPort");
          portPolicy = ExplicitPortPolicy(port: requestedPort);
        } else {
          Log.d("[opencode] starting on a dynamic port");
          portPolicy = DynamicPortPolicy(
            candidates: openCodeDynamicCandidates(candidates: _candidatePorts, random: _random),
          );
        }

        spec = buildOpenCodeManagedRuntimeSpec(
          host: host,
          executablePath: executablePath,
          password: serverPassword,
          portPolicy: portPolicy,
          probeClientFactory: _probeClientFactory,
          bindHost: bindHost,
          connectHost: connectHost,
        );

        // start() cleans up stale owned runtimes, selects a port, spawns, and
        // confirms health before returning — rolling everything back (and throwing
        // PluginStartException / PluginStartAbortedException) on failure. The
        // replaced-bridge identities authorize cleanup to reclaim records owned
        // by a bridge this one just replaced, even when its pid still looks live.
        handle = await service.start(
          spec: spec,
          terminatedBridgeIdentities: host.bridge.terminatedBridgeIdentities,
          startAborted: host.startAborted,
        );
        port = handle.port;
        // Structured Uri so an IPv6 literal connect host is bracketed correctly.
        serverUrl = Uri(scheme: "http", host: connectHost, port: handle.port).toString();
        Log.d("[opencode] started on port ${handle.port}");
      }
    }

    // Probe before the late-abort check so an abort during the probe is honored.
    // With no server yet, keep v1 recovery; a late v2 attach requires restart.
    // The shared server's discovery already established its v2 version.
    final OpenCodeProtocol protocol = switch (sharedEndpoint) {
      OpenCodeSharedServerEndpoint(:final version) => OpenCodeProtocolV2(version: version),
      null when handle == null => const OpenCodeProtocolV1(),
      null => await probeOpenCodeProtocol(
        port: port,
        password: apiPassword,
        clientFactory: _probeClientFactory,
        host: connectHost,
        timeout: openCodeProbeTimeout,
      ),
    };

    // Honor a late abort: a managed start the supervisor returned just as the
    // bridge aborted must release the owned child before we surface it.
    if (host.startAborted.isAborted) {
      if (handle case OwnedRuntimeHandle(:final record)) {
        await service.stopOwnedRuntime(record: record);
      }
      throw const PluginStartAbortedException();
    }

    // Older v2 releases have already migrated the database: never suggest v1.
    if (protocol case OpenCodeProtocolV2(:final version) when version.version.compareTo(openCodeMinimumV2Version) < 0) {
      if (handle case OwnedRuntimeHandle(:final record)) {
        await service.stopOwnedRuntime(record: record);
      }
      throw PluginStartException.userFacing(
        "OpenCode ${version.raw} requires an update to $openCodeMinimumV2Version or newer; "
        "do not downgrade OpenCode because its database has already migrated",
        cause: null,
      );
    }

    final reporter = ManagedRuntimeStatusReporter(
      status: PluginStatusController(initial: const PluginStarting()),
      clock: host.clock,
      degradedDebounce: openCodeDegradedDebounce,
      // A shared service can restart or move; failing lets the next request
      // run discovery again. Attach and managed servers cannot be re-found, so
      // they keep retrying the same address.
      disconnectOutcome: mode == _OpenCodeServerMode.shared
          ? ManagedRuntimeDisconnectOutcome.fail
          : ManagedRuntimeDisconnectOutcome.degrade,
    );

    // Construct and arm the exit monitor with bounded restart: an unexpected
    // child exit restarts on the address-frozen port with backoff, surfacing
    // PluginFailed only when the attempts are exhausted or the port never
    // frees. An attached (un-owned) handle has no child, so arm() is a no-op.
    final monitor = ManagedRuntimeMonitor<OpenCodeOwnershipRecord>(
      service: service,
      spec: spec,
      status: reporter.status,
      clock: host.clock,
      runtimeId: "opencode",
      restartPolicy: buildOpenCodeRestartPolicy(),
    );
    if (handle != null) {
      monitor.arm(handle);
    }

    final api = _buildApi(
      protocol: protocol,
      serverUrl: serverUrl,
      password: apiPassword,
      onConnected: reporter.markConnected,
      onDisconnected: reporter.markDisconnected,
    );

    final plugin = ManagedRuntimeBridgePlugin<OpenCodeOwnershipRecord, OpenCodeManagedApi>(
      api: api,
      managedApi: api,
      reporter: reporter,
      monitor: monitor,
      service: service,
      diagnostics: PluginDiagnostics(
        pluginId: Harness.opencode.name,
        endpoint: serverUrl,
        details: <String, String>{"port": "$port", "mode": mode.name},
      ),
      displayName: "OpenCode",
      logContext: "opencode",
      interruptOwnedOnly: true,
      onStartWarmUp: api.warmUpCommandCatalog,
    );

    if (handle == null) {
      // Attach probe failed: the server is already known to be unreachable, and
      // the cold-start has no bound of its own — a wrong localhost process that
      // accepts but never answers would hang start() under the bridge's startup
      // mutex. Keep the legacy fail-soft shape instead: report degraded now and
      // run the cold-start in the background; the SSE stream keeps retrying and
      // recovers the tracker when the server appears. In shared mode the
      // reporter fails the generation after the debounce instead.
      reporter.markDegradedNow();
      unawaited(
        api.initialize().catchError((Object error, StackTrace stackTrace) {
          Log.w("[opencode] background cold-start did not complete cleanly", error, stackTrace);
        }),
      );
    } else {
      // Await cold-start (previously fire-and-forget). A failure leaves the
      // plugin started but degraded rather than failing the whole bridge — the
      // server answered a health probe, so it is addressable; the SSE stream
      // keeps retrying and recovers the tracker.
      //
      // The await is bounded by [_coldStartBudget]: a service that passed the
      // health probe but stalls a REST call must not hang start() under the
      // bridge's cross-instance startup mutex. Past the budget the cold-start
      // keeps running in the background and the plugin starts degraded.
      await ManagedRuntimeColdStartService(
        budget: _coldStartBudget,
        logTag: "opencode",
      ).run(coldStart: api.initialize(), reporter: reporter);
    }

    // The cold-start is a phase boundary like any other: an abort observed here
    // must roll back everything acquired so far (api/SSE transport, monitor,
    // the owned child) before surfacing, or an aborted start leaks a live
    // runtime. The wrapper's shutdown owns exactly that ordered teardown.
    if (host.startAborted.isAborted) {
      try {
        await plugin.shutdown(budget: null);
      } on Object catch (error, stackTrace) {
        Log.e("[opencode] rollback after aborted start failed", error, stackTrace);
      }
      throw const PluginStartAbortedException();
    }

    return plugin;
  }
}
