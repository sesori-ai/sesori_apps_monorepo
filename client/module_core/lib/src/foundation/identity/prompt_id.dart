import "dart:math";

final Random _promptIdRandom = Random.secure();

/// Client-generated prompt identity, mirroring the bridge's `prm_` shape. It
/// survives retries of the same submission, so a send whose response was lost
/// re-lands on the bridge as an idempotent no-op.
String generatePromptId() {
  final buffer = StringBuffer("prm_");
  for (var index = 0; index < 16; index++) {
    buffer.write(_promptIdRandom.nextInt(256).toRadixString(16).padLeft(2, "0"));
  }
  return buffer.toString();
}
