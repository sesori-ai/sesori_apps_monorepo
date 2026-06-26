import 'dart:io';

import 'package:args/args.dart' show ArgParserException;
import 'package:args/command_runner.dart' as cli;
import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/api/bridge_settings_api.dart';
import 'package:sesori_bridge/src/api/default_editor_api.dart';
import 'package:sesori_bridge/src/api/wake_lock_client.dart';
import 'package:sesori_bridge/src/auth/bridge_registration_api.dart';
import 'package:sesori_bridge/src/auth/bridge_registration_repository.dart';
import 'package:sesori_bridge/src/auth/bridge_registration_service.dart';
import 'package:sesori_bridge/src/auth/token.dart';
import 'package:sesori_bridge/src/auth/token_manager.dart';
import 'package:sesori_bridge/src/bridge/foundation/device_type_detector.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner_command_executor.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_cli_dispatch.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_logout_runner.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_runtime_runner.dart';
import 'package:sesori_bridge/src/bridge/runtime/plugin_cli_options_mapper.dart';
import 'package:sesori_bridge/src/bridge/runtime/plugin_registry.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
import 'package:sesori_bridge/src/repositories/default_editor_repository.dart';
import 'package:sesori_bridge/src/repositories/wake_lock_repository.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/api/terminal_prompt_api.dart';
import 'package:sesori_bridge/src/server/repositories/bridge_instance_repository.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/repositories/terminal_prompt_repository.dart';
import 'package:sesori_bridge/src/server/services/bridge_instance_service.dart';
import 'package:sesori_bridge/src/services/bridge_config_service.dart';
import 'package:sesori_bridge/src/services/sleep_prevention_service.dart';
import 'package:sesori_bridge/src/updater/api/checksum_manifest_api.dart';
import 'package:sesori_bridge/src/updater/api/github_releases_api.dart';
import 'package:sesori_bridge/src/updater/api/managed_runtime_manifest_api.dart';
import 'package:sesori_bridge/src/updater/api/platform_update_api.dart';
import 'package:sesori_bridge/src/updater/api/update_attempt_api.dart';
import 'package:sesori_bridge/src/updater/api/update_cache_api.dart';
import 'package:sesori_bridge/src/updater/api/update_log_api.dart';
import 'package:sesori_bridge/src/updater/formatters/update_command_formatter.dart';
import 'package:sesori_bridge/src/updater/foundation/filesystem_cleaner.dart';
import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:sesori_bridge/src/updater/foundation/update_lock.dart';
import 'package:sesori_bridge/src/updater/models/distribution_target.dart';
import 'package:sesori_bridge/src/updater/models/explicit_update_outcome.dart';
import 'package:sesori_bridge/src/updater/repositories/release_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/update_artifact_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/update_attempt_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/update_installation_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/update_log_repository.dart';
import 'package:sesori_bridge/src/updater/services/managed_runtime_path_service.dart';
import 'package:sesori_bridge/src/updater/services/manual_update_service.dart';
import 'package:sesori_bridge/src/updater/services/update_apply_service.dart';
import 'package:sesori_bridge/src/updater/services/update_install_service.dart';
import 'package:sesori_bridge/src/version.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart'
    show BridgePluginDescriptor, Console, Log, LogLevel, PluginConfig, PluginConfigException, ProcessUser, ServerClock;

const String _defaultRelayURL = 'wss://relay.sesori.com';
const String _defaultAuthURL = 'https://api.sesori.com';

class RunCommand extends cli.Command<void> {
  @override
  final name = 'run';

  @override
  final description = 'Run the Sesori bridge (default)';

  final BridgePluginDescriptor _selectedPlugin;

  /// Maps the selected plugin's options to/from the CLI parser, namespaced
  /// under its id (e.g. `--opencode-host`).
  final PluginCliOptionsMapper _pluginCliMapper;

  /// Deferred plugin-selection failure (bad `enabledPlugins`): only running
  /// the bridge needs a valid selection, so the error surfaces here instead
  /// of blocking informational commands like `--help`, logout, or config.
  final String? _selectionError;

