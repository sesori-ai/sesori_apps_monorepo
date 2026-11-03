import 'dart:async';
import 'dart:io';

import 'package:args/args.dart' show ArgParserException;
import 'package:args/command_runner.dart' as cli;
import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/api/app_onboarding_state_storage.dart';
import 'package:sesori_bridge/src/api/bridge_settings_api.dart';
import 'package:sesori_bridge/src/api/default_editor_api.dart';
import 'package:sesori_bridge/src/api/wake_lock_client.dart';
import 'package:sesori_bridge/src/auth/auth_api.dart';
import 'package:sesori_bridge/src/auth/auth_repository.dart';
import 'package:sesori_bridge/src/auth/bridge_id_storage.dart';
import 'package:sesori_bridge/src/auth/bridge_registration_repository.dart';
import 'package:sesori_bridge/src/auth/bridge_registration_service.dart';
import 'package:sesori_bridge/src/auth/machine_id_api.dart';
import 'package:sesori_bridge/src/auth/token.dart';
import 'package:sesori_bridge/src/auth/token_refresh_exception.dart';
import 'package:sesori_bridge/src/auth/token_service.dart';
import 'package:sesori_bridge/src/foundation/abortable_request.dart';
import 'package:sesori_bridge/src/foundation/bridge_startup_banner_formatter.dart';
import 'package:sesori_bridge/src/foundation/data_directory_hardening.dart';
import 'package:sesori_bridge/src/foundation/device_type_detector.dart';
import 'package:sesori_bridge/src/foundation/process_group_isolation.dart';
import 'package:sesori_bridge/src/foundation/process_runner.dart';
import 'package:sesori_bridge/src/foundation/process_runner_command_executor.dart';
import 'package:sesori_bridge/src/repositories/app_onboarding_state_repository.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
import 'package:sesori_bridge/src/repositories/wake_lock_repository.dart';
import 'package:sesori_bridge/src/runtime/bridge_cli_dispatch.dart';
import 'package:sesori_bridge/src/runtime/bridge_cli_options.dart';
import 'package:sesori_bridge/src/runtime/bridge_logout_runner.dart';
import 'package:sesori_bridge/src/runtime/bridge_runtime_runner.dart';
import 'package:sesori_bridge/src/runtime/plugin_cli_options_mapper.dart';
import 'package:sesori_bridge/src/runtime/plugin_registry.dart';
import 'package:sesori_bridge/src/server/api/process_id_lookup_api.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/api/terminal_prompt_api.dart';
import 'package:sesori_bridge/src/server/repositories/bridge_instance_repository.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/repositories/terminal_prompt_repository.dart';
import 'package:sesori_bridge/src/server/services/bridge_instance_service.dart';
import 'package:sesori_bridge/src/server/services/windows_restart_successor_launcher.dart';
import 'package:sesori_bridge/src/services/bridge_config_service.dart';
import 'package:sesori_bridge/src/services/sleep_prevention_service.dart';
import 'package:sesori_bridge/src/updater/formatters/terminal_download_progress_listener.dart';
import 'package:sesori_bridge/src/updater/formatters/update_command_formatter.dart';
import 'package:sesori_bridge/src/updater/formatters/update_output_formatter.dart';
import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:sesori_bridge/src/updater/models/explicit_update_outcome.dart';
import 'package:sesori_bridge/src/updater/services/managed_runtime_path_service.dart';
import 'package:sesori_bridge/src/updater/services/manual_update_service.dart';
import 'package:sesori_bridge/src/updater/updater_composition.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart'
    show BridgePluginDescriptor, Console, Log, LogLevel, PluginConfig, PluginConfigException, ProcessUser, ServerClock;
import 'package:sesori_shared/sesori_shared.dart' show BridgeKind;
import 'package:win32/win32.dart' show SetThreadExecutionState;

const String _defaultRelayURL = 'wss://relay.sesori.com';
const String _defaultAuthURL = 'https://api.sesori.com';

class RunCommand() extends cli.Command<void> {
  @override
  final name = 'run';

  @override
  final description = 'Run the Sesori bridge (default)';

