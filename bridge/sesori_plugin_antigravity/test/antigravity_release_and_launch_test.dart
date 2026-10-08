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
        "f6c0f4e8357c7f28e84e3b883695c387b04ed2b9",
        "1.3.0",
        "1.3.0",
      ),
    );
    final macArtifact = AntigravityRelease.artifactFor(target: macArm);
    expect(
      (macArtifact.archiveBytes, macArtifact.serverBytes, macArtifact.harnessBytes),
      (111456962, 278535456, 118611392),
    );
    expect(
      macArtifact.archiveUrl,
      "https://dl.google.com/agy-extensions/releases/macos/"
      "agy-acp-server-1.3.0-darwin-arm64.zip",
    );
    expect(macArtifact.archiveSha256, "7cd97045f7b4fe81175a107cdf16f9c51484e3c78a5162cae415338bb6aa5b88");
    expect(
      AntigravityRelease.macosArm64ServerSha256,
      "cb1f0725183ed922079ed6cd1d2422b4d8be44c5fb60be3e9a43d8d04f99a18e",
    );
    expect(
      AntigravityRelease.macosArm64HarnessSha256,
      "b04b00662c1821b953a409d43626b86d1229130eeb2078b4e1304c06199aa481",
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
        "bb23956b89984bf5d354af2c3725e6c57f0cc1b7228e77a0e91c9c2bc1d47646",
        117245544,
        282840688,
        124175392,
      ),
      macArm: (
        "darwin-arm64.zip",
        "7cd97045f7b4fe81175a107cdf16f9c51484e3c78a5162cae415338bb6aa5b88",
        111456962,
        278535456,
        118611392,
      ),
      linuxX64: (
        "linux-x86_64.zip",
        "9fb60956af0a9d76220a4db91ca9ac88e2a2372ad68f985ab5fceace6b825b96",
        333727150,
        926533965,
        130388040,
      ),
      linuxArm: (
        "linux-arm64.zip",
        "500b0bc0fb858e88f4df404d4cedf80bf9298c178291e39e383d6c50b111cbdf",
        321690363,
        930848992,
        123224968,
      ),
      winX64: (
        "windows-x86_64.zip",
        "65215e0688681fa3116e048a9eab27ef53af1bbd6f3da3f1c52bd4911d8b17f9",
        124509787,
        81437336,
        145548952,
      ),
      winArm: (
        "windows-arm64.zip",
        "4a0f469720e9beb9438a979f543fdbfad5022ebe0992c052c590bd78b3144ca3",
        124654803,
        85893472,
        135640216,
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
