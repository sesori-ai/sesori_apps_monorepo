import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

/// One immutable artifact from Google's official ACP registry release.
final class const AntigravityReleaseArtifact({
  required final String archiveUrl,
  required final String archiveSha256,
  required final int archiveBytes,
  required final int serverBytes,
  required final int harnessBytes,
});

/// Public facts pinned from Google's official ACP registry release.
abstract final class AntigravityRelease() {
  static const String registryCommit = "655791de14720cb08eaa9753f39ec0095f04fa2c";
  static const String registryPackageVersion = "1.5.0";
  static const int protocolVersion = 1;
  static const String serverBuildLabelPrefix = "agy_acp_server_";
  static const String agentVersion = "1.5.0";

  static const String personalOauthMethodId = "oauth-personal";
  static const Set<String> advertisedAuthenticationMethodIds = {
    personalOauthMethodId,
    "oauth-business",
    "gemini-api-key",
    "agent-platform",
  };

  static const String posixServerFileName = "agy_acp_server.par";
  static const String posixHarnessFileName = "localharness_external";
  static const String windowsServerFileName = "agy_acp_server.exe";
  static const String windowsHarnessFileName = "localharness_external.exe";
  static const String harnessPathEnvironmentKey = "ANTIGRAVITY_HARNESS_PATH";
  static const String linuxUidArgument = "--uid=";

  /// Immutable facts independently verified from all six official archives.
  static const Map<PlatformOs, Map<PlatformArch, AntigravityReleaseArtifact>> artifacts = {
    PlatformOs.macos: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/macos/"
            "agy-acp-server-1.5.0-darwin-x86_64.zip",
        archiveSha256: "86a94e33b25d4a38ff30526ad844546860aa9ed98698498d9e87d30eb794426e",
        archiveBytes: 106461356,
        serverBytes: 184151792,
        harnessBytes: 134730544,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/macos/"
            "agy-acp-server-1.5.0-darwin-arm64.zip",
        archiveSha256: "c82ecb4ef476bfc35cbe5b2745cdddef873b99c9f5bd7fd11e5ca1fc1667a3fc",
        archiveBytes: 100401185,
        serverBytes: 179756208,
        harnessBytes: 129572384,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.5.0-linux-x86_64.zip",
        archiveSha256: "36f373e8948edf1727b39c7d62b5722d6a4474bdfd72b04ad3d6def571808c9f",
        archiveBytes: 274069093,
        serverBytes: 714224576,
        harnessBytes: 139570072,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.5.0-linux-arm64.zip",
        archiveSha256: "1e184f439477b54138e94440056b26a78c0a8075a8fd2ffda637ec31267c6459",
        archiveBytes: 264366319,
        serverBytes: 721489411,
        harnessBytes: 132951888,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.5.0-windows-x86_64.zip",
        archiveSha256: "6163f6b59b381bae419652dbae167bc8cda0ef29d665c0ba8af3d8c7fddd8867",
        archiveBytes: 105513364,
        serverBytes: 58314376,
        harnessBytes: 155782808,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.5.0-windows-arm64.zip",
        archiveSha256: "340092b8af6dafc71eb15f4a8ec54b4d1f0bce16d1fa4d163b562c50b905f8f4",
        archiveBytes: 108145235,
        serverBytes: 65077040,
        harnessBytes: 147104920,
      ),
    },
  };

  // The extracted macOS ARM64 siblings are also independently hashed.
  static const String macosArm64ServerSha256 = "bbb138a7ff32982e231af325e3176b252174f4c59e4fee7159c0e364ad5f9613";
  static const String macosArm64HarnessSha256 = "4eddc5c77a0bb275372fb548a9011a1acc70828a4a72412f2da0733c90db30fe";

  static AntigravityReleaseArtifact artifactFor({required PlatformTarget target}) =>
      artifacts[target.os]?[target.arch] ??
      (throw StateError("Missing Antigravity release artifact for ${target.key}"));

  static String serverFileName({required PlatformTarget target}) =>
      target.os == PlatformOs.windows ? windowsServerFileName : posixServerFileName;

  static String harnessFileName({required PlatformTarget target}) =>
      target.os == PlatformOs.windows ? windowsHarnessFileName : posixHarnessFileName;

  static List<String> launchArguments({required PlatformTarget target}) =>
      target.os == PlatformOs.linux ? const [linuxUidArgument] : const [];
}
