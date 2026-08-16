import "package:acp_plugin/acp_plugin.dart";

/// Builds the launch spec for `hermes acp`.
///
/// Auth is out of band: the process inherits the bridge environment and Hermes
/// also loads `$HERMES_HOME/.env` (default `~/.hermes/.env`), so provider/model
/// setup completed through `hermes setup` or `hermes model` is reused.
abstract final class HermesBinary() {
  /// The Hermes CLI launcher, resolved on PATH.
  static const String defaultBinary = "hermes";

  static AcpLaunchSpec launchSpec({
    required String binary,
    required String? cwd,
    required Map<String, String> environment,
  }) {
    return AcpLaunchSpec(
      command: binary,
      args: const ["acp"],
      cwd: cwd,
      environment: environment,
    );
  }
}
