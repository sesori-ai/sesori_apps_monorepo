import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:antigravity_plugin/src/services/antigravity_runtime_path_authority_calculator.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  const calculator = AntigravityRuntimePathAuthorityCalculator();
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

  test("requires both a missing PATH server candidate and verified filesystem absence", () {
    expect(
      calculator.provesServerAbsent(
        candidate: missingPathServer,
        serverPresence: HostExecutablePresence.absent,
      ),
      isTrue,
    );
    for (final presence in [HostExecutablePresence.present, HostExecutablePresence.unknown]) {
      expect(calculator.provesServerAbsent(candidate: missingPathServer, serverPresence: presence), isFalse);
    }
  });

  test("keeps every other pair result authoritative", () {
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
      expect(
        calculator.provesServerAbsent(
          candidate: candidate,
          serverPresence: HostExecutablePresence.absent,
        ),
        isFalse,
        reason: candidate.runtimeType.toString(),
      );
    }
  });
}
