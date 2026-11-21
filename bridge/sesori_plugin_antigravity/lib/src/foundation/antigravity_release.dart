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
  static const String registryCommit = "e29b5bf3bfd8756db5d901690b43dc31e926ccd5";
  static const String registryPackageVersion = "1.5.2";
  static const int protocolVersion = 1;
  static const String serverBuildLabelPrefix = "agy_acp_server_";
  static const String agentVersion = "1.5.2";

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
            "agy-acp-server-1.5.2-darwin-x86_64.zip",
        archiveSha256: "92addb5580577b5356d35484d72d1a113d9c5312ad766bcb304983aa8e3fbb06",
        archiveBytes: 106351992,
        serverBytes: 184312784,
        harnessBytes: 134350320,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/macos/"
            "agy-acp-server-1.5.2-darwin-arm64.zip",
        archiveSha256: "123a16d5c40a8ac99e20f01a62b68dd860fd96b1c528dfb8eaa37ca8733d4845",
        archiveBytes: 100309778,
        serverBytes: 179921328,
        harnessBytes: 129208672,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.5.2-linux-x86_64.zip",
        archiveSha256: "99dd8612450805011619d7b8447ce374c289e00549d8557f36790e1dd6256852",
        archiveBytes: 273964075,
        serverBytes: 714384320,
        harnessBytes: 139194456,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-1.5.2-linux-arm64.zip",
        archiveSha256: "e729e05ef54ef0763e48900032466b47fa7c9939cde257f93ba49410ab577acb",
        archiveBytes: 264270419,
        serverBytes: 721649155,
        harnessBytes: 132598576,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.5.2-windows-x86_64.zip",
        archiveSha256: "5cbadd4f4df698572473d8890fc26ec2dc1724501f06e3a963941daec2bd21d6",
        archiveBytes: 105407645,
        serverBytes: 58368800,
        harnessBytes: 155357336,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-1.5.2-windows-arm64.zip",
        archiveSha256: "8a4b2ea8df2ffefae33309348752e9119d21a6d36090c0eb48631c2e8f5781ab",
        archiveBytes: 108049351,
        serverBytes: 65130848,
        harnessBytes: 146707096,
      ),
    },
  };

  // The extracted macOS ARM64 siblings are also independently hashed.
  static const String macosArm64ServerSha256 = "4cea3c96875a4bb66a1c136d972b5cfdc5f7c91579ff7b9cbfc158a4358270bc";
  static const String macosArm64HarnessSha256 = "31ec5f444b8c849ddb14da1c0893a87dddab60f1d5e282b79db36dc41b2521ab";

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
