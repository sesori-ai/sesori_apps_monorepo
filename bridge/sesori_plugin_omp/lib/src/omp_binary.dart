import "package:acp_plugin/acp_plugin.dart";

abstract final class OmpBinary {
  static const String defaultBinary = "omp";

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
