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
  static const String registryCommit = "06229c691d24d039e2363ba12abe5c9dfae5bc66";
  static const String registryPackageVersion = "1.4.3";
  static const int protocolVersion = 1;
  static const String serverBuildLabelPrefix = "agy_acp_server_";
  static const String agentVersion = "1.4.3";

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
            "agy-acp-server-1.4.3-darwin-x86_64.zip",
        archiveSha256: "9392dbbdad7f0663dbfb5a0bf641297b0cf80d2ee9cd2d49a616bbbc7378731d",
        archiveBytes: 119801100,
        serverBytes: 286653712,
        harnessBytes: 127612208,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/macos/"
            "agy-acp-server-1.4.3-darwin-arm64.zip",
        archiveSha256: "c57db0a9b8b712daa9c3c17cdb990a61842ea569f279e8bd79d7aa85a303b20b",
        archiveBytes: 114147623,
        serverBytes: 282446160,
        harnessBytes: 122957936,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.4.3-linux-x86_64.zip",
        archiveSha256: "0634ce5306ba92c932945455e7a83fda78e2d99c33fa8aa6ee0566206a382714",
        archiveBytes: 336846435,
        serverBytes: 927707135,
        harnessBytes: 133926136,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.4.3-linux-arm64.zip",
        archiveSha256: "05c153443b0b1175151c760eeddea538950bc9843e317d54786a1f03670182bc",
        archiveBytes: 322887047,
        serverBytes: 932662106,
        harnessBytes: 127512832,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.4.3-windows-x86_64.zip",
        archiveSha256: "54c2e16378d9a4952e1da70e355f3c33c4f284308d6de48ab3e6e34a127bd325",
        archiveBytes: 131267135,
        serverBytes: 87022872,
        harnessBytes: 147843736,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.4.3-windows-arm64.zip",
        archiveSha256: "fcd46431ad33d3b510ce0b98fe7b43d095bd8b3f1c363ee2d57faa7ee981c7bb",
        archiveBytes: 134301870,
        serverBytes: 94238816,
        harnessBytes: 139322008,
      ),
    },
  };

  // The extracted macOS ARM64 siblings are also independently hashed.
  static const String macosArm64ServerSha256 = "1251927db3e21f3d693fd042d6890d82f65eb00587e97f1f3d8f0d798e7f0954";
  static const String macosArm64HarnessSha256 = "9e8fdc6e20a3262ca0a771850ca4a8414ca839a642cc964ec5c547cc2c33c200";

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
