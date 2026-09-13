import '../foundation/bridge_restart_env.dart';

typedef WindowsRestartSuccessorStarter = Future<void> Function({
  required String executable,
  required List<String> arguments,
  required Map<String, String> environment,
});

typedef WindowsRestartLauncherExit = void Function({required int code});

/// Runs the real Windows restart successor behind one short-lived launcher.
///
/// Once this launcher exits, the successor no longer has a live ancestry chain
/// back to the predecessor. A later `taskkill /T` can therefore terminate the
/// predecessor and every other descendant without terminating the successor.
/// Exit code zero acknowledges successful child creation to the waiting
/// predecessor; a spawn failure instead reaches the entrypoint's non-zero exit.
class WindowsRestartSuccessorLauncher({
  required final bool _isWindows,
  required Map<String, String> environment,
  required final String _executable,
  required final WindowsRestartSuccessorStarter _start,
  required final WindowsRestartLauncherExit _exitLauncher,
}) {
  final Map<String, String> _environment = Map<String, String>.unmodifiable(environment);

  Future<bool> launchIfRequested({required List<String> arguments}) async {
    if (!_isWindows || _environment[sesoriRestartLauncherEnvVar] != sesoriRestartLauncherEnvValue) return false;
    final childEnvironment = Map<String, String>.of(_environment)..remove(sesoriRestartLauncherEnvVar);
    await _start(
      executable: _executable,
      arguments: List<String>.unmodifiable(arguments),
      environment: Map<String, String>.unmodifiable(childEnvironment),
    );
    // Process.start keeps a process watcher alive even when nobody awaits the
    // child's exit. Terminate this dedicated launcher explicitly so its process
    // cannot remain as an ancestry link back to the predecessor.
    _exitLauncher(code: 0);
    return true;
  }
}
