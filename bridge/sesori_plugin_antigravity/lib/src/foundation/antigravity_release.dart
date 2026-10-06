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
  static const String registryCommit = "f6c0f4e8357c7f28e84e3b883695c387b04ed2b9";
  static const String registryPackageVersion = "1.3.0";
  static const int protocolVersion = 1;
  static const String serverBuildLabelPrefix = "agy_acp_server_";
  static const String agentVersion = "1.3.0";

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
            "agy-acp-server-1.3.0-darwin-x86_64.zip",
        archiveSha256: "bb23956b89984bf5d354af2c3725e6c57f0cc1b7228e77a0e91c9c2bc1d47646",
        archiveBytes: 117245544,
        serverBytes: 282840688,
        harnessBytes: 124175392,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/macos/"
            "agy-acp-server-1.3.0-darwin-arm64.zip",
        archiveSha256: "7cd97045f7b4fe81175a107cdf16f9c51484e3c78a5162cae415338bb6aa5b88",
        archiveBytes: 111456962,
        serverBytes: 278535456,
        harnessBytes: 118611392,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.3.0-linux-x86_64.zip",
        archiveSha256: "9fb60956af0a9d76220a4db91ca9ac88e2a2372ad68f985ab5fceace6b825b96",
        archiveBytes: 333727150,
        serverBytes: 926533965,
        harnessBytes: 130388040,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.3.0-linux-arm64.zip",
        archiveSha256: "500b0bc0fb858e88f4df404d4cedf80bf9298c178291e39e383d6c50b111cbdf",
        archiveBytes: 321690363,
        serverBytes: 930848992,
        harnessBytes: 123224968,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.3.0-windows-x86_64.zip",
        archiveSha256: "65215e0688681fa3116e048a9eab27ef53af1bbd6f3da3f1c52bd4911d8b17f9",
        archiveBytes: 124509787,
        serverBytes: 81437336,
        harnessBytes: 145548952,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.3.0-windows-arm64.zip",
        archiveSha256: "4a0f469720e9beb9438a979f543fdbfad5022ebe0992c052c590bd78b3144ca3",
        archiveBytes: 124654803,
        serverBytes: 85893472,
        harnessBytes: 135640216,
      ),
    },
  };

  // The extracted macOS ARM64 siblings are also independently hashed.
  static const String macosArm64ServerSha256 = "cb1f0725183ed922079ed6cd1d2422b4d8be44c5fb60be3e9a43d8d04f99a18e";
  static const String macosArm64HarnessSha256 = "b04b00662c1821b953a409d43626b86d1229130eeb2078b4e1304c06199aa481";

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
