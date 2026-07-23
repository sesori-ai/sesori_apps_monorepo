import "package:acp_plugin/acp_plugin.dart";

/// Builds the launch spec for `cursor-agent acp`.
///
/// Auth is out of band: the default process factory inherits the bridge's
/// environment, so `CURSOR_API_KEY` / `CURSOR_AUTH_TOKEN` (or a prior
/// `cursor-agent login`) are passed through automatically.
abstract final class CursorBinary {
  /// The stable Cursor CLI executable. The user-facing `agent` command can be
  /// registered as shell state, which is unavailable to a headless bridge.
  static const String defaultBinary = "cursor-agent";

  static AcpLaunchSpec launchSpec({
    String binary = defaultBinary,
    String? cwd,
    String? apiEndpoint,
    Map<String, String> environment = const {},
  }) {
    return AcpLaunchSpec(
      command: binary,
      args: [
        if (apiEndpoint != null) ...["-e", apiEndpoint],
        "acp",
      ],
      cwd: cwd,
      environment: environment,
    );
  }
}
