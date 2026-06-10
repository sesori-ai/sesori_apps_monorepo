import 'dart:io';

import 'package:args/args.dart' show ArgParserException;
import 'package:args/command_runner.dart' as cli;
import 'package:opencode_plugin/opencode_plugin.dart';
import 'package:sesori_bridge/src/api/bridge_settings_api.dart';
import 'package:sesori_bridge/src/api/default_editor_api.dart';
import 'package:sesori_bridge/src/api/wake_lock_client.dart';
import 'package:sesori_bridge/src/bridge/foundation/device_type_detector.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_cli_dispatch.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_logout_runner.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_runtime_runner.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
import 'package:sesori_bridge/src/repositories/default_editor_repository.dart';
import 'package:sesori_bridge/src/repositories/wake_lock_repository.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/api/terminal_prompt_api.dart';
import 'package:sesori_bridge/src/server/foundation/process_user.dart';
import 'package:sesori_bridge/src/server/foundation/server_clock.dart';
import 'package:sesori_bridge/src/server/repositories/bridge_instance_repository.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/repositories/terminal_prompt_repository.dart';
import 'package:sesori_bridge/src/server/services/bridge_instance_service.dart';
import 'package:sesori_bridge/src/services/bridge_config_service.dart';
import 'package:sesori_bridge/src/services/sleep_prevention_service.dart';
import 'package:sesori_bridge/src/version.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log, LogLevel;

const String _defaultRelayURL = 'wss://relay.sesori.com';
const String _defaultAuthURL = 'https://api.sesori.com';

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

    final BridgeCliOptions options;
    try {
      options = BridgeCliOptions.fromArgResults(
        cliArgs: globalResults!.arguments,
        results: results,
        environment: Platform.environment,
        defaultAuthUrl: _defaultAuthURL,
      );
    } on ArgParserException catch (e) {
      usageException(e.message);
    }
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
      api: TerminalPromptApi(stdin: stdin, stdout: stdout),
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
    );

    final result = await logoutRunner.logout(currentPid: pid);
    switch (result.status) {
      case BridgeLogoutStatus.loggedOut:
        stdout.writeln('Authentication cleared. You will be asked to log in on next start.');
      case BridgeLogoutStatus.loggedOutWithRunningBridges:
        stdout.writeln('Authentication cleared. You will be asked to log in on next start.');
        stdout.writeln(
          'Warning: ${result.runningBridgeCount} bridge instance(s) are still running '
          'and may re-create tokens when they refresh their session.',
        );
      case BridgeLogoutStatus.cancelled:
        stdout.writeln('Logout cancelled; stored tokens were not cleared.');
        exitCode = 1;
      case BridgeLogoutStatus.failed:
        stderr.writeln('Error: Failed to clear authentication tokens: ${result.error}');
        exitCode = 1;
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

Future<void> main(List<String> args) async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    Log.e('Unsupported platform ${Platform.operatingSystem}');
    exit(1);
  }

  final runner = cli.CommandRunner<void>('sesori-bridge', 'Sesori Bridge CLI')
    ..addCommand(RunCommand())
    ..addCommand(LogoutCommand())
    ..addCommand(ConfigCommand());

  try {
    await runner.run(effectiveCliArgs(args));
  } on cli.UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(e.usage);
    exit(1);
  }
}
