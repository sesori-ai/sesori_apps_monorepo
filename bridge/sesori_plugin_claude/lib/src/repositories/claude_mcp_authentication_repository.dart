import "dart:async";
import "dart:io" as io;

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/claude_process_factory.dart";
import "../api/claude_process_launch.dart";
import "models/claude_mcp_authentication_context.dart";
import "models/claude_mcp_command_exception.dart";

/// Runs native logout in an already resolved resident configuration context.
class ClaudeMcpAuthenticationRepository({
  required final HostClaudeProcessFactory _processFactory,
  required final String _binaryPath,
  required final Duration _commandBudget,
}) {
  static const _killGrace = Duration(seconds: 5);

  Future<void> forget({required ClaudeMcpAuthenticationContext context}) async {
    _requireSupportedHost();
    final process = await _processFactory.spawnCommand(
      launch: ClaudeProcessLaunch(
        binaryPath: _binaryPath,
        arguments: ["mcp", "logout", "--", context.serverName],
        workingDirectory: context.workingDirectory,
        environment: const {},
      ),
    );
    var exited = false;
    final exit = process.exitCode.then((code) {
      exited = true;
      return code;
    });
    final subscriptions = CompositeSubscription();
    try {
      final (code, _, _) = await (
        exit,
        _drain(stream: process.stdout, subscriptions: subscriptions),
        _drain(stream: process.stderr, subscriptions: subscriptions),
      ).wait.timeout(_commandBudget);
      if (code != 0) throw ClaudeMcpCommandExitedException(exitCode: code);
    } finally {
      if (!exited) {
        process.kill();
        try {
          await process.exitCode.timeout(_killGrace);
        } on TimeoutException {
          process.kill(io.ProcessSignal.sigkill);
          await process.exitCode;
        }
      }
      await subscriptions.cancel();
      await process.stdin.close();
    }
  }

  Future<void> _drain({required Stream<List<int>> stream, required CompositeSubscription subscriptions}) {
    final closed = Completer<void>();
    subscriptions.add(stream.listen(null, onDone: closed.complete, onError: closed.completeError, cancelOnError: true));
    return closed.future;
  }

  void _requireSupportedHost() {
    // Windows CLI credential operations remain unimplemented until its native
    // terminal and argument handling are qualified together.
    if (!_processFactory.supportsTerminal) {
      throw const PluginMcpAuthenticationUnavailableException(
        reason: PluginMcpAuthenticationUnavailableReason.notImplemented,
      );
    }
  }
}
