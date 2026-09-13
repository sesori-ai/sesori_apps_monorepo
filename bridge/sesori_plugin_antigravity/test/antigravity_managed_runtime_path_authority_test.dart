import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:antigravity_plugin/src/services/antigravity_managed_runtime_path_authority.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show StartAbortSignal;
import "package:test/test.dart";

class _RuntimeRepository({
  required final AntigravityRuntimeCandidateResult candidate,
  required final AntigravityPathServerPresence serverPresence,
}) implements AntigravityRuntimeRepository {
  int presenceInspections = 0;
  @override
  AntigravityRuntimeCandidateResult inspectPath({
    required Map<String, String> environment,
    required PlatformTarget target,
  }) => candidate;

  @override
  AntigravityRuntimeCandidateResult inspectPair({
    required AntigravityRuntimeSource source,
    required String serverPath,
    required PlatformTarget target,
  }) => throw UnsupportedError("unused");

  @override
  AntigravityPathServerPresence inspectPathServerPresence({
    required Map<String, String> environment,
    required PlatformTarget target,
  }) {
    presenceInspections++;
    return serverPresence;
  }

  @override
  Future<AntigravityRuntimeProbeResult> probe({
    required AntigravityRuntimeSource source,
    required AntigravityRuntimePair pair,
    required Map<String, String> environment,
    required String? workingDirectory,
    required Duration timeout,
    required StartAbortSignal abortSignal,
  }) => throw UnsupportedError("unused");
}

void main() {
  const target = PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64);
  const pair = AntigravityRuntimePair(
    serverPath: "/runtime/agy_acp_server.par",
    harnessPath: "/runtime/localharness_external",
    target: target,
  );
  const missingPathServer = AntigravityRuntimeCandidateMissing(
    source: AntigravityRuntimeSource.path,
    component: AntigravityRuntimeComponent.server,
  );

  Future<({bool absent, int scans})> inspect({
    required AntigravityRuntimeCandidateResult candidate,
    required AntigravityPathServerPresence serverPresence,
  }) async {
    final repository = _RuntimeRepository(candidate: candidate, serverPresence: serverPresence);
    final authority = AntigravityManagedRuntimePathAuthority(
      runtimeRepository: repository,
      pathAuthorityCalculator: const AntigravityRuntimePathAuthorityCalculator(),
      target: target,
    );
    final absent = await authority.isPathAbsent(environment: const {}, abortSignal: StartAbortSignal.never);
    return (absent: absent, scans: repository.presenceInspections);
  }

  test("requires both a missing PATH server candidate and verified filesystem absence", () async {
    for (final presence in AntigravityPathServerPresence.values) {
      final result = await inspect(candidate: missingPathServer, serverPresence: presence);
      expect(result.absent, presence == AntigravityPathServerPresence.absent);
      expect(result.scans, 1);
    }
  });

  test("keeps every other pair result authoritative without a duplicate PATH scan", () async {
    final candidates = <AntigravityRuntimeCandidateResult>[
      const AntigravityRuntimeCandidateFound(source: AntigravityRuntimeSource.path, pair: pair),
      const AntigravityRuntimeCandidateMissing(
        source: AntigravityRuntimeSource.path,
        component: AntigravityRuntimeComponent.harness,
      ),
      const AntigravityRuntimeCandidateMissing(
        source: AntigravityRuntimeSource.explicit,
        component: AntigravityRuntimeComponent.server,
      ),
      const AntigravityRuntimeCandidateRejected(
        source: AntigravityRuntimeSource.path,
        component: AntigravityRuntimeComponent.server,
        issue: AntigravityRuntimePairIssue.notAFile,
      ),
      AntigravityRuntimeCandidateStorageFailed(
        source: AntigravityRuntimeSource.path,
        cause: StateError("unreadable PATH entry"),
        stackTrace: StackTrace.empty,
      ),
      const AntigravityRuntimeCandidateUnsupported(target: target),
    ];

    for (final candidate in candidates) {
      final result = await inspect(candidate: candidate, serverPresence: AntigravityPathServerPresence.absent);
      expect(result.absent, isFalse, reason: candidate.runtimeType.toString());
      expect(result.scans, 0, reason: candidate.runtimeType.toString());
    }
  });
}
