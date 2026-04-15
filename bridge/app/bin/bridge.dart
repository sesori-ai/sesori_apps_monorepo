import 'dart:io';

import 'package:args/args.dart';
import 'package:opencode_plugin/opencode_plugin.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_runtime_runner.dart';
import 'package:sesori_bridge/src/version.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log, LogLevel;

const String _defaultRelayURL = 'wss://relay.sesori.com';
const String _defaultAuthURL = 'https://api.sesori.com';

Future<void> main(List<String> args) async {
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

  final exitCode = await runBridgeApp(
    options: options,
    pluginFactory: ({required String serverUrl, required String? serverPassword}) {
      return OpenCodePlugin(serverUrl: serverUrl, password: serverPassword);
    },
  );
  exit(exitCode);
}
