import "package:acp_plugin/acp_plugin.dart";

import "../foundation/antigravity_release.dart";
import "../models/antigravity_runtime_pair.dart";

/// Builds an ACP launch specification from one already-validated runtime pair.
class const AntigravityLaunchSpecBuilder() {
  AcpLaunchSpec build({
    required AntigravityRuntimePair pair,
    required String? cwd,
    required Map<String, String> environment,
  }) {
    return AcpLaunchSpec(
      command: pair.serverPath,
      args: AntigravityRelease.launchArguments(target: pair.target),
      cwd: cwd,
      environment: Map<String, String>.unmodifiable({
        ...environment,
        AntigravityRelease.harnessPathEnvironmentKey: pair.harnessPath,
      }),
    );
  }
}
