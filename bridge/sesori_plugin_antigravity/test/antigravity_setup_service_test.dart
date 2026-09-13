import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:antigravity_plugin/src/models/antigravity_runtime_version.dart";
import "package:antigravity_plugin/src/repositories/antigravity_runtime_version_repository.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class const _FoundRuntime() implements AntigravityRuntimeService {
  @override
  AntigravityRuntimeCandidateResult inspect({
    required String? explicitServerPath,
    required String? managedServerPath,
    required Map<String, String> pathEnvironment,
    required PlatformTarget target,
  }) => AntigravityRuntimeCandidateFound(
    source: AntigravityRuntimeSource.path,
    pair: AntigravityRuntimePair(
      serverPath: "/runtime/agy_acp_server.par",
      harnessPath: "/runtime/localharness_external",
      target: target,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _CurrentVersion() implements AntigravityRuntimeVersionRepository {
  @override
  Future<AntigravityRuntimeVersionProbeResult> probe({
    required AntigravityRuntimeSource source,
    required String serverPath,
    required Map<String, String> environment,
    required Duration timeout,
  }) async {
    final version = AntigravityRuntimeVersion.tryParse(buildLabel: AntigravityRelease.agentVersion);
    if (version == null) throw StateError("invalid test version");
    return AntigravityRuntimeVersionProbeSucceeded(source: source, version: version);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _ThrowingProfile() implements AntigravityProfileInspectionService {
  @override
  AntigravityAuthenticationHint inspect({required String geminiHome}) => throw StateError("profile unavailable");

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test("retains a verified runtime version when profile inspection fails", () async {
    final setup =
        await AntigravitySetupService(
          runtime: const _FoundRuntime(),
          runtimeVersions: const _CurrentVersion(),
          profile: const _ThrowingProfile(),
        ).inspect(
          explicitServerPath: null,
          managedServerPath: null,
          pathEnvironment: const {},
          probeEnvironment: const {},
          target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
          geminiHome: "/profile",
          managedInstallAvailable: false,
          timeout: const Duration(seconds: 1),
        );

    expect(setup, isA<PluginSetupUnknown>());
    expect(setup.runtimeVersion, AntigravityRelease.agentVersion);
  });
}
