import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../foundation/bridge_restart_command.dart';
import '../foundation/bridge_restart_command_builder.dart';
import '../foundation/bridge_restart_env.dart';
import '../repositories/process_repository.dart';

/// Owns the process side of an explicit, user-triggered bridge restart:
/// validating that a successor can be spawned and spawning it.
///
/// It deliberately does NOT shut the current process down — the consumer
/// (orchestrator) drives the existing graceful-shutdown path after the
/// `{restarting:true}` reply has been flushed to the phone, so the relay
/// disconnect → reconnect carries the handoff. The successor is spawned with the
/// predecessor's pid so it can wait this process out before enforcing
/// single-live-bridge.
class BridgeRestartService {
  BridgeRestartService({
    required ProcessRepository processRepository,
    required BridgeRestartCommandBuilder commandBuilder,
    required String binaryPath,
    required List<String> cliArgs,
    required int currentPid,
  }) : _processRepository = processRepository,
       _commandBuilder = commandBuilder,
       _binaryPath = binaryPath,
       _cliArgs = cliArgs,
       _currentPid = currentPid;

  final ProcessRepository _processRepository;
  final BridgeRestartCommandBuilder _commandBuilder;
  final String _binaryPath;
  final List<String> _cliArgs;
  final int _currentPid;

  bool _restartRequested = false;

  /// Marks that a restart has been accepted (after the handler validates it),
  /// so the consumer performs the handoff once the response is sent.
  void requestRestart() {
    _restartRequested = true;
  }

  /// Returns whether a restart was requested and clears the flag.
  bool consumeRestartRequest() {
    final bool requested = _restartRequested;
    _restartRequested = false;
    return requested;
  }

  /// Whether the managed binary exists and is executable, so the handler only
  /// promises a restart it can actually deliver (an unspawnable bridge fails
  /// fast with an error response instead of a dropped session).
  Future<bool> canSpawnSuccessor() async {
    // Sync dart:io checks satisfy the project's `avoid_slow_async_io` lint.
    final File file = File(_binaryPath);
    if (!file.existsSync()) {
      return false;
    }
    if (Platform.isWindows) {
      return true;
    }
    // POSIX: require an execute bit so a present-but-non-executable binary
    // fails the preflight rather than promising a restart that cannot spawn.
    try {
      final int mode = file.statSync().mode;
      return mode & 0x49 != 0; // any of owner/group/other execute (0o111)
    } on Object {
      return false;
    }
  }

  /// Spawns the successor bridge detached (inheriting this terminal). Returns
  /// `true` on success; `false` if the process could not be started.
  Future<bool> spawnSuccessor() async {
    final BridgeRestartCommand command = _commandBuilder.build(binaryPath: _binaryPath, cliArgs: _cliArgs);
    try {
      await _processRepository.startDetached(
        executable: command.executable,
        arguments: command.arguments,
        environment: <String, String>{sesoriRestartPredecessorPidEnvVar: '$_currentPid'},
      );
      return true;
    } on Object catch (error, stackTrace) {
      Log.e('Failed to spawn successor bridge for restart: $error', error, stackTrace);
      return false;
    }
  }
}
