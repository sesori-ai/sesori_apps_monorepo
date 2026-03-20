import "dart:io";

/// Log levels ordered from most to least verbose.
///
/// The [index] of each value determines filtering: messages with a level
/// below [Log.level] are silently discarded.
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

/// Lightweight global logger for the bridge and its plugins.
///
/// Set [Log.level] once at startup (defaults to [LogLevel.info]).
/// Messages below that level are silently discarded.
///
/// [Log.e] writes to stderr; all other levels write to stdout.
class Log {
  Log._();

  /// Current minimum log level. Defaults to [LogLevel.info].
  static LogLevel level = LogLevel.info;

  /// Log a verbose-level message (most detailed tracing).
  static void v(String message) => _write(LogLevel.verbose, message);

  /// Log a debug-level message.
  static void d(String message) => _write(LogLevel.debug, message);

  /// Log an info-level message.
  static void i(String message) => _write(LogLevel.info, message);

  /// Log a warning-level message.
  static void w(String message) => _write(LogLevel.warning, message);

  /// Log an error-level message. Always written to stderr.
  static void e(String message) => _write(LogLevel.error, message);

  static void _write(LogLevel msgLevel, String message) {
    if (msgLevel.index < level.index) return;
    if (msgLevel == LogLevel.error) {
      stderr.writeln(message);
    } else {
      stdout.writeln(message);
    }
  }
}
