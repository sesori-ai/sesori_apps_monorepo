import "../extensions/sugar_dart.dart";

/// Controls which log messages are emitted.
///
/// Ordered from most-verbose to least-verbose. A message is printed when its
/// level is ≥ the current [logLevel].
///
/// **Isolate note**: Dart isolates have separate memory spaces, so changing
/// [logLevel] in one isolate does not affect others. Call [setLogLevel] at the
/// entry point of any spawned isolate that needs a non-default level.
enum LogLevel { trace, debug, info, warning, error, none }

/// The active log level for this isolate.
///
/// Defaults to [LogLevel.debug] in debug builds and [LogLevel.warning] in
/// release builds. Override at startup (or per-isolate) via [setLogLevel].
LogLevel _logLevel = const bool.fromEnvironment("dart.vm.product") ? LogLevel.info : LogLevel.debug;

/// Returns the current log level for this isolate.
LogLevel get logLevel => _logLevel;

/// Sets the log level for this isolate.
///
/// Messages below [level] will be suppressed. Call this from the entry point
/// of each isolate independently if you need non-default verbosity.
void setLogLevel(LogLevel level) => _logLevel = level;

void logt(String message, [Object? error, StackTrace? stackTrace]) {
  if (_logLevel.index <= LogLevel.trace.index) {
    _printWithDetails(message, error, stackTrace);
  }
}

void logd(String message, [Object? error, StackTrace? stackTrace]) {
  if (_logLevel.index <= LogLevel.debug.index) {
    // ignore: avoid_print
    message.chunked(800).forEach(print);
  }
}

void logi(String message, [Object? error, StackTrace? stackTrace]) {
  if (_logLevel.index <= LogLevel.info.index) {
    _printWithDetails(message, error, stackTrace);
  }
}

void logw(String message, [Object? error, StackTrace? stackTrace]) {
  if (_logLevel.index <= LogLevel.warning.index) {
    _printWithDetails(message, error, stackTrace);
  }
}

void loge(String message, [Object? error, StackTrace? stackTrace]) {
  if (_logLevel.index <= LogLevel.error.index) {
    _printWithDetails(message, error, stackTrace);
  }
}

void logwf(String message, [Object? error, StackTrace? stackTrace]) {
  // fatal — always emitted unless suppressed to none
  if (_logLevel != LogLevel.none) {
    _printWithDetails(message, error, stackTrace);
  }
}

void _printWithDetails(String message, Object? error, StackTrace? stackTrace) {
  if (error != null) {
    // ignore: avoid_print
    print("$message: $error");
  } else {
    // ignore: avoid_print
    message.chunked(800).forEach(print);
  }
  if (stackTrace != null) {
    // ignore: avoid_print
    print(stackTrace.toString());
  }
}
