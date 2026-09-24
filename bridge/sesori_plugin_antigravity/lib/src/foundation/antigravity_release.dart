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
  static const String registryCommit = "7384f5e98d28cbbeba10035d520bdb680b19b3d8";
  static const String registryPackageVersion = "1.2.1";
  static const int protocolVersion = 1;
  static const String serverBuildLabelPrefix = "agy_acp_server_";
  static const String agentVersion = "1.2.1";

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
            "agy-acp-server-1.2.1-darwin-x86_64.zip",
        archiveSha256: "d09bf99bdea7b82021e1afcff829da35e4aa583d8f0984ef364dc3a7c064e07e",
        archiveBytes: 117493869,
        serverBytes: 281143216,
        harnessBytes: 126174208,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/macos/"
            "agy-acp-server-1.2.1-darwin-arm64.zip",
        archiveSha256: "0fab9938812e6b32b3b543e65e4f3a0025ceef755413db13542d9a9b81ea803c",
        archiveBytes: 111725488,
        serverBytes: 276920768,
        harnessBytes: 120663872,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.2.1-linux-x86_64.zip",
        archiveSha256: "9fbf0bd584a26478161f637cabd75113f72541c842d148f578ef1a6a9edcb843",
        archiveBytes: 333590110,
        serverBytes: 919951920,
        harnessBytes: 132815192,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.2.1-linux-arm64.zip",
        archiveSha256: "7e7ef4088bc185e1af4204029e0f4ec4210af20724f3ff262186ac0bcea6aa0e",
        archiveBytes: 321280184,
        serverBytes: 921424555,
        harnessBytes: 125568904,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.2.1-windows-x86_64.zip",
        archiveSha256: "9b82493819bc14613baa76264d55ad307ddd8ab4a8d6e110edb32da35498c07b",
        archiveBytes: 124869770,
        serverBytes: 81231712,
        harnessBytes: 147063448,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.2.1-windows-arm64.zip",
        archiveSha256: "21db37ae246284053212f2670e05c4de8d6ee9488b000bf304e1fe4ea191f7b8",
        archiveBytes: 124945935,
        serverBytes: 85647280,
        harnessBytes: 137181336,
      ),
    },
  };

  // The extracted macOS ARM64 siblings are also independently hashed.
  static const String macosArm64ServerSha256 = "c93c86c0f505fcdf8b13c695bed26d306141ef5446189d591397074d324db34e";
  static const String macosArm64HarnessSha256 = "1b8a2b712ca312c9769e425b800bfbcceec4770f19736404474d1e8e50d65456";

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
