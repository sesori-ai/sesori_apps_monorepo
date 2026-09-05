import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

/// One official ACP server and its mandatory sibling harness.
final class const AntigravityRuntimePair({
  required final String serverPath,
  required final String harnessPath,
  required final PlatformTarget target,
});

enum AntigravityRuntimeComponent() {
  server,
  harness,
}

enum AntigravityRuntimePairInvalidReason() {
  wrongName,
  notAFile,
  notSiblings,
  notDistinct,
}

/// Layer-1 result of reading an official runtime pair from local storage.
sealed class const AntigravityRuntimePairReadResult();

final class const AntigravityRuntimePairFound({required final AntigravityRuntimePair pair})
    extends AntigravityRuntimePairReadResult;

final class const AntigravityRuntimePairMissing({required final AntigravityRuntimeComponent component})
    extends AntigravityRuntimePairReadResult;

final class const AntigravityRuntimePairInvalid({
  required final AntigravityRuntimeComponent component,
  required final AntigravityRuntimePairInvalidReason reason,
}) extends AntigravityRuntimePairReadResult;

final class const AntigravityRuntimeTargetUnsupported({required final PlatformTarget target})
    extends AntigravityRuntimePairReadResult;

final class const AntigravityRuntimeStorageFailure({
  // ignore: no_slop_linter/prefer_specific_type, caught storage failures remain opaque
  required final Object cause,
  required final StackTrace stackTrace,
}) extends AntigravityRuntimePairReadResult;