  RunCommand({required BridgePluginDescriptor selectedPlugin, required String? selectionError})
    : _selectedPlugin = selectedPlugin,
      _pluginCliMapper = PluginCliOptionsMapper(pluginId: selectedPlugin.id),
      _selectionError = selectionError {
    argParser
      ..addFlag(
        'version',
        negatable: false,
        help: 'Show version and exit',
      )
      ..addOption('relay', defaultsTo: _defaultRelayURL, help: 'Relay server URL')
      // The selection was already scanned out of the raw argv to build this
      // parser (see PluginSelector); registering the option here makes the
      // full parse accept it and reject unknown ids via the allowed list.
      // --help therefore documents the *selected* plugin's options.
      ..addOption(
        'plugin',
        help: 'Plugin backend to run. Defaults to "enabledPlugins" in the bridge settings, then opencode',
        allowed: [for (final plugin in knownPlugins) plugin.id],
      );
    // The selected plugin contributes its own CLI options, namespaced under the
    // plugin id (for OpenCode: --opencode-port, --opencode-host, etc.).
    _pluginCliMapper.register(parser: argParser, options: _selectedPlugin.options);
    argParser
      ..addOption('auth-backend', defaultsTo: '', help: 'Auth backend URL')
      ..addOption(
        'debug-port',
        defaultsTo: '',
        help: 'Start a debug HTTP server on this port (for Postman/curl testing)',
      )
      ..addOption(
        'log-level',
        defaultsTo: 'info',
        allowed: ['verbose', 'debug', 'info', 'warning', 'error'],
        help: 'Minimum log level',
      )
      // Supervised mode: the desktop GUI passes the loopback control-channel
      // URL here. Hidden because it is an internal GUI↔helper contract, not a
      // user-facing flag. The per-spawn secret is delivered off-argv (stdin),
      // never as a flag (ADR A8). Absent ⇒ standalone behaviour is unchanged.
      ..addOption('control-url', hide: true, help: 'Internal: supervised-mode control channel URL');
  }

  @override
  Future<void> run() async {
    final results = argResults!;

    if (results['version'] as bool) {
      stdout.writeln(appVersion);
      return;
    }

    final selectionError = _selectionError;
    if (selectionError != null) {
      usageException(selectionError);
    }

    final BridgeCliOptions options;
    final PluginConfig pluginConfig;
    final List<String> pluginConfigDeprecations;
    try {
      // Plugin option validate hooks and config validation run at
      // argument-parse time — strictly before the startup mutex, so a typo'd
      // flag can never terminate a healthy resident bridge.
      final parsed = _pluginCliMapper.parse(results: results, options: _selectedPlugin.options);
      pluginConfig = parsed.config;
      pluginConfigDeprecations = parsed.deprecations;
      _selectedPlugin.validateConfig(pluginConfig);
      options = BridgeCliOptions.fromArgResults(
        cliArgs: globalResults!.arguments,
        results: results,
        environment: Platform.environment,
        defaultAuthUrl: _defaultAuthURL,
      );
    } on ArgParserException catch (e) {
      usageException(e.message);
    } on PluginConfigException catch (e) {
      usageException(e.message);
    }
    Log.level = LogLevel.values.byName(options.logLevelName);

    // Surface deprecated-flag usage to the user directly. The legacy flag still
    // worked; this only nudges the user toward the namespaced form, so it must
    // be visible regardless of --log-level and is not a diagnostic.
    pluginConfigDeprecations.forEach(Console.warning);

    final settingsRepository = BridgeSettingsRepository(api: BridgeSettingsApi());
    final sleepPreventionService = SleepPreventionService(
      bridgeSettingsRepository: settingsRepository,
      wakeLockRepository: WakeLockRepository(
        client: WakeLockClient.forPlatform(),
      ),
      deviceTypeDetector: DeviceTypeDetector(
        processRunner: ProcessRunner(),
        platformChecker: DefaultPlatformChecker(),
      ),
    );

    try {
      final mode = await sleepPreventionService.applyConfiguredMode();
      Log.i('Sleep prevention mode: ${mode.name}');
    } on Object catch (error) {
      Log.w('Sleep prevention failed: $error');
    }

    final exitCode = await runBridgeApp(
      options: options,
      pluginConfig: pluginConfig,
      pluginId: _selectedPlugin.id,
    );
    await sleepPreventionService.dispose();
    exit(exitCode);
  }
}

class LogoutCommand extends cli.Command<void> {
  @override
  final name = 'logout';

  @override
  final description = 'Clear stored authentication tokens';

  LogoutCommand() {
    argParser.addOption('auth-backend', defaultsTo: '', help: 'Auth backend URL');
  }

