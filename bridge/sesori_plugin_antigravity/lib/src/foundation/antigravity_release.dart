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
  static const String registryCommit = "02b460362cfedf4d43b03df7aad6d79a353fe064";
  static const String registryPackageVersion = "1.4.5";
  static const int protocolVersion = 1;
  static const String serverBuildLabelPrefix = "agy_acp_server_";
  static const String agentVersion = "1.4.5";

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
            "agy-acp-server-1.4.5-darwin-x86_64.zip",
        archiveSha256: "b39f3573c03b9acb9df028853f647527f1f3133f32bd77e78b796e48a205114a",
        archiveBytes: 103577295,
        serverBytes: 183127600,
        harnessBytes: 127612208,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/macos/"
            "agy-acp-server-1.4.5-darwin-arm64.zip",
        archiveSha256: "886fff7767d08994ca39eb02c3d01a7532c7325a94aa33aaf52d52068733284f",
        archiveBytes: 97923855,
        serverBytes: 178915920,
        harnessBytes: 122957936,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.4.5-linux-x86_64.zip",
        archiveSha256: "923923a0d7dc8073f66cc6f78647a3107e3a7ee2b7e1a24df8b3927b5188013b",
        archiveBytes: 321783181,
        serverBytes: 826226766,
        harnessBytes: 133926136,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.4.5-linux-arm64.zip",
        archiveSha256: "7d64246633ae094f67e3bbcd2d679e89048f91346d5339313336e7483f40f056",
        archiveBytes: 307829008,
        serverBytes: 831194025,
        harnessBytes: 127512832,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.4.5-windows-x86_64.zip",
        archiveSha256: "d24f4c73c9f96d4f44384e281c855a56c72d8eaa9c5b0fad7ccb1635c6b63f50",
        archiveBytes: 100423655,
        serverBytes: 55839864,
        harnessBytes: 147843736,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.4.5-windows-arm64.zip",
        archiveSha256: "ab0a9aac8349e08ef289be6d16da8f89e3abe60eba5158032ef78c4a1220261c",
        archiveBytes: 102703121,
        serverBytes: 62293488,
        harnessBytes: 139322008,
      ),
    },
  };

  // The extracted macOS ARM64 siblings are also independently hashed.
  static const String macosArm64ServerSha256 = "fb2581fb49738263db15ffccf3f48d979794ffb748350e85c335953f6b6522a2";
  static const String macosArm64HarnessSha256 = "9d87cb505e6efa316f55bb98459de614de867dce43cdeb5677b2153d77c283e8";

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
