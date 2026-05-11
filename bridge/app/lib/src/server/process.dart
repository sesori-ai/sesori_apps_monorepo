import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

const int _passwordLength = 32;
const Duration _serverStartupWait = Duration(seconds: 30);
const Duration _pollInterval = Duration(milliseconds: 250);
const Duration _gracefulShutdownTimeout = Duration(seconds: 5);

/// Generates a random 32-byte password and returns it as a hex string (64 chars).
String generatePassword() {
  final random = Random.secure();
  final bytes = List<int>.generate(_passwordLength, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Starts the opencode server process.
///
/// [binaryPath]: Path to the opencode binary
/// [port]: Port number for the server
/// [password]: Server password (set as OPENCODE_SERVER_PASSWORD env var)
///
/// Returns the Process object. Logs stderr output with [opencode] prefix.
/// Monitors for unexpected exit and logs if process exits while context is active.
Future<Process> startServer(
  String binaryPath,
  int port,
  String password,
) async {
  final args = ['serve', '--port', port.toString(), '--hostname', '127.0.0.1'];

  final env = Map<String, String>.from(Platform.environment);
  env['OPENCODE_SERVER_PASSWORD'] = password;

  final process = await Process.start(
    binaryPath,
    args,
    environment: env,
    runInShell: Platform.isWindows,
  );

  // Pipe stderr to log with [opencode] prefix
  process.stderr.transform(utf8.decoder).listen((String line) {
    Log.d('[opencode] $line');
  });

  // Monitor for unexpected exit
  unawaited(
    process.exitCode.then((int exitCode) {
      Log.e('opencode process exited unexpectedly with code: $exitCode');
    }),
  );

  return process;
}

/// Waits for the server to be ready by polling the health endpoint.
///
/// Polls GET {serverURL}/global/health every 250ms with Basic auth.
/// Returns when status 200 is received.
/// Throws TimeoutException if server doesn't become ready within 30 seconds.
Future<void> waitReady(
  String serverURL,
  String password, {
  Duration timeout = _serverStartupWait,
}) async {
  final healthURL = '$serverURL/global/health';
  final deadline = DateTime.now().add(timeout);
  final httpClient = http.Client();

  try {
    while (DateTime.now().isBefore(deadline)) {
      try {
        final request = http.Request('GET', Uri.parse(healthURL));
        request.headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('opencode:$password'))}';

        final streamedResponse = await httpClient
            .send(request)
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                throw TimeoutException('Health check request timeout');
              },
            );

        if (streamedResponse.statusCode == 200) {
          return;
        }
      } catch (_) {
        // Continue polling on any error
      }

      // Wait before next poll
      await Future<void>.delayed(_pollInterval);
    }

    throw TimeoutException(
      'Server did not become ready within ${timeout.inSeconds}s',
    );
  } finally {
    httpClient.close();
  }
}

/// Stops the opencode server process gracefully.
///
/// Sends SIGTERM on Unix, SIGKILL on Windows.
/// Waits up to 5 seconds for graceful shutdown.
/// If process doesn't exit within 5s, force kills it.
Future<void> stopServer(Process? process) async {
  if (process == null) {
    return;
  }

  Log.i('Stopping opencode server...');

  try {
    if (Platform.isWindows) {
      // Windows doesn't support SIGTERM, use SIGKILL
      process.kill(ProcessSignal.sigkill);
    } else {
      // Unix: try graceful shutdown with SIGTERM
      process.kill(ProcessSignal.sigterm);
    }
  } catch (e) {
    Log.e('Failed to send signal: $e');
    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {
      // Process may already be dead
    }
    return;
  }

  // Wait for graceful shutdown
  try {
    await process.exitCode.timeout(_gracefulShutdownTimeout);
    Log.i('opencode server stopped gracefully');
  } on TimeoutException {
    Log.w('opencode server did not stop within 5s, killing...');
    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {
      // Process may already be dead
    }
  }
}

/// Outcome of [startCodexAppServer]: the process handle and the bound WS URL.
class CodexProcessStartup {
  const CodexProcessStartup({required this.process, required this.serverUrl});

  final Process process;

  /// The WebSocket URL discovered from codex's startup output, e.g.
  /// `ws://127.0.0.1:54321`.
  final String serverUrl;
}

/// Starts `codex app-server` on a loopback WebSocket and waits for it to
/// announce its bound port.
///
/// [binaryPath]: Resolved codex binary (see [CodexBinaryResolver]).
/// [requestedPort]: 0 → ephemeral, codex picks the port.
///
/// Returns once codex has printed its listening URL on stdout, or throws
/// [TimeoutException] after [startupTimeout].
Future<CodexProcessStartup> startCodexAppServer({
  required String binaryPath,
  int requestedPort = 0,
  Duration startupTimeout = _serverStartupWait,
}) async {
  final args = [
    'app-server',
    '--listen',
    'ws://127.0.0.1:$requestedPort',
  ];

  final process = await Process.start(
    binaryPath,
    args,
    runInShell: Platform.isWindows,
  );

  final urlCompleter = Completer<String>();

  // Codex prints the listening URL at startup as a line containing
  // "ws://127.0.0.1:<port>". Match exactly that shape from stdout/stderr.
  final urlPattern = RegExp(r'(ws://[0-9.]+:\d+)');

  void scan(String line) {
    Log.d('[codex] $line');
    final match = urlPattern.firstMatch(line);
    if (match != null && !urlCompleter.isCompleted) {
      urlCompleter.complete(match.group(1)!);
    }
  }

  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(scan);
  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(scan);

  // If the process exits before printing its URL, fail the wait with a
  // useful error instead of hanging until the timeout.
  unawaited(
    process.exitCode.then((int exitCode) {
      if (!urlCompleter.isCompleted) {
        urlCompleter.completeError(
          Exception(
            'codex app-server exited with code $exitCode before announcing its listen URL',
          ),
        );
      } else {
        Log.e('codex app-server exited unexpectedly with code: $exitCode');
      }
    }),
  );

  try {
    final url = await urlCompleter.future.timeout(startupTimeout);
    return CodexProcessStartup(process: process, serverUrl: url);
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    throw TimeoutException(
      'codex app-server did not announce a listen URL within ${startupTimeout.inSeconds}s',
    );
  }
}

/// Stops the codex app-server process gracefully.
///
/// Same shutdown semantics as [stopServer] but logs under the "codex" tag
/// so operators can tell the two backends apart.
Future<void> stopCodexAppServer(Process? process) async {
  if (process == null) return;

  Log.i('Stopping codex app-server...');
  try {
    if (Platform.isWindows) {
      process.kill(ProcessSignal.sigkill);
    } else {
      process.kill(ProcessSignal.sigterm);
    }
  } catch (e) {
    Log.e('Failed to signal codex process: $e');
    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {
      // Already dead.
    }
    return;
  }

  try {
    await process.exitCode.timeout(_gracefulShutdownTimeout);
    Log.i('codex app-server stopped gracefully');
  } on TimeoutException {
    Log.w('codex app-server did not stop within 5s, killing...');
    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {
      // Already dead.
    }
  }
}
