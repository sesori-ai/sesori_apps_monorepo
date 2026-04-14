import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../../server/process.dart';
import 'bridge_cli_options.dart';

const String defaultTargetHost = 'http://127.0.0.1';

Future<BridgeServerRuntime> resolveServer({required BridgeCliOptions options}) async {
  final serverUrl = '$defaultTargetHost:${options.port}';
  if (options.noAutoStart) {
    Log.i('Using existing server at $serverUrl (auto-start disabled)');
    return BridgeServerRuntime(
      serverUrl: serverUrl,
      serverPassword: options.password.isNotEmpty ? options.password : null,
      process: null,
    );
  }

  final serverPassword = options.password.isEmpty ? generatePassword() : options.password;
  final process = await startServer(options.opencodeBin, options.port, serverPassword);
  try {
    await waitReady(serverUrl, serverPassword);
  } catch (error) {
    await stopServer(process);
    throw Exception('opencode server failed to start: $error');
  }

  Log.i('opencode server started on port ${options.port}');
  return BridgeServerRuntime(
    serverUrl: serverUrl,
    serverPassword: serverPassword,
    process: process,
  );
}

class BridgeServerRuntime {
  const BridgeServerRuntime({
    required this.serverUrl,
    required this.serverPassword,
    required this.process,
  });

  final String serverUrl;
  final String? serverPassword;
  final Process? process;
}
