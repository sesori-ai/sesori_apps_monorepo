import '../logging/logging.dart';

void recordNonFatalError({
  required Object err,
  required String context,
  Map<String, dynamic>? extraData,
}) {
  loge("Non-fatal error: $err", err, StackTrace.current);
}
