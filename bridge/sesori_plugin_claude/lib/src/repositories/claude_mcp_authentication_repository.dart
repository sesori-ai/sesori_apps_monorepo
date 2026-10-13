import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/claude_process_factory.dart";
import "../api/claude_process_launch.dart";
import "models/claude_mcp_authentication_context.dart";
import "models/claude_mcp_command_exception.dart";

/// Runs native logout in an already resolved resident configuration context.
class ClaudeMcpAuthenticationRepository({
  required final HostClaudeProcessFactory _processFactory,
  required final String _binaryPath,
}) {
  static const _killGrace = Duration(seconds: 5);

  Future<void> forget({required ClaudeMcpAuthenticationContext context}) async {
    _requireSupportedHost();
    final process = await _processFactory.spawn(
      ClaudeProcessLaunch(
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
    try {
      final (code, _, _) = await (
        exit,
        process.stdout.drain<void>(),
        process.stderr.drain<void>(),
      ).wait.timeout(const Duration(seconds: 30));
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
      await process.stdin.close();
    }
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
