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
  static const String registryCommit = "d30bc9a7c011b522e8502281d5fbcfca51abd5ff";
  static const String registryPackageVersion = "1.1.1";
  static const int protocolVersion = 1;
  static const String agentVersion = "agy_acp_server_1.1.1";

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
            "agy-acp-server-agy_acp_server_1.1.1-darwin-arm64.zip",
        archiveSha256: "fdfa915652cdb7ba8085cc8fffed072cbe009251aa2c951aabdda07a8c28a189",
        archiveBytes: 316014828,
        serverBytes: 802163856,
        harnessBytes: 116766704,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-agy_acp_server_1.1.1-linux-x86_64.zip",
        archiveSha256: "38f62d01b32deb0907b3d39a71ec301fd36369f6ffd1cf262d4af385177f79df",
        archiveBytes: 681969407,
        serverBytes: 1880360328,
        harnessBytes: 128966920,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/linux/"
            "agy-acp-server-agy_acp_server_1.1.1-linux-arm64.zip",
        archiveSha256: "ed69e64b308fcb123ab54bf3277bf9cb0d651064f885ea5aab0ff520c7175398",
        archiveBytes: 656572786,
        serverBytes: 1862073131,
        harnessBytes: 122158704,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.x64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-agy_acp_server_1.1.1-windows-x86_64.zip",
        archiveSha256: "47cb50eef14f0a4655d78cfcfda869bcea7aaee5f9787e936bc2935ea612c3b8",
        archiveBytes: 468238392,
        serverBytes: 430801616,
        harnessBytes: 130971800,
      ),
      PlatformArch.arm64: AntigravityReleaseArtifact(
        archiveUrl:
            "https://dl.google.com/agy-extensions/releases/windows/"
            "agy-acp-server-agy_acp_server_1.1.1-windows-arm64.zip",
        archiveSha256: "35f4b1f47ba6a3fea7b0a3e30010df5ea73a64b4f0e7cf991cddc673ddfbcafc",
        archiveBytes: 468521191,
        serverBytes: 435075816,
        harnessBytes: 122455704,
      ),
    },
  };

  // The extracted macOS ARM64 siblings are also independently hashed.
  static const String macosArm64ServerSha256 = "9d900b93031fc42397f88206e14eba4193729bbef631a70b18e7a19631a6dfac";
  static const String macosArm64HarnessSha256 = "e0a8ef9d80a1ffb178f945159dda33f73d4a5be65516642542352584b834fa2a";

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
