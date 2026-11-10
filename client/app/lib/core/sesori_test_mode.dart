import "package:flutter/foundation.dart" show kReleaseMode;

/// Whether this build runs automated simulator checks, set with
/// `--dart-define=SESORI_TEST_MODE=true`.
///
/// It turns off what blocks an unattended driver: both native notification
/// permission prompts, the founder call sheet and the rating prompt, and starts
/// the composer in typing mode. A release build always ignores it; any debug or
/// profile build honors it, including one on a physical device, so pass it only
/// for unattended simulator runs.
const sesoriTestMode = !kReleaseMode && bool.fromEnvironment("SESORI_TEST_MODE");
