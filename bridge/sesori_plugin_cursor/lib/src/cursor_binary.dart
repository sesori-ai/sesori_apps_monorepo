import "package:acp_plugin/acp_plugin.dart";

/// Builds the launch spec for `cursor-agent acp`.
///
/// Auth is out of band: the default process factory inherits the bridge's
/// environment, so `CURSOR_API_KEY` / `CURSOR_AUTH_TOKEN` (or a prior
/// `cursor-agent login`) are passed through automatically.
abstract final class CursorBinary {
  /// The current installer exposes both names for the same payload. Use
  /// `cursor-agent` because older installs may not provide the `agent` symlink.
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
