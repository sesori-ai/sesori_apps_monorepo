import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  const macArm = PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64);
  const macX64 = PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64);
  const linuxX64 = PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64);
  const linuxArm = PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64);
  const winX64 = PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64);
  const winArm = PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64);

  test("pins the independently verified official release", () {
    expect(
      (
        AntigravityIdentity.pluginId,
        AntigravityIdentity.upstreamAgentName,
        AntigravityRelease.registryCommit,
        AntigravityRelease.registryPackageVersion,
        AntigravityRelease.agentVersion,
      ),
      (
        "antigravity",
        "antigravity-acp",
        "536e378b70a7a6d5f078a9160180e3569a23253c",
        "1.0.0",
        "agy_acp_server_20260818_01_RC01",
      ),
    );
    expect(
      (
        AntigravityRelease.macosArm64ArchiveBytes,
        AntigravityRelease.macosArm64ServerBytes,
        AntigravityRelease.macosArm64HarnessBytes,
      ),
      (314500221, 792105680, 101551680),
    );
    expect(
      AntigravityRelease.macosArm64ArchiveUrl,
      "https://dl.google.com/agy-extensions/releases/macos/"
      "agy-acp-server-agy_acp_server_20260818_01_RC01-darwin-arm64.zip",
    );
    expect(
      AntigravityRelease.macosArm64ArchiveSha256,
      "f122ca7e7030a27f9649da4cf1a7d80e12c48c5f6118ff35affc34d56cbf83dd",
    );
    expect(
      AntigravityRelease.macosArm64ServerSha256,
      "6d700b48eaaab70b1083b4d18d63e81b6d8cdc1da1c4670db29f5986f9d484ef",
    );
    expect(
      AntigravityRelease.macosArm64HarnessSha256,
      "34d78dd5fd0e24a628ed6487bc6a042ff9419f7122f5f761b001d218f2c9d026",
    );
    expect(
      AntigravityRelease.advertisedAuthenticationMethodIds,
      {"oauth-personal", "oauth-business", "gemini-api-key", "agent-platform"},
    );
  });

  test("maps the five published targets and rejects macOS x64", () {
    for (final target in [macArm, linuxX64, linuxArm, winX64, winArm]) {
      expect(AntigravityRelease.supportsTarget(target: target), isTrue);
    }
    expect(AntigravityRelease.supportsTarget(target: macX64), isFalse);
    expect(() => AntigravityRelease.serverFileName(target: macX64), throwsUnsupportedError);
    expect(AntigravityRelease.serverFileName(target: winArm), "agy_acp_server.exe");
    expect(AntigravityRelease.harnessFileName(target: winArm), "localharness_external.exe");
    expect(AntigravityRelease.serverFileName(target: linuxArm), "agy_acp_server.par");
    expect(AntigravityRelease.harnessFileName(target: linuxArm), "localharness_external");
  });

  test("builds exact Linux and Windows launch specs", () {
    const linuxPair = AntigravityRuntimePair(
      serverPath: "/runtime/agy_acp_server.par",
      harnessPath: "/runtime/localharness_external",
      target: linuxArm,
    );
    final linux = const AntigravityLaunchSpecBuilder().build(
      pair: linuxPair,
      cwd: "/workspace",
      environment: const {"GEMINI_HOME": "/profile"},
    );
    expect((linux.command, linux.cwd), (linuxPair.serverPath, "/workspace"));
    expect(linux.args, ["--uid="]);
    expect(linux.environment, {
      "GEMINI_HOME": "/profile",
      "ANTIGRAVITY_HARNESS_PATH": linuxPair.harnessPath,
    });
    expect(() => linux.environment["ambient"] = "value", throwsUnsupportedError);

    const windowsPair = AntigravityRuntimePair(
      serverPath: r"C:\runtime\agy_acp_server.exe",
      harnessPath: r"C:\runtime\localharness_external.exe",
      target: winArm,
    );
    final windows = const AntigravityLaunchSpecBuilder().build(
      pair: windowsPair,
      cwd: null,
      environment: const {},
    );
    expect(windows.command, windowsPair.serverPath);
    expect(windows.args, isEmpty);
    expect(windows.environment[AntigravityRelease.harnessPathEnvironmentKey], windowsPair.harnessPath);
  });
}
