import 'dart:io';

import 'package:args/args.dart';
import 'package:opencode_plugin/opencode_plugin.dart';
import 'package:sesori_bridge/src/api/bridge_settings_api.dart';
import 'package:sesori_bridge/src/api/default_editor_api.dart';
import 'package:sesori_bridge/src/api/linux_default_editor_api.dart';
import 'package:sesori_bridge/src/api/linux_wake_lock_api.dart';
import 'package:sesori_bridge/src/api/macos_default_editor_api.dart';
import 'package:sesori_bridge/src/api/macos_wake_lock_api.dart';
import 'package:sesori_bridge/src/api/windows_default_editor_api.dart';
import 'package:sesori_bridge/src/api/windows_wake_lock_api.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_runtime_runner.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
import 'package:sesori_bridge/src/repositories/default_editor_repository.dart';
import 'package:sesori_bridge/src/repositories/wake_lock_repository.dart';
import 'package:sesori_bridge/src/services/bridge_config_service.dart';
import 'package:sesori_bridge/src/services/sleep_prevention_service.dart';
import 'package:sesori_bridge/src/version.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log, LogLevel;

const String _defaultRelayURL = 'wss://relay.sesori.com';
const String _defaultAuthURL = 'https://api.sesori.com';

Future<Process> _startProcess(String executable, List<String> args) {
  return Process.start(executable, args);
}

OpenCodePlugin _createOpenCodePlugin({
  required String serverUrl,
  required String? serverPassword,
}) {
  return OpenCodePlugin(serverUrl: serverUrl, password: serverPassword);
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args[0] == 'config') {
    final api = BridgeSettingsApi();
    final settingsRepository = BridgeSettingsRepository(api: api);
    final DefaultEditorApi editorApi = switch (Platform.operatingSystem) {
      'macos' => MacosDefaultEditorApi(),
      'linux' => LinuxDefaultEditorApi(),
      'windows' => WindowsDefaultEditorApi(),
      _ => throw UnsupportedError(
        'Unsupported platform for config command: ${Platform.operatingSystem}',
      ),
    };
    final editorRepository = DefaultEditorRepository(api: editorApi);
    final configService = BridgeConfigService(
      bridgeSettingsRepository: settingsRepository,
      defaultEditorRepository: editorRepository,
    );

    final configFilePath = await configService.openConfigFile();
    stdout.writeln('Opening config file at $configFilePath');
    exit(0);
  }

  final parser = ArgParser()
    ..addFlag(
      'version',
      negatable: false,
      help: 'Show version and exit',
    )
    ..addOption('relay', defaultsTo: _defaultRelayURL, help: 'Relay server URL')
    ..addOption(
      'port',
      defaultsTo: '4096',
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
    ..addFlag(
      'login',
      defaultsTo: false,
      help: 'Force re-login and clear stored tokens',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message',
    )
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

  ArgResults results;
  try {
    results = parser.parse(args);
  } on ArgParserException catch (e) {
    Log.e('Error: ${e.message}');
    Log.e(parser.usage);
    exit(1);
  }

  if (results['version'] as bool) {
    stdout.writeln(appVersion);
    exit(0);
  }

  if (results['help'] as bool) {
    stdout.writeln(parser.usage);
    exit(0);
  }

  final options = BridgeCliOptions.fromArgResults(
    cliArgs: args,
    results: results,
    environment: Platform.environment,
    defaultAuthUrl: _defaultAuthURL,
  );
  Log.level = LogLevel.values.byName(options.logLevelName);

  final settingsRepository = BridgeSettingsRepository(api: BridgeSettingsApi());
  final SleepPreventionService? sleepPreventionService = switch (
    Platform.operatingSystem
  ) {
    'macos' => SleepPreventionService(
      bridgeSettingsRepository: settingsRepository,
      wakeLockRepository: WakeLockRepository(
        client: MacOSWakeLockApi(processStarter: _startProcess),
      ),
    ),
    'linux' => SleepPreventionService(
      bridgeSettingsRepository: settingsRepository,
      wakeLockRepository: WakeLockRepository(client: LinuxWakeLockApi()),
    ),
    'windows' => SleepPreventionService(
      bridgeSettingsRepository: settingsRepository,
      wakeLockRepository: WakeLockRepository(client: WindowsWakeLockApi()),
    ),
    _ => null,
  };

  if (sleepPreventionService == null) {
    Log.w('Sleep prevention unavailable on ${Platform.operatingSystem}');
  } else {
    try {
      final mode = await sleepPreventionService.applyConfiguredMode();
      Log.i('Sleep prevention: ${mode.name}');
    } on Object catch (error) {
      Log.w('Sleep prevention failed: $error');
    }
  }

  final exitCode = await runBridgeApp(
    options: options,
    pluginFactory: _createOpenCodePlugin,
  );
  await sleepPreventionService?.dispose();
  exit(exitCode);
}
