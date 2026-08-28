import "package:acp_plugin/acp_plugin.dart";

abstract final class DeepSeekBinary() {
  static const String defaultBinary = "sesori-deepseek-acp";

  static AcpLaunchSpec launchSpec({
    required String binary,
    required String cwd,
    required String stateDirectory,
    required Map<String, String> environment,
  }) => AcpLaunchSpec(
    command: binary,
    args: ["serve", "--state-dir", stateDirectory],
    cwd: cwd,
    environment: {...environment, "DSH_TELEMETRY_MODE": "off"},
  );
}