  /// Maps every registered plugin's options to/from the CLI parser, namespaced
  /// under its id (e.g. `--opencode-host`).
  final List<({BridgePluginDescriptor plugin, PluginCliOptionsMapper mapper})> _pluginCliMappers;

  this
    : _pluginCliMappers = [
        for (final plugin in knownPlugins) (plugin: plugin, mapper: PluginCliOptionsMapper(pluginId: plugin.id)),
      ] {
    argParser
      ..addFlag(
        'version',
        negatable: false,
        help: 'Show version and exit',
      )
      ..addOption('relay', defaultsTo: _defaultRelayURL, help: 'Relay server URL');
    for (final (:plugin, :mapper) in _pluginCliMappers) {
      mapper.register(parser: argParser, options: plugin.options);
    }
    argParser
      ..addOption('auth-backend', help: 'Auth backend URL')
      ..addOption(
        'data-dir',
        valueHelp: 'path',
        help: 'Override the account data directory (tokens, bridge ID, and database)',
      )
      ..addOption(
        'debug-port',
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
    final results = argResults;
    final allResults = globalResults;
    if (results == null || allResults == null) usageException('Unable to read command arguments.');

    if (results['version'] as bool) {
      stdout.writeln(bridgeVersion);
      return;
    }

    final BridgeCliOptions options;
    final Map<BridgePluginDescriptor, PluginConfig> pluginConfigs;
    try {
      // Plugin option validate hooks and config validation run at
      // argument-parse time — strictly before the startup mutex, so a typo'd
      // flag can never terminate a healthy resident bridge.
      pluginConfigs = {
        for (final (:plugin, :mapper) in _pluginCliMappers)
          plugin: mapper.parse(results: results, options: plugin.options),
      };
      for (final MapEntry(key: plugin, value: config) in pluginConfigs.entries) {
        plugin.validateConfig(config);
      }
      options = BridgeCliOptions.fromArgResults(
        cliArgs: allResults.arguments,
        results: results,
        environment: Platform.environment,
        defaultAuthUrl: _defaultAuthURL,
        defaultDataDirectory: sesoriDataDirectory(),
      );
    } on ArgParserException catch (e) {
      usageException(e.message);
    } on PluginConfigException catch (e) {
      usageException(e.message);
    }
    Log.level = LogLevel.values.byName(options.logLevelName);

    if (options.isSupervised) {
      // Establish ownership before sleep prevention or any other long-lived
      // child starts, so the desktop can terminate the complete live group.
      ProcessGroupIsolation().isolateCurrentProcess();
    }

    if (!options.isSupervised) {
      final banner = BridgeStartupBannerFormatter(
        out: stdout,
        environment: Platform.environment,
      ).format(version: bridgeVersion);
      if (banner != null) Console.message(banner);
    }

    final settingsRepository = BridgeSettingsRepository(defaultEditorApi: null, api: BridgeSettingsApi());
    final sleepPreventionService = SleepPreventionService(
      bridgeSettingsRepository: settingsRepository,
      wakeLockRepository: WakeLockRepository(
        client: WakeLockClient.forPlatform(
          platform: PlatformTarget.current().os,
          processStarter: Process.start,
          executionStateSetter: SetThreadExecutionState,
          warningLogger: Log.w,
        ),
      ),
      deviceTypeDetector: DeviceTypeDetector(
        processRunner: ProcessRunner(),
        platform: PlatformTarget.current().os,
      ),
      warningLogger: Log.w,
    );

    try {
      final mode = await sleepPreventionService.applyConfiguredMode();
      Log.i('Sleep prevention mode: ${mode.name}');
    } on Object catch (error, stackTrace) {
      Log.w('Sleep prevention failed', error, stackTrace);
    }

    final exitCode = await BridgeRuntimeRunner.run(
      options: options,
      pluginConfigs: pluginConfigs,
    );
    await sleepPreventionService.dispose();
    exit(exitCode);
  }
}

class LogoutCommand() extends cli.Command<void> {
  @override
  final name = 'logout';

  @override
  final description = 'Clear stored authentication tokens';

  this {
    argParser
      ..addOption('auth-backend', help: 'Auth backend URL')
      ..addOption(
        'data-dir',
        valueHelp: 'path',
        help: 'Override the account data directory (tokens, bridge ID, and database)',
      );
  }

