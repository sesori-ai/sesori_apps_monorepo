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
  static const String registryCommit = "536e378b70a7a6d5f078a9160180e3569a23253c";
  static const String registryPackageVersion = "1.0.0";
  static const int protocolVersion = 1;
  static const String agentVersion = "agy_acp_server_20260818_01_RC01";

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

  /// Immutable facts independently verified from all five official archives.
  static const Map<PlatformOs, Map<PlatformArch, AntigravityReleaseArtifact>> artifacts = {
    PlatformOs.macos: {
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/macos/"
            "agy-acp-server-agy_acp_server_20260818_01_RC01-darwin-arm64.zip",
        archiveSha256: "f122ca7e7030a27f9649da4cf1a7d80e12c48c5f6118ff35affc34d56cbf83dd",
        archiveBytes: 314500221,
        serverBytes: 792105680,
        harnessBytes: 101551680,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-agy_acp_server_20260818_01_RC01-linux-x86_64.zip",
        archiveSha256: "ce3f09628575b25497cf5a3c19d073b49acb80f1dab1ff8592919e9c9b8799e1",
        archiveBytes: 543411011,
        serverBytes: 1529513909,
        harnessBytes: 117532520,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-agy_acp_server_20260818_01_RC01-linux-arm64.zip",
        archiveSha256: "70fcdac70684de60f7a0eb16ea497d6cc4498728420f060e0850cfc9a9329b40",
        archiveBytes: 524995159,
        serverBytes: 1519373648,
        harnessBytes: 110601552,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-agy_acp_server_20260818_01_RC01-windows-x86_64.zip",
        archiveSha256: "35c7dd169c2794172ce02e9444a6db4a8ed4bb11398be07976cac2ee494f44e6",
        archiveBytes: 331985114,
        serverBytes: 297200088,
        harnessBytes: 122038424,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-agy_acp_server_20260818_01_RC01-windows-arm64.zip",
        archiveSha256: "1522056748d45fbc34d0be72b41b99b0637be1b4caad0b34d37eb16d04ccb9c4",
        archiveBytes: 332484576,
        serverBytes: 301449928,
        harnessBytes: 114173080,
      ),
    },
  };

  // Step 2 also independently hashed the extracted macOS members.
  static const String macosArm64ServerSha256 = "6d700b48eaaab70b1083b4d18d63e81b6d8cdc1da1c4670db29f5986f9d484ef";
  static const String macosArm64HarnessSha256 = "34d78dd5fd0e24a628ed6487bc6a042ff9419f7122f5f761b001d218f2c9d026";

  static AntigravityReleaseArtifact? artifactFor({required PlatformTarget target}) =>
      artifacts[target.os]?[target.arch];

  static bool supportsTarget({required PlatformTarget target}) => artifactFor(target: target) != null;

  static String serverFileName({required PlatformTarget target}) {
    _requireSupported(target: target);
    return target.os == PlatformOs.windows ? windowsServerFileName : posixServerFileName;
  }

  static String harnessFileName({required PlatformTarget target}) {
    _requireSupported(target: target);
    return target.os == PlatformOs.windows ? windowsHarnessFileName : posixHarnessFileName;
  }

  static List<String> launchArguments({required PlatformTarget target}) {
    _requireSupported(target: target);
    return target.os == PlatformOs.linux ? const [linuxUidArgument] : const [];
  }

  static void _requireSupported({required PlatformTarget target}) {
    if (!supportsTarget(target: target)) {
      throw UnsupportedError("Google does not publish Antigravity ACP for ${target.key}");
    }
  }
}
