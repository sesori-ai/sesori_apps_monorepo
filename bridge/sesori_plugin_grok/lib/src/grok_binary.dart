import "package:acp_plugin/acp_plugin.dart";

/// Builds the launch specification for Grok Build's official ACP server.
///
/// The bridge owns a dedicated local agent process: it neither attaches to
/// Grok's shared leader nor lets the child update its executable. Ask-mode is
/// intentionally left enabled, so standard ACP permission requests reach the
/// Sesori client.
abstract final class GrokBinary() {
  /// Grok Build's CLI launcher, resolved on PATH by default.
  static const String defaultBinary = "grok";

  static AcpLaunchSpec launchSpec({
    required String binary,
    required String? cwd,
    required Map<String, String> environment,
  }) {
    return AcpLaunchSpec(
      command: binary,
      args: const [
        "--no-auto-update",
        "agent",
        "--no-leader",
        "stdio",
      ],
      cwd: cwd,
      environment: environment,
    );
  }
}
