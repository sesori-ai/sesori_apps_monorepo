import "package:acp_plugin/acp_plugin.dart";

/// Builds the launch spec for `hermes acp`.
///
/// Auth is out of band: the process factory inherits the bridge's
/// environment, so a Hermes install with a configured provider/model
/// (via `hermes setup` / `hermes model`) is picked up automatically.
abstract final class HermesBinary() {
  /// The Hermes CLI launcher, resolved on PATH.
  static const String defaultBinary = "hermes";

  static AcpLaunchSpec launchSpec({
    String binary = defaultBinary,
    String? cwd,
    Map<String, String> environment = const {},
  }) {
    return AcpLaunchSpec(
      command: binary,
      args: const ["acp"],
      cwd: cwd,
      environment: environment,
    );
  }
}