  @override
  Future<void> run() async {
    final authBackendUrl = BridgeCliOptions.resolveAuthBackendUrl(
      authBackendFlag: argResults!['auth-backend'] as String,
      environment: Platform.environment,
      defaultAuthUrl: _defaultAuthURL,
    );
    final systemProcessApi = SystemProcessApi(
      processRunner: ProcessRunner(),
      clock: const ServerClock(),
      isWindows: Platform.isWindows,
      platform: Platform.operatingSystem,
    );
    final currentUser = ProcessUser.fromRawUser(
      Platform.environment['USER'] ?? Platform.environment['USERNAME'],
    );
    final bridgeInstanceRepository = BridgeInstanceRepository(
      api: systemProcessApi,
      currentUser: currentUser,
    );
    final terminalPromptRepository = TerminalPromptRepository(
      api: TerminalPromptApi(
        stdin: stdin,
        stdout: stdout,
        environment: Platform.environment,
      ),
    );
    final logoutRunner = BridgeLogoutRunner(
      bridgeInstanceRepository: bridgeInstanceRepository,
      bridgeInstanceService: BridgeInstanceService(
        bridgeInstanceRepository: bridgeInstanceRepository,
        terminalPromptRepository: terminalPromptRepository,
        processRepository: ProcessRepository(
          api: systemProcessApi,
          currentUser: currentUser,
        ),
        clock: const ServerClock(),
      ),
      terminalPromptRepository: terminalPromptRepository,
      unregisterBridge: () => _unregisterBridgeRegistration(authBackendUrl: authBackendUrl),
    );

    final result = await logoutRunner.logout(currentPid: pid);
    switch (result.status) {
      case BridgeLogoutStatus.loggedOut:
        Console.message('Authentication cleared. You will be asked to log in on next start.');
      case BridgeLogoutStatus.loggedOutWithRunningBridges:
        Console.message('Authentication cleared. You will be asked to log in on next start.');
        Console.message(
          'Warning: ${result.runningBridgeCount} bridge instance(s) are still running '
          'and may re-create tokens when they refresh their session.',
        );
      case BridgeLogoutStatus.cancelled:
        Console.message('Logout cancelled; stored tokens were not cleared.');
        exitCode = 1;
      case BridgeLogoutStatus.failed:
        Console.error('Error: Failed to clear authentication tokens: ${result.error}');
        exitCode = 1;
    }
  }
}

/// Removes this bridge's registration on the auth server before the token
/// file is deleted. Callers treat any failure as non-fatal.
Future<void> _unregisterBridgeRegistration({required String authBackendUrl}) async {
  final TokenData tokens;
  try {
    tokens = await loadTokens();
  } on Object catch (e) {
    // No stored tokens — nothing registered to remove. A corrupt token file
    // also lands here; logout still proceeds, but leave a trace.
    Log.w('Skipping bridge unregistration; could not load tokens: $e');
    return;
  }
  if (tokens.bridgeId == null) {
    return;
  }

  final httpClient = http.Client();
  final tokenManager = TokenManager(
    initialToken: tokens.accessToken,
    authBackendUrl: authBackendUrl,
    loadTokens: loadTokens,
    saveTokens: saveTokens,
  );
  try {
    final registrationService = BridgeRegistrationService(
      repository: BridgeRegistrationRepository(
        api: BridgeRegistrationApi(authBackendUrl: authBackendUrl, client: httpClient),
      ),
      tokenRefresher: tokenManager,
      loadTokens: loadTokens,
      saveTokens: saveTokens,
      hostName: Platform.localHostname,
      platform: BridgeRegistrationService.currentPlatformName(),
    );
    await registrationService.unregister().timeout(const Duration(seconds: 10));
  } finally {
    tokenManager.dispose();
    httpClient.close();
  }
}

class ConfigCommand extends cli.Command<void> {
  @override
  final name = 'config';

  @override
  final description = 'Manage bridge configuration';

  ConfigCommand() {
    addSubcommand(ConfigTrackCommand());
    addSubcommand(ConfigEditCommand());
  }
}

class ConfigEditCommand extends cli.Command<void> {
  @override
  final name = 'edit';

  @override
  final description = 'Open the bridge configuration file in your default editor';

