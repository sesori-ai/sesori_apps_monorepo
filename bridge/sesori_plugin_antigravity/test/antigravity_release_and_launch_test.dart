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
        "e29b5bf3bfd8756db5d901690b43dc31e926ccd5",
        "1.5.2",
        "1.5.2",
      ),
    );
    final macArtifact = AntigravityRelease.artifactFor(target: macArm);
    expect(
      (macArtifact.archiveBytes, macArtifact.serverBytes, macArtifact.harnessBytes),
      (100309778, 179921328, 129208672),
    );
    expect(
      macArtifact.archiveUrl,
      "https://dl.google.com/agy-extensions/releases/macos/"
      "agy-acp-server-1.5.2-darwin-arm64.zip",
    );
    expect(macArtifact.archiveSha256, "123a16d5c40a8ac99e20f01a62b68dd860fd96b1c528dfb8eaa37ca8733d4845");
    expect(
      AntigravityRelease.macosArm64ServerSha256,
      "4cea3c96875a4bb66a1c136d972b5cfdc5f7c91579ff7b9cbfc158a4358270bc",
    );
    expect(
      AntigravityRelease.macosArm64HarnessSha256,
      "31ec5f444b8c849ddb14da1c0893a87dddab60f1d5e282b79db36dc41b2521ab",
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
        "92addb5580577b5356d35484d72d1a113d9c5312ad766bcb304983aa8e3fbb06",
        106351992,
        184312784,
        134350320,
      ),
      macArm: (
        "darwin-arm64.zip",
        "123a16d5c40a8ac99e20f01a62b68dd860fd96b1c528dfb8eaa37ca8733d4845",
        100309778,
        179921328,
        129208672,
      ),
      linuxX64: (
        "linux-x86_64.zip",
        "99dd8612450805011619d7b8447ce374c289e00549d8557f36790e1dd6256852",
        273964075,
        714384320,
        139194456,
      ),
      linuxArm: (
        "linux-arm64.zip",
        "e729e05ef54ef0763e48900032466b47fa7c9939cde257f93ba49410ab577acb",
        264270419,
        721649155,
        132598576,
      ),
      winX64: (
        "windows-x86_64.zip",
        "5cbadd4f4df698572473d8890fc26ec2dc1724501f06e3a963941daec2bd21d6",
        105407645,
        58368800,
        155357336,
      ),
      winArm: (
        "windows-arm64.zip",
        "8a4b2ea8df2ffefae33309348752e9119d21a6d36090c0eb48631c2e8f5781ab",
        108049351,
        65130848,
        146707096,
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
