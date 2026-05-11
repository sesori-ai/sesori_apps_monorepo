import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../../server/codex_binary_resolver.dart';
import '../../server/process.dart';
import 'bridge_cli_options.dart';

const String defaultTargetHost = 'http://127.0.0.1';

/// Resolves the backend server runtime according to [options.backend].
///
/// For `opencode`: starts `opencode serve` on [options.port] and returns its
/// HTTP URL + Basic-auth password — historical behaviour, untouched by the
/// codex work.
///
/// For `codex`: resolves the codex binary, spawns `codex app-server` on a
/// loopback WS, and returns the discovered `ws://` URL. Auth is not used
/// for loopback (codex's `--ws-auth` is documented as required only for
/// non-loopback listeners).
Future<BridgeServerRuntime> resolveServer({required BridgeCliOptions options}) async {
  return switch (options.backend) {
    BridgeBackend.opencode => _resolveOpenCodeServer(options),
    BridgeBackend.codex => _resolveCodexServer(options),
  };
}

Future<BridgeServerRuntime> _resolveOpenCodeServer(BridgeCliOptions options) async {
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

Future<BridgeServerRuntime> _resolveCodexServer(BridgeCliOptions options) async {
  final resolver = CodexBinaryResolver(codexBinFlag: options.codexBin);
  final binaryPath = await resolver.resolve();

  if (options.noAutoStart) {
    Log.i("codex: auto-start disabled; expecting an existing app-server on the user's configured URL");
    // With auto-start off, we don't know the URL — caller is expected to
    // bring their own. For now, surface this as an error so users get
    // a clear message; remove or relax if a real external-server flow lands.
    throw UnsupportedError(
      'codex backend does not yet support --no-auto-start; remove the flag or set --backend opencode',
    );
  }

  final startup = await startCodexAppServer(
    binaryPath: binaryPath,
    requestedPort: options.codexPort,
  );

  Log.i('codex app-server started at ${startup.serverUrl}');
  return BridgeServerRuntime(
    serverUrl: startup.serverUrl,
    // Loopback codex requires no auth; non-loopback would be a future scope.
    serverPassword: null,
    process: startup.process,
    backend: BridgeBackend.codex,
  );
}

class BridgeServerRuntime {
  const BridgeServerRuntime({
    required this.serverUrl,
    required this.serverPassword,
    required this.process,
    this.backend = BridgeBackend.opencode,
  });

  final String serverUrl;
  final String? serverPassword;
  final Process? process;
  final BridgeBackend backend;
}
