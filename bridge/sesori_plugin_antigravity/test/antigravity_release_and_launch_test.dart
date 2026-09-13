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
        "d30bc9a7c011b522e8502281d5fbcfca51abd5ff",
        "1.1.1",
        "agy_acp_server_1.1.1",
      ),
    );
    final macArtifact = AntigravityRelease.artifactFor(target: macArm)!;
    expect(
      (macArtifact.archiveBytes, macArtifact.serverBytes, macArtifact.harnessBytes),
      (316014828, 802163856, 116766704),
    );
    expect(
      macArtifact.archiveUrl,
      "https://dl.google.com/agy-extensions/releases/macos/"
      "agy-acp-server-agy_acp_server_1.1.1-darwin-arm64.zip",
    );
    expect(macArtifact.archiveSha256, "fdfa915652cdb7ba8085cc8fffed072cbe009251aa2c951aabdda07a8c28a189");
    expect(
      AntigravityRelease.macosArm64ServerSha256,
      "9d900b93031fc42397f88206e14eba4193729bbef631a70b18e7a19631a6dfac",
    );
    expect(
      AntigravityRelease.macosArm64HarnessSha256,
      "e0a8ef9d80a1ffb178f945159dda33f73d4a5be65516642542352584b834fa2a",
    );
    expect(
      AntigravityRelease.advertisedAuthenticationMethodIds,
      {"oauth-personal", "oauth-business", "gemini-api-key", "agent-platform"},
    );
  });

  test("maps every independently verified archive and rejects macOS x64", () {
    final expected = <PlatformTarget, (String, String, int, int, int)>{
      macArm: (
        "darwin-arm64.zip",
        "fdfa915652cdb7ba8085cc8fffed072cbe009251aa2c951aabdda07a8c28a189",
        316014828,
        802163856,
        116766704,
      ),
      linuxX64: (
        "linux-x86_64.zip",
        "38f62d01b32deb0907b3d39a71ec301fd36369f6ffd1cf262d4af385177f79df",
        681969407,
        1880360328,
        128966920,
      ),
      linuxArm: (
        "linux-arm64.zip",
        "ed69e64b308fcb123ab54bf3277bf9cb0d651064f885ea5aab0ff520c7175398",
        656572786,
        1862073131,
        122158704,
      ),
      winX64: (
        "windows-x86_64.zip",
        "47cb50eef14f0a4655d78cfcfda869bcea7aaee5f9787e936bc2935ea612c3b8",
        468238392,
        430801616,
        130971800,
      ),
      winArm: (
        "windows-arm64.zip",
        "35f4b1f47ba6a3fea7b0a3e30010df5ea73a64b4f0e7cf991cddc673ddfbcafc",
        468521191,
        435075816,
        122455704,
      ),
    };
    for (final entry in expected.entries) {
      final target = entry.key;
      final facts = entry.value;
      final artifact = AntigravityRelease.artifactFor(target: target)!;
      expect(artifact.archiveUrl, endsWith(facts.$1));
      expect(
        (artifact.archiveSha256, artifact.archiveBytes, artifact.serverBytes, artifact.harnessBytes),
        (facts.$2, facts.$3, facts.$4, facts.$5),
      );
      expect(AntigravityRelease.supportsTarget(target: target), isTrue);
    }
    expect(AntigravityRelease.artifactFor(target: macX64), isNull);
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
