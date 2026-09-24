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
        "7384f5e98d28cbbeba10035d520bdb680b19b3d8",
        "1.2.1",
        "1.2.1",
      ),
    );
    final macArtifact = AntigravityRelease.artifactFor(target: macArm);
    expect(
      (macArtifact.archiveBytes, macArtifact.serverBytes, macArtifact.harnessBytes),
      (111725488, 276920768, 120663872),
    );
    expect(
      macArtifact.archiveUrl,
      "https://dl.google.com/agy-extensions/releases/macos/"
      "agy-acp-server-1.2.1-darwin-arm64.zip",
    );
    expect(macArtifact.archiveSha256, "0fab9938812e6b32b3b543e65e4f3a0025ceef755413db13542d9a9b81ea803c");
    expect(
      AntigravityRelease.macosArm64ServerSha256,
      "c93c86c0f505fcdf8b13c695bed26d306141ef5446189d591397074d324db34e",
    );
    expect(
      AntigravityRelease.macosArm64HarnessSha256,
      "1b8a2b712ca312c9769e425b800bfbcceec4770f19736404474d1e8e50d65456",
    );
    expect(
      AntigravityRelease.advertisedAuthenticationMethodIds,
      {"oauth-personal", "oauth-business", "gemini-api-key", "agent-platform"},
    );
  });

  test("maps an independently verified archive for every host target", () {
    final expected = <PlatformTarget, (String, String, int, int, int)>{
      macX64: (
        "darwin-x86_64.zip",
        "d09bf99bdea7b82021e1afcff829da35e4aa583d8f0984ef364dc3a7c064e07e",
        117493869,
        281143216,
        126174208,
      ),
      macArm: (
        "darwin-arm64.zip",
        "0fab9938812e6b32b3b543e65e4f3a0025ceef755413db13542d9a9b81ea803c",
        111725488,
        276920768,
        120663872,
      ),
      linuxX64: (
        "linux-x86_64.zip",
        "9fbf0bd584a26478161f637cabd75113f72541c842d148f578ef1a6a9edcb843",
        333590110,
        919951920,
        132815192,
      ),
      linuxArm: (
        "linux-arm64.zip",
        "7e7ef4088bc185e1af4204029e0f4ec4210af20724f3ff262186ac0bcea6aa0e",
        321280184,
        921424555,
        125568904,
      ),
      winX64: (
        "windows-x86_64.zip",
        "9b82493819bc14613baa76264d55ad307ddd8ab4a8d6e110edb32da35498c07b",
        124869770,
        81231712,
        147063448,
      ),
      winArm: (
        "windows-arm64.zip",
        "21db37ae246284053212f2670e05c4de8d6ee9488b000bf304e1fe4ea191f7b8",
        124945935,
        85647280,
        137181336,
      ),
    };
    expect(
      expected.keys,
      unorderedEquals([
        for (final os in PlatformOs.values)
          for (final arch in PlatformArch.values) PlatformTarget(os: os, arch: arch),
      ]),
    );
    for (final entry in expected.entries) {
      final target = entry.key;
      final facts = entry.value;
      final artifact = AntigravityRelease.artifactFor(target: target);
      expect(artifact.archiveUrl, endsWith(facts.$1));
      expect(
        (artifact.archiveSha256, artifact.archiveBytes, artifact.serverBytes, artifact.harnessBytes),
        (facts.$2, facts.$3, facts.$4, facts.$5),
      );
    }
    expect(AntigravityRelease.serverFileName(target: macX64), "agy_acp_server.par");
    expect(AntigravityRelease.harnessFileName(target: macX64), "localharness_external");
    expect(AntigravityRelease.serverFileName(target: winArm), "agy_acp_server.exe");
    expect(AntigravityRelease.harnessFileName(target: winArm), "localharness_external.exe");
    expect(AntigravityRelease.serverFileName(target: linuxArm), "agy_acp_server.par");
    expect(AntigravityRelease.harnessFileName(target: linuxArm), "localharness_external");
  });

  test("builds exact macOS launch specs for both architectures", () {
    for (final target in [macArm, macX64]) {
      final pair = AntigravityRuntimePair(
        serverPath: "/runtime/agy_acp_server.par",
        harnessPath: "/runtime/localharness_external",
        target: target,
      );
      final launch = const AntigravityLaunchSpecBuilder().build(
        pair: pair,
        cwd: "/workspace",
        environment: const {"GEMINI_HOME": "/profile"},
      );
      expect((launch.command, launch.cwd), (pair.serverPath, "/workspace"));
      expect(launch.args, isEmpty);
      expect(launch.includeParentEnvironment, isFalse);
      expect(launch.environment, {
        "GEMINI_HOME": "/profile",
        "ANTIGRAVITY_HARNESS_PATH": pair.harnessPath,
      });
    }
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
    expect(linux.includeParentEnvironment, isFalse);
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
    expect(windows.includeParentEnvironment, isFalse);
    expect(windows.environment[AntigravityRelease.harnessPathEnvironmentKey], windowsPair.harnessPath);
  });
}
