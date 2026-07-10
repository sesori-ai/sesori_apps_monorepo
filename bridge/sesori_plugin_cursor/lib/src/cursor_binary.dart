import "package:acp_plugin/acp_plugin.dart";

/// Builds the launch spec for `agent acp`.
///
/// Auth is out of band: the default process factory inherits the bridge's
/// environment, so `CURSOR_API_KEY` / `CURSOR_AUTH_TOKEN` (or a prior
/// `agent login`) are passed through automatically.
abstract final class CursorBinary {
  /// The Cursor CLI's official binary name (`agent`, per cursor.com/docs/cli;
  /// `agent acp` is the documented ACP server mode). Older installs that only
  /// ship the legacy `cursor-agent` name can point `--cursor-bin` at it.
  static const String defaultBinary = "agent";

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
