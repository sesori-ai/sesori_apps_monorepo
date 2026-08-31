/// Layer-0 capability that supplies the environment for a supervised bridge
/// child process.
///
/// Desktop launchers such as macOS LaunchAgents do not inherit the interactive
/// terminal environment. Implementations may enrich the inherited environment
/// (for example, its executable search path), but must not make lifecycle or
/// plugin decisions. This capability does not grant filesystem permissions;
/// the child still runs with the desktop user's normal OS credentials.
abstract interface class BridgeProcessEnvironment() {
  /// Returns environment overrides. The process boundary continues to inherit
  /// the desktop process's other variables.
  Future<Map<String, String>> resolve();
}