  @override
  Future<void> run() async {
    final results = argResults ?? usageException('Unable to read command arguments.');
    final dataDirectoryFlag = results['data-dir'] as String?;
    final defaultDataDirectory = sesoriDataDirectory();
    final String dataDirectory;
    try {
      dataDirectory = BridgeCliOptions.resolveDataDirectory(
        dataDirectoryFlag: dataDirectoryFlag,
        defaultDataDirectory: defaultDataDirectory,
        environment: Platform.environment,
      );
    } on ArgParserException catch (error) {
      usageException(error.message);
    }
    final isCustomDataDirectory = !BridgeCliOptions.isDefaultDataDirectory(
      dataDirectory: dataDirectory,
      defaultDataDirectory: defaultDataDirectory,
    );
    if (isCustomDataDirectory) {
      Console.warning(
        'Stop the source-run bridge using $dataDirectory before logging out; '
        'custom data-directory logout does not stop running bridge processes.',
      );
    }
    final authBackendUrl = BridgeCliOptions.resolveAuthBackendUrl(
      authBackendFlag: results['auth-backend'] as String?,
      environment: Platform.environment,
      defaultAuthUrl: _defaultAuthURL,
    );
    final processRunner = ProcessRunner();
    final systemProcessApi = SystemProcessApi(
      processRunner: processRunner,
      clock: const ServerClock(),
      isWindows: Platform.isWindows,
      inheritingStdioProcessRunner: SystemProcessApi.ioInheritingStdioProcessRunner,
    );
    final processIdLookupApi = ProcessIdLookupApi.forPlatform(
      isWindows: Platform.isWindows,
      processRunner: processRunner,
    );
    final currentUser = ProcessUser.fromRawUser(
      Platform.environment['USER'] ?? Platform.environment['USERNAME'],
    );
    final bridgeInstanceRepository = BridgeInstanceRepository(
      processIdLookupApi: processIdLookupApi,
      processApi: systemProcessApi,
      currentUser: currentUser,
    );
    final terminalPromptRepository = TerminalPromptRepository(
      api: TerminalPromptApi(
        stdin: stdin,
        stdout: stdout,
      ),
    );
    final logoutRunner = BridgeLogoutRunner(
      bridgeInstanceRepository: bridgeInstanceRepository,
      bridgeInstanceService: BridgeInstanceService(
        bridgeInstanceRepository: bridgeInstanceRepository,
        // The logout CLI always runs from a terminal, never supervised.
        replacePrompt: terminalPromptRepository,
        processRepository: ProcessRepository(
          api: systemProcessApi,
          currentUser: currentUser,
        ),
        clock: const ServerClock(),
      ),
      terminalPromptRepository: terminalPromptRepository,
      unregisterBridge: () => _unregisterBridgeRegistration(
        authBackendUrl: authBackendUrl,
        dataDirectory: dataDirectory,
      ),
      appOnboardingStateRepository: AppOnboardingStateRepository(
        storage: AppOnboardingStateStorage(
          directoryPath: appOnboardingStateDirectoryPath(dataDirectory: dataDirectory),
        ),
      ),
      clearTokens: () => clearTokens(dataDirectory: dataDirectory),
    );

    final result = await logoutRunner.logout(
      currentPid: pid,
      manageRunningBridges: !isCustomDataDirectory,
    );
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
        Console.error('Error: Failed to clear authentication state: ${result.error}');
        exitCode = 1;
    }
  }
}

