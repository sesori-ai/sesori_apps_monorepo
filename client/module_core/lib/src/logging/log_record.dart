/// Ordered from most verbose to least verbose; [LogLevel.none] disables all messages.
enum LogLevel() {
  trace,
  debug,
  info,
  warning,
  error,
  none,
}

/// Diagnostic presentation prepared by the logging boundary, not by IO sinks.
class const LogRecord({
  required final LogLevel level,
  required final DateTime timestamp,
  required final String message,
  required final String? diagnosticError,
  required final StackTrace? stackTrace,
}) {
  String get formatted =>
      "${timestamp.toIso8601String()} [${level.name.toUpperCase()}] $message"
      "${diagnosticError == null ? '' : ': $diagnosticError'}"
      "${stackTrace == null ? '' : '\n${stackTrace.toString()}'}";
}
