import "package:acp_plugin/acp_plugin.dart";

abstract final class OmpBinary {
  static const String defaultBinary = "omp";

  static AcpLaunchSpec launchSpec({
    required String binary,
    required String cwd,
  }) => AcpLaunchSpec(
    command: binary,
    args: const ["acp"],
    cwd: cwd,
  );
}