/// Removes this bridge's registration on the auth server before the token
/// file is deleted. Callers treat any failure as non-fatal.
Future<void> _unregisterBridgeRegistration({
  required String authBackendUrl,
  required String dataDirectory,
}) async {
  final bridgeIdStorage = BridgeIdStorage(
    filePath: bridgeIdPath(dataDirectory: dataDirectory),
    writeRestrictedFile: writeRestrictedFile,
  );
  if (await bridgeIdStorage.read() == null) {
    // Nothing registered to remove.
    return;
  }

  final TokenData tokens;
  try {
    tokens = await loadTokens(dataDirectory: dataDirectory);
  } on PathNotFoundException {
    // Logout is idempotent. A persisted bridge id can outlive the token file
    // after an earlier best-effort unregister failed, so no token is expected
    // when the user runs logout again.
    return;
  } on Object catch (error, stackTrace) {
    // A registered bridge with an unreadable token file has no credential for
    // the unregister call. Logout still proceeds, but retain the unexpected
    // local failure for diagnostics.
    Log.w('Skipping bridge unregistration; could not load tokens', error, stackTrace);
    return;
  }

  final httpClient = http.Client();
  final authApi = AuthApi(
    authBackendUrl: authBackendUrl,
    client: httpClient,
    requestDeadline: AuthApi.defaultRequestDeadline,
    sendRequest: sendRequestWithDeadline,
  );
  final tokenService = TokenService(
    initialToken: tokens.accessToken,
    loadTokens: () => loadTokens(dataDirectory: dataDirectory),
    saveTokens: (data) => saveTokens(
      data: data,
      dataDirectory: dataDirectory,
      writeRestrictedFile: writeRestrictedFile,
    ),
    authRepository: AuthRepository(api: authApi),
  );
  try {
    final registrationService = BridgeRegistrationService(
      repository: BridgeRegistrationRepository(
        api: authApi,
        machineIdApi: MachineIdApi.forPlatform(
          platform: PlatformTarget.current().os,
          commandExecutor: ProcessRunnerCommandExecutor(processRunner: ProcessRunner()),
        ),
      ),
      tokenRefresher: tokenService,
      bridgeIdStorage: bridgeIdStorage,
      hostName: Platform.localHostname,
      platform: BridgeRegistrationService.currentPlatformName(),
      // ponytail: this instance only unregisters, so the kind is never sent.
      kind: BridgeKind.cli,
    );
    try {
      await registrationService.unregister().timeout(const Duration(seconds: 10));
    } on TokenRefreshException catch (error) {
      if (error.statusCode != 401) {
        rethrow;
      }
      // An expired or revoked saved session is a normal reason to log out. The
      // server registration cannot be removed without valid credentials, but
      // the local logout should remain clean and the persisted bridge id lets a
      // later login reclaim the same registration.
      Log.i('Skipping bridge unregistration because the saved authentication session is no longer valid.');
    }
  } finally {
    tokenService.dispose();
    httpClient.close();
  }
}

class ConfigCommand() extends cli.Command<void> {
  @override
  final name = 'config';

  @override
  final description = 'Manage bridge configuration';

  this {
    addSubcommand(ConfigTrackCommand());
    addSubcommand(
      ConfigSwitchCommand(
        name: 'yolo',
        description: 'Show or set automatic permission approval (on|off)',
        label: 'YOLO mode',
        read: (settings) => settings.yolo,
        write: (repository, {required enabled}) => repository.updateYolo(enabled: enabled),
        enabledWarning: 'Warning: permission requests will be auto-approved without being sent to clients.',
      ),
    );
    addSubcommand(
      ConfigSwitchCommand(
        name: 'warmup',
        description: 'Show or set session-open plugin warm-up (on|off)',
        label: 'Session-open plugin warm-up',
        read: (settings) => settings.warmUpPluginsOnSessionOpen,
        write: (repository, {required enabled}) => repository.updateWarmUpPluginsOnSessionOpen(enabled: enabled),
        enabledWarning: null,
      ),
    );
    addSubcommand(ConfigPluginsCommand());
    addSubcommand(ConfigEditCommand());
  }
}

class ConfigEditCommand() extends cli.Command<void> {
  @override
  final name = 'edit';

  @override
  final description = 'Open the bridge configuration file in your default editor';

  @override
  Future<void> run() async {
    final settingsRepository = BridgeSettingsRepository(
      api: BridgeSettingsApi(),
      defaultEditorApi: DefaultEditorApi.forPlatform(
        platform: PlatformTarget.current().os,
        processRunner: ProcessRunner(),
      ),
    );
    final configService = BridgeConfigService(bridgeSettingsRepository: settingsRepository);

    final configFilePath = await configService.openConfigFile();
    Console.message('Opening config file at $configFilePath');
  }
}

class ConfigPluginsCommand() extends cli.Command<void> {
  @override
  final name = 'plugins';

  @override
  final description = 'Show or change plugin eligibility';

