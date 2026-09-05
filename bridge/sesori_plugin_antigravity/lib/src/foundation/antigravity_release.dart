import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

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

  /// Immutable facts independently verified from the Step 2 macOS arm64 artifact.
  static const String macosArm64ArchiveUrl =
      "https://dl.google.com/agy-extensions/releases/macos/"
      "agy-acp-server-agy_acp_server_20260818_01_RC01-darwin-arm64.zip";
  static const String macosArm64ArchiveSha256 = "f122ca7e7030a27f9649da4cf1a7d80e12c48c5f6118ff35affc34d56cbf83dd";
  static const int macosArm64ArchiveBytes = 314500221;
  static const int macosArm64ServerBytes = 792105680;
  static const String macosArm64ServerSha256 = "6d700b48eaaab70b1083b4d18d63e81b6d8cdc1da1c4670db29f5986f9d484ef";
  static const int macosArm64HarnessBytes = 101551680;
  static const String macosArm64HarnessSha256 = "34d78dd5fd0e24a628ed6487bc6a042ff9419f7122f5f761b001d218f2c9d026";

  static bool supportsTarget({required PlatformTarget target}) => switch ((target.os, target.arch)) {
    (PlatformOs.macos, PlatformArch.arm64) ||
    (PlatformOs.linux, PlatformArch.x64) ||
    (PlatformOs.linux, PlatformArch.arm64) ||
    (PlatformOs.windows, PlatformArch.x64) ||
    (PlatformOs.windows, PlatformArch.arm64) => true,
    (PlatformOs.macos, PlatformArch.x64) => false,
  };

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
