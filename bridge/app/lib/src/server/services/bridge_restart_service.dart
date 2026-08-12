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
///   it, so no successor is spawned. Instead [performRestartHandoff] notifies
///   the composition root (`onSupervisedRestartRequested`) at the moment the
///   handoff is decided, so the GUI-respawn sentinel exit code is recorded
///   before any shutdown runs. Spawning a supervised successor would replay
///   `--control-url` into a detached child with no off-argv secret and fail
///   closed, so supervised mode must never call [spawnSuccessor].
///
/// It deliberately does NOT shut the current process down. The restart
/// dispatcher emits a shutdown request only after the debug response closes or
/// the relay response is synchronously enqueued. Relay delivery remains
/// best-effort through the existing graceful close.
class BridgeRestartService({
    required ProcessRepository processRepository,
    required BridgeRestartCommandBuilder commandBuilder,
    required String binaryPath,
    required List<String> cliArgs,
    required int currentPid,
    required bool isSupervised,
    required void Function() onSupervisedRestartRequested,
  }) {
  this : _processRepository = processRepository,
       _commandBuilder = commandBuilder,
       _binaryPath = binaryPath,
       _cliArgs = cliArgs,
       _currentPid = currentPid,
       _isSupervised = isSupervised,
       _onSupervisedRestartRequested = onSupervisedRestartRequested;

  final ProcessRepository _processRepository;
  final BridgeRestartCommandBuilder _commandBuilder;
  final String _binaryPath;
  final List<String> _cliArgs;
  final int _currentPid;
  final bool _isSupervised;

  /// Invoked the moment a supervised restart handoff is decided, before the
  /// shutdown it triggers, so the composition root can record the GUI-respawn
  /// sentinel exit code ahead of any teardown (including a hung one whose
  /// backstop force-exits). Only ever invoked in supervised mode; standalone
  /// spawns a successor instead.
  final void Function() _onSupervisedRestartRequested;

  /// Whether an explicit restart can be delivered right now, so the handler only
  /// promises a restart it can actually carry out.
  ///
  /// Supervised bridges are always restartable — the desktop GUI respawns the
  /// process, so no managed successor binary is required (a bundled helper is a
  /// child process, not necessarily installed at the managed CLI path). Standalone
  /// requires a spawnable managed successor binary ([canSpawnSuccessor]).
  Future<bool> canRestart() async {
    if (_isSupervised) {
      return true;
    }
    return canSpawnSuccessor();
  }

  /// Whether the managed binary exists and is executable, so the standalone
  /// handoff only promises a restart it can actually deliver (an unspawnable
  /// bridge fails fast with an error response instead of a dropped session).
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
  /// caller should now request graceful shutdown.
  ///
  /// - **supervised:** notifies `onSupervisedRestartRequested` and returns `true`
  ///   without spawning a successor — the desktop GUI respawns this process after
  ///   it exits with the sentinel code.
  /// - **standalone:** spawns a successor and returns whether it started; `false`
  ///   means the bridge could not be replaced and should keep running.
  Future<bool> performRestartHandoff() async {
    if (_isSupervised) {
      Log.i('Supervised restart: exiting for GUI respawn (no successor spawn)');
      _onSupervisedRestartRequested();
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
