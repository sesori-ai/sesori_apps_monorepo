import "package:flutter/foundation.dart" show kReleaseMode;

/// Whether this build runs automated simulator checks, set with
/// `--dart-define=SESORI_TEST_MODE=true`.
///
/// It turns off what blocks an unattended driver: the native notification
/// permission prompt, the founder call sheet and the rating prompt, and starts
/// the composer in typing mode. A release build always ignores it.
const sesoriTestMode = !kReleaseMode && bool.fromEnvironment("SESORI_TEST_MODE");
