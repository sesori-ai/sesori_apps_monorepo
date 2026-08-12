import '../api/update_log_api.dart';

/// Layer 2 wrapper over [UpdateLogApi]. Delegates durable, redacted logging of
/// the update pipeline and exposes the log path for user-facing failure
/// guidance.
class UpdateLogRepository({required final UpdateLogApi _api}) {
  /// Absolute path of the durable update log, surfaced in failure messages.
  String get logPath => _api.logPath;

  Future<void> logAttemptHeader({required String fromVersion, required String toVersion}) {
    return _api.appendAttemptHeader(fromVersion: fromVersion, toVersion: toVersion);
  }

  Future<void> log({required String message}) => _api.append(message: message);
}
