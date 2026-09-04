import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Test seam for the desktop application's log-backed failure reporter.
@visibleForTesting
typedef DesktopFailureLogSink = void Function({
  required String message,
  required Object? error,
  required StackTrace? stackTrace,
});

/// Keeps shared handled failures observable on desktop without forwarding
/// payload-bearing context to a remote crash service.
///
/// The shared module supplies [FailureReporter] to recoverable event handlers.
/// Mobile binds that seam to Crashlytics, but the desktop shell intentionally
/// has no remote crash-reporting dependency yet. This implementation preserves
/// the useful error, stack, operation identifier, and event-type context in the
/// local application log while reducing [information] to type/shape metadata.
@LazySingleton(as: FailureReporter)
class DesktopFailureReporter.forTesting({required final DesktopFailureLogSink _logSink}) implements FailureReporter {
  new()
    : this.forTesting(
        logSink: ({required String message, required Object? error, required StackTrace? stackTrace}) =>
            loge(message, error, stackTrace),
      );

  @override
  void setGlobalKey({required String key, required Object value}) {
    _logSink(
      message:
          "Failure reporter context updated: key=${_sanitizeContext(key)} valueType=${value.runtimeType.toString()}",
      error: null,
      stackTrace: null,
    );
  }

  @override
  void log({required String message}) {
    _logSink(
      message: "Failure reporter log: ${_sanitizeContext(message)}",
      error: null,
      stackTrace: null,
    );
  }

  @override
  Future<void> recordFailure({
    required Object error,
    required StackTrace stackTrace,
    required String uniqueIdentifier,
    required bool fatal,
    required String? reason,
    required Iterable<Object> information,
  }) async {
    final String informationShape = information.map(_describeInformation).join(", ");
    _logSink(
      message:
          "Handled failure: identifier=${_sanitizeContext(uniqueIdentifier)} "
          "fatal=$fatal reason=${reason == null ? "<none>" : _sanitizeContext(reason)} "
          "information=[$informationShape]",
      error: error,
      stackTrace: stackTrace,
    );
  }

  // ignore: no_slop_linter/prefer_specific_type, FailureReporter information is intentionally opaque at this boundary.
  static String _describeInformation(Object value) {
    if (value is String) {
      return "String(length=${value.length})";
    }
    return value.runtimeType.toString();
  }

  /// Keeps operation/event labels readable while preventing arbitrary values
  /// from becoming multiline or unbounded log records.
  static String _sanitizeContext(String value) {
    final String normalized = value.replaceAll(RegExp(r"\s+"), " ").trim();
    final String safe = normalized.replaceAll(RegExp("[^A-Za-z0-9_.:/=-]"), "_");
    if (safe.length <= 160) return safe;
    return "${safe.substring(0, 160)}…";
  }
}