  @override
  Future<void> run() async {
    final api = BridgeSettingsApi();
    final settingsRepository = BridgeSettingsRepository(api: api);
    final editorRepository = DefaultEditorRepository(
      api: DefaultEditorApi.forPlatform(
        processRunner: ProcessRunner(),
      ),
    );
    final configService = BridgeConfigService(
      bridgeSettingsRepository: settingsRepository,
      defaultEditorRepository: editorRepository,
    );

    final configFilePath = await configService.openConfigFile();
    Console.message('Opening config file at $configFilePath');
  }
}

class ConfigTrackCommand extends cli.Command<void> {
  @override
  final name = 'track';

  @override
  final description = 'Show or set the bridge update track (stable|internal)';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      usageException('Unable to read command arguments.');
    }
    final rest = results.rest;
    final repository = BridgeSettingsRepository(api: BridgeSettingsApi());

    if (rest.isEmpty) {
      final settings = await repository.loadSettings();
      stdout.writeln('Release track: ${settings.releaseTrack.wireValue}');
      return;
    }

    if (rest.length > 1) {
      usageException('Expected a single track value: stable or internal.');
    }

    final ReleaseTrack track = _parseTrackArgument(rest.single);
    await repository.updateReleaseTrack(track: track);
    stdout.writeln('Release track set to ${track.wireValue}.');
    if (track == ReleaseTrack.internal) {
      stdout.writeln(
        'Warning: internal builds are pre-release and may be unstable. '
        'The bridge will auto-update to the latest internal build on next start.',
      );
    }
    stdout.writeln('Restart sesori-bridge to apply.');
  }

  ReleaseTrack _parseTrackArgument(String value) {
    switch (value) {
      case 'stable':
        return ReleaseTrack.stable;
      case 'internal':
        return ReleaseTrack.internal;
      default:
        usageException('Track must be "stable" or "internal".');
    }
  }
}

class UpdateCommand extends cli.Command<void> {
  @override
  final name = 'update';

  @override
  final description = 'Update the bridge to the latest release on your track, then exit';

  UpdateCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help:
          'Reinstall the latest release for your track even if you are already on it, '
          'and switch from an internal build back to stable when the track is stable.',
    );
  }

  @override
  Future<void> run() async {
    final bool force = argResults!['force'] as bool;
    final environment = Platform.environment;
    final managedRuntimePaths = const ManagedRuntimePathService().currentPaths(environment: environment);
    final installRoot = managedRuntimePaths.installRoot;
    const clock = Clock();
    const filesystemCleaner = FilesystemCleaner();
    final releaseTrack = await _resolveReleaseTrack();

    // Opportunistically authenticate GitHub release checks; the first non-empty
    // of GITHUB_TOKEN / GH_TOKEN lifts the 60/hour anonymous limit to 5000/hour.
    final githubToken =
        [
              environment['GITHUB_TOKEN'],
              environment['GH_TOKEN'],
            ]
            .map((token) => token?.trim())
            .firstWhere(
              (token) => token != null && token.isNotEmpty,
              orElse: () => null,
            );

    final httpClient = http.Client();
    try {
      final processRunner = ProcessRunner();
      final logRepository = UpdateLogRepository(
        api: UpdateLogApi(installRoot: installRoot, clock: clock),
      );
      final attemptRepository = UpdateAttemptRepository(api: UpdateAttemptApi(installRoot: installRoot));
      final installationRepository = UpdateInstallationRepository(
        platformUpdateApi: PlatformUpdateApi.forPlatform(processRunner: processRunner),
        manifestApi: const ManagedRuntimeManifestApi(),
      );
      final updateLock = UpdateLock(currentPid: pid, processRunner: processRunner, clock: clock);
      final distributionTarget = currentDistributionTarget();
      final commandExecutor = ProcessRunnerCommandExecutor(processRunner: processRunner);

      final manualUpdateService = ManualUpdateService(
        releaseRepository: ReleaseRepository(
          api: GitHubReleasesApi(httpClient: httpClient, authToken: githubToken),
          cache: UpdateCacheApi(cacheDirectory: managedRuntimePaths.cacheDirectory, clock: clock),
          currentVersion: appVersion,
          target: distributionTarget,
          track: releaseTrack,
        ),
        updateInstallService: UpdateInstallService(
          updateArtifactRepository: UpdateArtifactRepository(
            downloadClient: BinaryDownloadClient(httpClient: httpClient),
            checksumManifestApi: ChecksumManifestApi(httpClient: httpClient),
            checksumValidator: ChecksumValidator(),
            archiveExtractor: ArchiveExtractor(commandExecutor: commandExecutor),
            archiveFormat: distributionTarget.archiveFormat,
          ),
          filesystemCleaner: filesystemCleaner,
          // Stage into a per-process workspace so a manual update can't clobber
          // (or be clobbered by) a resident bridge's background staging.
          workspaceLabel: 'manual.$pid',
        ),
        updateApplyService: UpdateApplyService(
          installationRepository: installationRepository,
          attemptRepository: attemptRepository,
          logRepository: logRepository,
          updateLock: updateLock,
          filesystemCleaner: filesystemCleaner,
          clock: clock,
          currentVersion: appVersion,
          installRoot: installRoot,
        ),
        track: releaseTrack,
        installRoot: installRoot,
        executablePath: Platform.resolvedExecutable,
        managedExecutablePath: managedRuntimePaths.binaryPath,
      );

      final outcome = await manualUpdateService.runUpdate(force: force);

      final formatter = UpdateCommandFormatter(
        outStream: stdout,
        errorStream: stderr,
        environment: environment,
      );
      for (final line in formatter.format(outcome: outcome)) {
        if (line.isError) {
          stderr.writeln(line.text);
        } else {
          stdout.writeln(line.text);
        }
      }
      exitCode = _exitCodeFor(outcome);
    } finally {
      httpClient.close();
    }
  }

  Future<ReleaseTrack> _resolveReleaseTrack() async {
    try {
      final settings = await BridgeSettingsRepository(api: BridgeSettingsApi()).loadSettings();
      return settings.releaseTrack;
    } on Object catch (error) {
      Log.w('Failed to resolve release track; defaulting to stable: $error');
      return ReleaseTrack.stable;
    }
  }

  int _exitCodeFor(ExplicitUpdateOutcome outcome) {
    switch (outcome) {
      case ExplicitUpdateApplied():
      case ExplicitUpdateAlreadyLatest():
      case ExplicitUpdateTrackMismatch():
        return 0;
      case ExplicitUpdateNoEligibleRelease():
      case ExplicitUpdateNotManaged():
      case ExplicitUpdateNpmDirect():
      case ExplicitUpdateLockBusy():
      case ExplicitUpdateFailed():
        return 1;
    }
  }
}

