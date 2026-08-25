import "package:acp_plugin/acp_plugin.dart";

/// Builds the launch spec for `omp acp` and declares the handshake policy every
/// Sesori ACP connection to it (live plugin, catalog and cleanup leases) uses.
abstract final class OmpBinary() {
  static const String defaultBinary = "omp";

  /// The ACP auth method OMP advertises for its locally configured agent.
  static const String acpAuthMethodId = "agent";

  static AcpLaunchSpec launchSpec({
    required String binary,
    required String cwd,
    required String? sessionDirectory,
  }) => AcpLaunchSpec(
    command: binary,
    args: [
      "acp",
      if (sessionDirectory != null) ...["--session-dir", sessionDirectory],
    ],
    cwd: cwd,
  );
}