  @override
  Future<void> run() async {
    final results = argResults ?? usageException('Unable to read command arguments.');
    final rest = results.rest;
    final descriptors = [...knownPlugins]
      ..sort((left, right) {
        final byName = left.displayName.toLowerCase().compareTo(right.displayName.toLowerCase());
        return byName != 0 ? byName : left.id.compareTo(right.id);
      });
    final knownIds = {for (final descriptor in descriptors) descriptor.id};
    final configService = BridgeConfigService(
      bridgeSettingsRepository: BridgeSettingsRepository(defaultEditorApi: null, api: BridgeSettingsApi()),
    );

    if (rest.isEmpty) {
      final snapshot = await configService.listPlugins(
        knownPluginIds: [for (final descriptor in descriptors) descriptor.id],
      );
      final enabledIds = {
        for (final entry in snapshot.plugins)
          if (entry.enabled) entry.pluginId,
      };
      for (final descriptor in descriptors) {
        final enabled = enabledIds.contains(descriptor.id);
        stdout.writeln('${descriptor.displayName} (${descriptor.id}): ${enabled ? 'enabled' : 'disabled'}');
      }
      if (snapshot.unknownDisabledPluginIds.isNotEmpty) {
        stdout.writeln('Unknown disabled plugin IDs: ${snapshot.unknownDisabledPluginIds.join(', ')}');
      }
      return;
    }

    if (rest.length != 2 || (rest.first != 'enable' && rest.first != 'disable')) {
      usageException('Expected: config plugins [enable|disable] <plugin-id>.');
    }
    final pluginId = rest[1];
    final enabled = rest.first == 'enable';
    try {
      await configService.setPluginEnabled(
        pluginId: pluginId,
        enabled: enabled,
        knownPluginIds: knownIds,
      );
    } on UnknownPluginConfigException catch (error) {
      usageException('$error Known plugins: ${knownIds.join(', ')}.');
    }
    stdout.writeln('Plugin "$pluginId" ${enabled ? 'enabled' : 'disabled'}.');
    stdout.writeln('Restart sesori-bridge to apply.');
  }
}

class ConfigTrackCommand() extends cli.Command<void> {
  @override
  final name = 'track';

  @override
  final description = 'Show or set the bridge update track (stable|internal)';

