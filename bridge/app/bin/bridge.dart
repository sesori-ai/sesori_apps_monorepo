import 'dart:io';

import 'package:args/command_runner.dart' as cli;
import 'package:opencode_plugin/opencode_plugin.dart';
import 'package:sesori_bridge/src/api/bridge_settings_api.dart';
import 'package:sesori_bridge/src/api/default_editor_api.dart';
import 'package:sesori_bridge/src/api/wake_lock_client.dart';
import 'package:sesori_bridge/src/auth/token.dart';
import 'package:sesori_bridge/src/bridge/foundation/device_type_detector.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_runtime_runner.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
import 'package:sesori_bridge/src/repositories/default_editor_repository.dart';
import 'package:sesori_bridge/src/repositories/wake_lock_repository.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/foundation/process_identity.dart';
import 'package:sesori_bridge/src/server/foundation/process_user.dart';
import 'package:sesori_bridge/src/server/foundation/server_clock.dart';
import 'package:sesori_bridge/src/server/repositories/bridge_instance_repository.dart';
import 'package:sesori_bridge/src/services/bridge_config_service.dart';
import 'package:sesori_bridge/src/services/sleep_prevention_service.dart';
import 'package:sesori_bridge/src/version.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log, LogLevel;

const String _defaultRelayURL = 'wss://relay.sesori.com';
const String _defaultAuthURL = 'https://api.sesori.com';
const Duration _bridgeShutdownWait = Duration(seconds: 5);

OpenCodePlugin _createOpenCodePlugin({
  required String serverUrl,
  required String? serverPassword,
}) {
  return OpenCodePlugin(serverUrl: serverUrl, password: serverPassword);
}

class RunCommand extends cli.Command<void> {
  @override
  final name = 'run';

  @override
  final description = 'Run the Sesori bridge (default)';

  RunCommand() {
    argParser
      ..addFlag(
        'version',
        negatable: false,
        help: 'Show version and exit',
      )
      ..addOption('relay', defaultsTo: _defaultRelayURL, help: 'Relay server URL')
      ..addOption(
        'port',
        help: 'Port for opencode server to listen on',
      )
      ..addFlag(
        'no-auto-start',
        defaultsTo: false,
        help: 'Skip auto-starting opencode server (use existing localhost server)',
      )
      ..addOption(
        'password',
        defaultsTo: '',
        help: 'Override server password (auto-generated if not set)',
      )
      ..addOption(
        'opencode-bin',
        defaultsTo: 'opencode',
        help: 'Path to opencode binary',
      )
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
      );
  }

  @override
  Future<void> run() async {
    final results = argResults!;

    if (results['version'] as bool) {
      stdout.writeln(appVersion);
      return;
    }

    final options = BridgeCliOptions.fromArgResults(
      cliArgs: globalResults!.arguments,
      results: results,
      environment: Platform.environment,
      defaultAuthUrl: _defaultAuthURL,
    );
    Log.level = LogLevel.values.byName(options.logLevelName);

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
      pluginFactory: _createOpenCodePlugin,
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

  @override
  Future<void> run() async {
    final runningBridges = await _listRunningBridges();

    if (runningBridges.isNotEmpty) {
      final shouldStop = await _promptStopBridges(runningBridges.length);
      if (shouldStop) {
        await _terminateBridges(runningBridges);
      }
    }

    try {
      await clearTokens();
      stdout.writeln('Authentication cleared. You will be asked to log in on next start.');
    } on FileSystemException catch (e) {
      stderr.writeln('Error: Failed to clear authentication tokens: ${e.message}');
      exitCode = 1;
    }
  }

  Future<List<ProcessIdentity>> _listRunningBridges() async {
    final processApi = SystemProcessApi(
      processRunner: ProcessRunner(),
      clock: const ServerClock(),
      isWindows: Platform.isWindows,
      platform: Platform.operatingSystem,
    );

    final currentUser = ProcessUser.fromRawUser(
      Platform.environment['USER'] ?? Platform.environment['USERNAME'],
    );

    final bridgeRepo = BridgeInstanceRepository(
      api: processApi,
      currentUser: currentUser,
    );

    return bridgeRepo.listLiveBridgeCandidates(currentPid: pid);
  }

  Future<bool> _promptStopBridges(int count) async {
    if (!stdin.hasTerminal || !stdout.hasTerminal) {
      stdout.writeln(
        'Warning: $count bridge instance(s) are running in the background. '
        'Tokens will be cleared, but active sessions may continue.',
      );
      return false;
    }

    stdout.writeln('$count bridge instance(s) are currently running.');
    stdout.write('Stop them before logging out? [y/N] ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    return answer == 'y' || answer == 'yes';
  }

  Future<void> _terminateBridges(List<ProcessIdentity> bridges) async {
    final processApi = SystemProcessApi(
      processRunner: ProcessRunner(),
      clock: const ServerClock(),
      isWindows: Platform.isWindows,
      platform: Platform.operatingSystem,
    );

    // Send graceful termination
    for (final bridge in bridges) {
      try {
        await processApi.sendGracefulSignal(pid: bridge.pid);
      } on Object catch (e) {
        stderr.writeln('Warning: Failed to stop bridge (PID ${bridge.pid}): $e');
      }
    }

    await Future<void>.delayed(_bridgeShutdownWait);

    // Force kill any survivors
    final currentUser = ProcessUser.fromRawUser(
      Platform.environment['USER'] ?? Platform.environment['USERNAME'],
    );
    final bridgeRepo = BridgeInstanceRepository(
      api: processApi,
      currentUser: currentUser,
    );
    final stillRunning = await bridgeRepo.listLiveBridgeCandidates(currentPid: pid);

    for (final bridge in stillRunning) {
      try {
        await processApi.sendForceSignal(pid: bridge.pid);
      } on Object catch (e) {
        stderr.writeln('Warning: Failed to force stop bridge (PID ${bridge.pid}): $e');
      }
    }
  }
}

class ConfigCommand extends cli.Command<void> {
  @override
  final name = 'config';

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
    stdout.writeln('Opening config file at $configFilePath');
  }
}

List<String> _effectiveArgs(List<String> args) {
  // Handle global help/version before command dispatch
  if (args.contains('--help') || args.contains('-h')) {
    return args;
  }

  if (args.isEmpty) {
    return ['run'];
  }

  final first = args[0];

  // If first arg is a flag, it's meant for the default 'run' command
  if (first.startsWith('-')) {
    return ['run', ...args];
  }

  // If it's a known command, pass through
  final knownCommands = {'run', 'logout', 'config', 'help'};
  if (knownCommands.contains(first)) {
    return args;
  }

  // Unknown command — let CommandRunner report the error
  return args;
}

Future<void> main(List<String> args) async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    Log.e('Unsupported platform ${Platform.operatingSystem}');
    exit(1);
  }

  final runner = cli.CommandRunner<void>('sesori-bridge', 'Sesori Bridge CLI')
    ..addCommand(RunCommand())
    ..addCommand(LogoutCommand())
    ..addCommand(ConfigCommand());

  final effectiveArgs = _effectiveArgs(args);

  try {
    await runner.run(effectiveArgs);
  } on cli.UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(e.usage);
    exit(1);
  }
}
