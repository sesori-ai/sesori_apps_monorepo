import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../../bridge/foundation/legacy_post_update_relaunch.dart';
import '../foundation/bridge_restart_command.dart';
import '../foundation/bridge_restart_command_builder.dart';
import '../foundation/bridge_restart_env.dart';
import '../repositories/process_repository.dart';

/// Owns the process side of an explicit, user-triggered bridge restart:
/// deciding how the running bridge is replaced and carrying that out.
///
/// There are two strategies, chosen once at the composition root via
/// [isSupervised]:
/// - **standalone** — this bridge spawns its own successor process
///   ([spawnSuccessor]); the successor waits this pid out before enforcing
///   single-live-bridge.
/// - **supervised** — the desktop GUI owns this process's lifecycle and respawns
///   it, so no successor is spawned. Instead [performRestartHandoff] records that
///   a supervised restart was requested ([supervisedRestartRequested]); the
///   composition root reads that flag once the session ends and exits with the
///   GUI-respawn sentinel code. Spawning a supervised successor would replay
///   `--control-url` into a detached child with no off-argv secret and fail
///   closed, so supervised mode must never call [spawnSuccessor].
///
/// It deliberately does NOT shut the current process down — the consumer
/// (orchestrator) drives the existing graceful-shutdown path after the
/// `{restarting:true}` reply has been flushed to the phone, so the relay
/// disconnect → reconnect carries the handoff.
class BridgeRestartService {
  BridgeRestartService({
    required ProcessRepository processRepository,
    required BridgeRestartCommandBuilder commandBuilder,
    required String binaryPath,
    required List<String> cliArgs,
    required int currentPid,
    required bool isSupervised,
  }) : _processRepository = processRepository,
       _commandBuilder = commandBuilder,
       _binaryPath = binaryPath,
       _cliArgs = cliArgs,
       _currentPid = currentPid,
       _isSupervised = isSupervised;

  final ProcessRepository _processRepository;
  final BridgeRestartCommandBuilder _commandBuilder;
  final String _binaryPath;
  final List<String> _cliArgs;
  final int _currentPid;
  final bool _isSupervised;

  bool _restartRequested = false;
  bool _supervisedRestartRequested = false;

  /// Whether a supervised restart handoff has been performed, so the composition
  /// root can exit with the GUI-respawn sentinel code instead of a clean 0. Only
  /// ever set in supervised mode; standalone spawns a successor and leaves this
  /// false.
  bool get supervisedRestartRequested => _supervisedRestartRequested;

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

  /// Performs the restart handoff for the active run mode and reports whether the
  /// caller should now proceed to shut down (flush the queued reply, then cancel
  /// the session).
  ///
  /// - **supervised:** records [supervisedRestartRequested] and returns `true`
  ///   without spawning a successor — the desktop GUI respawns this process after
  ///   it exits with the sentinel code.
  /// - **standalone:** spawns a successor and returns whether it started; `false`
  ///   means the bridge could not be replaced and should keep running.
  Future<bool> performRestartHandoff() async {
    if (_isSupervised) {
      Log.i('Supervised restart: exiting for GUI respawn (no successor spawn)');
      _supervisedRestartRequested = true;
      return true;
    }
    Log.i('Standalone restart: spawning successor bridge');
    return spawnSuccessor();
  }

  /// Spawns the successor bridge detached (inheriting this terminal). Returns
  /// `true` on success; `false` if the process could not be started.
  Future<bool> spawnSuccessor() async {
    final BridgeRestartCommand command = _commandBuilder.build(binaryPath: _binaryPath, cliArgs: _cliArgs);
    try {
      await _processRepository.startDetached(
        executable: command.executable,
        arguments: command.arguments,
        environment: <String, String>{
          sesoriRestartPredecessorPidEnvVar: '$_currentPid',
          // The successor inherits this process's environment. If this bridge
          // was itself launched non-interactively by a legacy auto-updater, the
          // relaunch flag would otherwise propagate to every restart successor,
          // pinning them to non-interactive mode indefinitely. An explicit
          // restart is an intentional, terminal-attached launch, so clear the
          // flag (the reader treats anything other than '1' as absent).
          sesoriPostUpdateRestartEnvVar: '',
        },
      );
      return true;
    } on Object catch (error, stackTrace) {
      Log.e('Failed to spawn successor bridge for restart: $error', error, stackTrace);
      return false;
    }
  }
}
