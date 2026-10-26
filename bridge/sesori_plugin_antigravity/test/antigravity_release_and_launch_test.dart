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
        "06229c691d24d039e2363ba12abe5c9dfae5bc66",
        "1.4.3",
        "1.4.3",
      ),
    );
    final macArtifact = AntigravityRelease.artifactFor(target: macArm);
    expect(
      (macArtifact.archiveBytes, macArtifact.serverBytes, macArtifact.harnessBytes),
      (114147623, 282446160, 122957936),
    );
    expect(
      macArtifact.archiveUrl,
      "https://dl.google.com/agy-extensions/releases/macos/"
      "agy-acp-server-1.4.3-darwin-arm64.zip",
    );
    expect(macArtifact.archiveSha256, "c57db0a9b8b712daa9c3c17cdb990a61842ea569f279e8bd79d7aa85a303b20b");
    expect(
      AntigravityRelease.macosArm64ServerSha256,
      "1251927db3e21f3d693fd042d6890d82f65eb00587e97f1f3d8f0d798e7f0954",
    );
    expect(
      AntigravityRelease.macosArm64HarnessSha256,
      "9e8fdc6e20a3262ca0a771850ca4a8414ca839a642cc964ec5c547cc2c33c200",
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
        "9392dbbdad7f0663dbfb5a0bf641297b0cf80d2ee9cd2d49a616bbbc7378731d",
        119801100,
        286653712,
        127612208,
      ),
      macArm: (
        "darwin-arm64.zip",
        "c57db0a9b8b712daa9c3c17cdb990a61842ea569f279e8bd79d7aa85a303b20b",
        114147623,
        282446160,
        122957936,
      ),
      linuxX64: (
        "linux-x86_64.zip",
        "0634ce5306ba92c932945455e7a83fda78e2d99c33fa8aa6ee0566206a382714",
        336846435,
        927707135,
        133926136,
      ),
      linuxArm: (
        "linux-arm64.zip",
        "05c153443b0b1175151c760eeddea538950bc9843e317d54786a1f03670182bc",
        322887047,
        932662106,
        127512832,
      ),
      winX64: (
        "windows-x86_64.zip",
        "54c2e16378d9a4952e1da70e355f3c33c4f284308d6de48ab3e6e34a127bd325",
        131267135,
        87022872,
        147843736,
      ),
      winArm: (
        "windows-arm64.zip",
        "fcd46431ad33d3b510ce0b98fe7b43d095bd8b3f1c363ee2d57faa7ee981c7bb",
        134301870,
        94238816,
        139322008,
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
