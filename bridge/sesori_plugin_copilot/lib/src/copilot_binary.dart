import "package:acp_plugin/acp_plugin.dart";

/// Builds the launch specification for GitHub Copilot CLI's ACP server.
///
/// Authentication remains out of band. The process inherits credentials from
/// a prior `copilot login`, supported GitHub token environment variables, or a
/// configured BYOK provider through the host-owned process factory.
abstract final class CopilotBinary() {
  static const String defaultBinary = "copilot";

  /// Copilot's standard ACP authentication method for its local login state.
  static const String acpAuthMethodId = "copilot-login";

  static AcpLaunchSpec catalogLaunchSpec({
    required AcpLaunchSpec liveSpec,
    required String configDirectory,
  }) => AcpLaunchSpec(
    command: liveSpec.command,
    args: liveSpec.args,
    cwd: liveSpec.cwd,
    environment: {...liveSpec.environment, "COPILOT_HOME": configDirectory},
  );

  static AcpLaunchSpec launchSpec({
    required String binary,
    required String cwd,
    required Map<String, String> environment,
  }) {
    return AcpLaunchSpec(
      command: binary,
      // A bridge-owned process must not replace the runtime selected and
      // version-gated by its descriptor while that process is starting.
      args: const ["--no-auto-update", "--acp"],
      cwd: cwd,
      environment: environment,
    );
  }
}
