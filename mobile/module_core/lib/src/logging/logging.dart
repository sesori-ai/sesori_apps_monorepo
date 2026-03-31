import "package:sesori_shared/sesori_shared.dart" show StringExtensions;

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

// ignore: no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void logt(String message, [Object? error, StackTrace? stackTrace]) {
  if (_logLevel.index <= LogLevel.trace.index) {
    _printWithDetails(message, error, stackTrace);
  }
}

// ignore: no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void logd(String message, [Object? error, StackTrace? stackTrace]) {
  if (_logLevel.index <= LogLevel.debug.index) {
    // ignore: avoid_print, logging intentionally writes to stdout in pure Dart modules
    message.chunked(800).forEach(print);
  }
}

// ignore: no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void logi(String message, [Object? error, StackTrace? stackTrace]) {
  if (_logLevel.index <= LogLevel.info.index) {
    _printWithDetails(message, error, stackTrace);
  }
}

// ignore: no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void logw(String message, [Object? error, StackTrace? stackTrace]) {
  if (_logLevel.index <= LogLevel.warning.index) {
    _printWithDetails(message, error, stackTrace);
  }
}

// ignore: no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void loge(String message, [Object? error, StackTrace? stackTrace]) {
  if (_logLevel.index <= LogLevel.error.index) {
    _printWithDetails(message, error, stackTrace);
  }
}

// ignore: no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
void logwf(String message, [Object? error, StackTrace? stackTrace]) {
  // fatal — always emitted unless suppressed to none
  if (_logLevel != LogLevel.none) {
    _printWithDetails(message, error, stackTrace);
  }
}

// ignore: no_slop_linter/prefer_required_named_parameters, private logging helper keeps optional positional context
void _printWithDetails(String message, Object? error, StackTrace? stackTrace) {
  if (error != null) {
    // ignore: avoid_print, logging intentionally writes to stdout in pure Dart modules
    print("$message: ${error.toString()}");
  } else {
    // ignore: avoid_print, logging intentionally writes to stdout in pure Dart modules
    message.chunked(800).forEach(print);
  }
  if (stackTrace != null) {
    // ignore: avoid_print, logging intentionally writes to stdout in pure Dart modules
    print(stackTrace.toString());
  }
}
