import "log_record.dart";
import "log_sink.dart";
import "stdout_log_sink.dart";

export "log_record.dart";
export "log_sink.dart";
export "stdout_log_sink.dart";

/// Per-isolate defaults: debug in development, info in release builds.
LogLevel _logLevel = const bool.fromEnvironment("dart.vm.product") ? LogLevel.info : LogLevel.debug;
LogSink _logSink = const StdoutLogSink();

LogLevel get logLevel => _logLevel;

/// Configure each isolate independently when it needs another verbosity.
void setLogLevel(LogLevel level) => _logLevel = level;

/// Installs output for this isolate only; existing level filtering still applies.
void setLogSink({required LogSink sink}) => _logSink = sink;

/// Best-effort completion before orderly termination, never an unbounded wait.
Future<void> flushLogs({required Duration timeout}) async {
  try {
    await _logSink.flush().timeout(timeout);
  } on Object catch (error, stackTrace) {
    // Bypass the sink that failed or timed out; do not recursively enqueue a log.
    const StdoutLogSink().write(
      record: LogRecord(
        level: LogLevel.warning,
        timestamp: DateTime.now().toUtc(),
        message: "Log sink flush failed; pending diagnostics may be lost",
        diagnosticError: error.toString(),
        stackTrace: stackTrace,
      ),
    );
  }
}

// ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void logt(String message, [Object? error, StackTrace? stackTrace]) =>
    _write(level: LogLevel.trace, message: message, error: error, stackTrace: stackTrace);

// ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void logd(String message, [Object? error, StackTrace? stackTrace]) =>
    _write(level: LogLevel.debug, message: message, error: error, stackTrace: stackTrace);

// ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void logi(String message, [Object? error, StackTrace? stackTrace]) =>
    _write(level: LogLevel.info, message: message, error: error, stackTrace: stackTrace);

// ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void logw(String message, [Object? error, StackTrace? stackTrace]) =>
    _write(level: LogLevel.warning, message: message, error: error, stackTrace: stackTrace);

// ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void loge(String message, [Object? error, StackTrace? stackTrace]) =>
    _write(level: LogLevel.error, message: message, error: error, stackTrace: stackTrace);

void _write({
  required LogLevel level,
  required String message,
  // ignore: no_slop_linter/prefer_specific_type, original diagnostic errors are converted at the logging boundary
  required Object? error,
  required StackTrace? stackTrace,
}) {
  if (_logLevel.index > level.index) return;
  final record = LogRecord(
    level: level,
    timestamp: DateTime.now().toUtc(),
    message: message,
    diagnosticError: error?.toString(),
    stackTrace: stackTrace,
  );
  try {
    _logSink.write(record: record);
  } on Object catch (sinkError, sinkStack) {
    const fallback = StdoutLogSink();
    fallback.write(record: record);
    fallback.write(
      record: LogRecord(
        level: LogLevel.warning,
        timestamp: DateTime.now().toUtc(),
        message: "Log sink failed; using console output",
        diagnosticError: sinkError.toString(),
        stackTrace: sinkStack,
      ),
    );
  }
}