/// Best-effort `enabledPlugins` read for plugin selection. Selection also
/// runs for `--help` and `logout`, so it must never crash on (or create)
/// a missing/broken config — failures resolve to "unset". Diagnostics go
/// through [Log.e] (the stderr level): stdout of `--version`/`--help` must
/// stay machine-consumable.
Future<List<String>?> _loadEnabledPluginsFromSettings() async {
  try {
    final settings = await BridgeSettingsRepository(api: BridgeSettingsApi()).peekSettings();
    return settings.enabledPlugins;
  } on Object catch (error) {
    Log.e('Could not read bridge settings for plugin selection: $error');
    return null;
  }
}

Future<void> main(List<String> args) async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    Log.e('Unsupported platform ${Platform.operatingSystem}');
    exit(1);
  }

  // First pass of the two-pass parse: the selected plugin determines which
  // options the run command's parser is built with.
  BridgePluginDescriptor selectedPlugin;
  String? pluginSelectionError;
  try {
    selectedPlugin = await const PluginSelector(
      knownPlugins: knownPlugins,
      defaultPluginId: defaultPluginId,
      loadEnabledPlugins: _loadEnabledPluginsFromSettings,
    ).resolve(args: args);
  } on PluginSelectionException catch (e) {
    // Bad settings must not brick --help, logout, or config — config being
    // the recovery command the message recommends. Build the parser from the
    // default surface and defer the error to the run command itself.
    selectedPlugin = knownPlugins.firstWhere((plugin) => plugin.id == defaultPluginId);
    pluginSelectionError = e.message;
  }

  final runner = cli.CommandRunner<void>('sesori-bridge', 'Sesori Bridge CLI')
    ..addCommand(RunCommand(selectedPlugin: selectedPlugin, selectionError: pluginSelectionError))
    ..addCommand(LogoutCommand())
    ..addCommand(ConfigCommand())
    ..addCommand(UpdateCommand());

  try {
    await runner.run(effectiveCliArgs(args));
  } on cli.UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(e.usage);
    exit(1);
  }
}
