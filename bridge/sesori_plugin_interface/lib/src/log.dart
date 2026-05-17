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
  static void v(String message) => _write(LogLevel.verbose, message, null, null);

  /// Log a debug-level message.
  static void d(String message) => _write(LogLevel.debug, message, null, null);

  /// Log an info-level message.
  static void i(String message) => _write(LogLevel.info, message, null, null);

  /// Log a warning-level message.
  static void w(String message, [Object? error, StackTrace? st]) => _write(LogLevel.warning, message, error, st);

  /// Log an error-level message. Always written to stderr.
  static void e(String message, [Object? error, StackTrace? st]) => _write(LogLevel.error, message, error, st);

  static void _write(
    final LogLevel msgLevel,
    final String rawMessage,
    final Object? error,
    final StackTrace? st,
  ) {
    if (msgLevel.index < level.index) return;

    final String message = msgLevel == .info
        ? rawMessage
        : () {
            final callerClass = _getCallerClassName();

            final buffer = StringBuffer();
            buffer.write("[$callerClass]");
            if (!rawMessage.startsWith("[")) {
              buffer.write(" ");
            }
            buffer.write(rawMessage);
            if (error != null && level.index < LogLevel.info.index) {
              buffer.write("\n -- Error on next line(s)");
              buffer.write(error.toString());
            }
            if (st != null && level.index < LogLevel.info.index) {
              buffer.write(st.toString());
            }

            return buffer.toString();
          }();

    if (msgLevel == LogLevel.error) {
      stderr.writeln(message);
    } else {
      stdout.writeln(message);
    }
  }

  static String _getCallerClassName() {
    final trace = StackTrace.current.toString().split('\n');

    // Example trace:
    // ...
    // #3      Log.d (package:sesori_plugin_interface/src/log.dart:31:36)
    // #4      OrchestratorSession.run (package:sesori_bridge/src/bridge/orchestrator.dart:369:13)
    final line = trace[4];

    final match = RegExp(r'#\d+\s+(.+?)\.').firstMatch(line);

    if (match != null) {
      return match.group(1) ?? "UnknownGroup";
    }

    return 'Unknown';
  }
}