  @override
  Future<void> run() async {
    final results = argResults ?? usageException('Unable to read command arguments.');
    final rest = results.rest;
    final repository = BridgeSettingsRepository(defaultEditorApi: null, api: BridgeSettingsApi());

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

/// A `config` subcommand that shows or sets one on/off bridge setting.
class ConfigSwitchCommand({
  @override required final String name,
  @override required final String description,
  required final String _label,
  required final bool Function(BridgeSettings settings) _read,
  required final Future<void> Function(BridgeSettingsRepository repository, {required bool enabled}) _write,
  required final String? _enabledWarning,
}) extends cli.Command<void> {
  @override
  Future<void> run() async {
    final results = argResults ?? usageException('Unable to read command arguments.');
    final rest = results.rest;
    final repository = BridgeSettingsRepository(defaultEditorApi: null, api: BridgeSettingsApi());

    if (rest.isEmpty) {
      final settings = await repository.loadSettings();
      stdout.writeln('$_label: ${_read(settings) ? 'on' : 'off'}');
      return;
    }

    final bool enabled = switch (rest) {
      ['on'] => true,
      ['off'] => false,
      _ => usageException('Expected a single $_label value: on or off.'),
    };
    await _write(repository, enabled: enabled);
    stdout.writeln('$_label set to ${enabled ? 'on' : 'off'}.');
    if (_enabledWarning case final warning? when enabled) {
      stdout.writeln(warning);
    }
    stdout.writeln('Restart sesori-bridge to apply.');
  }
}

class UpdateCommand() extends cli.Command<void> {
  @override
  final name = 'update';

  @override
  final description = 'Update the bridge to the latest release on your track, then exit';

  this {
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
    final results = argResults ?? usageException('Unable to read command arguments.');
    final bool force = results['force'] as bool;
    final environment = Platform.environment;
    final managedRuntimePaths = const ManagedRuntimePathService().currentPaths(environment: environment);
    final releaseTrack = await _resolveReleaseTrack();

    final httpClient = http.Client();
    final progressController = StreamController<DownloadProgress>();
    final outFormatter = UpdateOutputFormatter.forStream(out: stdout, environment: environment);
    final errFormatter = UpdateOutputFormatter.forStream(out: stderr, environment: environment);
    // Renders the download progress bar to stderr on an interactive terminal;
    // silently drains the progress stream otherwise.
    final progressListener = TerminalDownloadProgressListener(
      progress: progressController.stream,
      formatter: errFormatter,
      out: stderr,
    );
    try {
      final updater = composeUpdater(
        httpClient: httpClient,
        processRunner: ProcessRunner(),
        managedRuntimePaths: managedRuntimePaths,
        releaseTrack: releaseTrack,
        environment: environment,
        progressSink: progressController.sink,
        // Stage into a per-process workspace so a manual update can't clobber
        // (or be clobbered by) a resident bridge's background staging.
        workspaceLabel: 'manual.$pid',
      );
      final manualUpdateService = ManualUpdateService(
        releaseRepository: updater.releaseRepository,
        updateInstallService: updater.installService,
        updateApplyService: updater.applyService,
        track: releaseTrack,
        installRoot: managedRuntimePaths.installRoot,
        executablePath: Platform.resolvedExecutable,
        managedExecutablePath: managedRuntimePaths.binaryPath,
      );

      final ExplicitUpdateOutcome outcome;
      try {
        outcome = await manualUpdateService.runUpdate(force: force);
      } finally {
        // Close any open progress-bar line before printing the result summary so
        // it starts on a fresh line (e.g. after a mid-download failure that left
        // the bar drawn but not at 100%). In a finally so even an unexpected
        // throw can't leave the bar line unterminated ahead of the error output.
        await progressListener.dispose();
      }

      final formatter = UpdateCommandFormatter(outFormatter: outFormatter, errFormatter: errFormatter);
      for (final line in formatter.format(outcome: outcome)) {
        if (line.isError) {
          stderr.writeln(line.text);
        } else {
          stdout.writeln(line.text);
        }
      }
      exitCode = _exitCodeFor(outcome);
    } finally {
      await progressController.close();
      httpClient.close();
    }
  }

  Future<ReleaseTrack> _resolveReleaseTrack() async {
    try {
      final settings = await BridgeSettingsRepository(defaultEditorApi: null, api: BridgeSettingsApi()).loadSettings();
      return settings.releaseTrack;
    } on Object catch (error, stackTrace) {
      Log.w('Failed to resolve release track; defaulting to stable', error, stackTrace);
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

Future<void> main(List<String> args) async {
  try {
    final restartLauncher = WindowsRestartSuccessorLauncher(
      isWindows: Platform.isWindows,
      environment: Platform.environment,
      executable: Platform.resolvedExecutable,
      start:
          ({required executable, required arguments, required environment, required includeParentEnvironment}) async {
            await Process.start(
              executable,
              arguments,
              environment: environment,
              includeParentEnvironment: includeParentEnvironment,
              mode: ProcessStartMode.inheritStdio,
            );
          },
      exitLauncher: ({required code}) => exit(code),
    );
    final launchedRestartSuccessor = await restartLauncher.launchIfRequested(arguments: args);
    if (launchedRestartSuccessor) return;
  } on Object catch (error, stackTrace) {
    Log.e('Failed to launch the Windows restart successor', error, stackTrace);
    exitCode = 1;
    return;
  }

  // A browser command must succeed silently, even after its parent cancels.
  if (BrowserNoop.matches(arguments: args)) return;

  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    Log.e('Unsupported platform ${Platform.operatingSystem}');
    exit(1);
  }

  final runner = cli.CommandRunner<void>('sesori-bridge', 'Sesori Bridge CLI')
    ..addCommand(RunCommand())
    ..addCommand(LogoutCommand())
    ..addCommand(ConfigCommand())
    ..addCommand(UpdateCommand());

  try {
    await runner.run(effectiveCliArgs(args));
  } on cli.UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(e.usage);
    exit(1);
  } on FormatException catch (error) {
    stderr.writeln('Invalid bridge configuration: ${error.message}');
    exit(1);
  }
}
