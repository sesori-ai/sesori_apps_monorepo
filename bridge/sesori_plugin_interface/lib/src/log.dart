import "dart:io";

import "ansi_color.dart";

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

/// Lightweight global diagnostic logger for the bridge and its plugins.
///
/// Set [Log.level] once at startup (defaults to [LogLevel.info]); messages
/// below that level are silently discarded. All levels write to stderr, so the
/// log stream can be redirected or silenced (`--log-level error`, `2>/dev/null`)
/// without affecting user-facing output. For messages the user must see to
/// operate the bridge — prompts, requests, essential status — use [Console]
/// instead; it always writes to stdout regardless of [Log.level].
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

  /// Log an error-level message.
  static void e(String message, [Object? error, StackTrace? st]) => _write(LogLevel.error, message, error, st);

  static void _write(
    final LogLevel msgLevel,
    final String rawMessage,
    final Object? error,
    final StackTrace? st,
  ) {
    if (msgLevel.index < level.index) return;

    final buffer = StringBuffer();
    // The [CallerClass] tag is debugging noise at normal verbosity. Only show it
    // when the configured level is debug/verbose, where the extra context helps.
    if (level.index <= LogLevel.debug.index) {
      final callerClass = _getCallerClassName();
      buffer.write("[$callerClass]");
      if (!rawMessage.startsWith("[")) {
        buffer.write(" ");
      }
    }
    buffer.write(rawMessage);
    if (error != null && level.index < LogLevel.info.index) {
      buffer.write("\n -- Error on next line(s)");
      buffer.write(error.toString());
    }
    if (st != null && level.index < LogLevel.info.index) {
      buffer.write(st.toString());
    }

    // All diagnostic logs go to stderr so the log stream stays separate from
    // user-facing output (which [Console] writes to stdout) and can be
    // silenced without making the bridge unoperable.
    stderr.writeln(_colorizeForLevel(msgLevel, buffer.toString()));
  }

  /// Highlights warning lines in yellow and error lines in red when stderr is an
  /// interactive terminal; other levels are written without color.
  static String _colorizeForLevel(LogLevel msgLevel, String text) {
    switch (msgLevel) {
      case LogLevel.warning:
        return AnsiColorFormatter.colorize(text: text, color: AnsiColor.yellow, out: stderr);
      case LogLevel.error:
        return AnsiColorFormatter.colorize(text: text, color: AnsiColor.red, out: stderr);
      case LogLevel.verbose:
      case LogLevel.debug:
      case LogLevel.info:
        return text;
    }
  }

  static String _getCallerClassName() {
    // Stack frames from this method up to the original caller:
    //   #0 Log._getCallerClassName
    //   #1 Log._write
    //   #2 Log.<v|d|i|w|e>      (the public entry point)
    //   #3 <caller>             (the class we want to name)
    const callerLineIndex = 3;
    final trace = StackTrace.current.toString().split('\n');

    if (trace.length < callerLineIndex + 1) {
      return "Unknown0";
    }

    // Example frame:
    // #3      OrchestratorSession.run (package:sesori_bridge/src/bridge/orchestrator.dart:369:13)
    final line = trace[callerLineIndex];

    final match = RegExp(r'#\d+\s+(.+?)\.').firstMatch(line);

    if (match != null) {
      return match.group(1) ?? "Unknown1";
    }

    return 'Unknown';
  }
}
