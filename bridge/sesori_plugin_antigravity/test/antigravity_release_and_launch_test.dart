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
        "655791de14720cb08eaa9753f39ec0095f04fa2c",
        "1.5.0",
        "1.5.0",
      ),
    );
    final macArtifact = AntigravityRelease.artifactFor(target: macArm);
    expect(
      (macArtifact.archiveBytes, macArtifact.serverBytes, macArtifact.harnessBytes),
      (100401185, 179756208, 129572384),
    );
    expect(
      macArtifact.archiveUrl,
      "https://dl.google.com/agy-extensions/releases/macos/"
      "agy-acp-server-1.5.0-darwin-arm64.zip",
    );
    expect(macArtifact.archiveSha256, "c82ecb4ef476bfc35cbe5b2745cdddef873b99c9f5bd7fd11e5ca1fc1667a3fc");
    expect(
      AntigravityRelease.macosArm64ServerSha256,
      "bbb138a7ff32982e231af325e3176b252174f4c59e4fee7159c0e364ad5f9613",
    );
    expect(
      AntigravityRelease.macosArm64HarnessSha256,
      "4eddc5c77a0bb275372fb548a9011a1acc70828a4a72412f2da0733c90db30fe",
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
        "86a94e33b25d4a38ff30526ad844546860aa9ed98698498d9e87d30eb794426e",
        106461356,
        184151792,
        134730544,
      ),
      macArm: (
        "darwin-arm64.zip",
        "c82ecb4ef476bfc35cbe5b2745cdddef873b99c9f5bd7fd11e5ca1fc1667a3fc",
        100401185,
        179756208,
        129572384,
      ),
      linuxX64: (
        "linux-x86_64.zip",
        "36f373e8948edf1727b39c7d62b5722d6a4474bdfd72b04ad3d6def571808c9f",
        274069093,
        714224576,
        139570072,
      ),
      linuxArm: (
        "linux-arm64.zip",
        "1e184f439477b54138e94440056b26a78c0a8075a8fd2ffda637ec31267c6459",
        264366319,
        721489411,
        132951888,
      ),
      winX64: (
        "windows-x86_64.zip",
        "6163f6b59b381bae419652dbae167bc8cda0ef29d665c0ba8af3d8c7fddd8867",
        105513364,
        58314376,
        155782808,
      ),
      winArm: (
        "windows-arm64.zip",
        "340092b8af6dafc71eb15f4a8ec54b4d1f0bce16d1fa4d163b562c50b905f8f4",
        108145235,
        65077040,
        147104920,
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
