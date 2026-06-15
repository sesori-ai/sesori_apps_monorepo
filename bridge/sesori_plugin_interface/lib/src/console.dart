import "dart:io";

/// User-facing console output for the bridge and its plugins.
///
/// Distinct from [Log]: [Console] messages are shown to the user regardless of
/// the configured log level, because the bridge must remain operable even when
/// logging is silenced (e.g. `--log-level error`, or redirecting stderr with
/// `2>/dev/null`). Use it for prompts, requests, and status the user must see
/// to operate the bridge — never for diagnostics, which belong in [Log].
///
/// Routine output goes to stdout; [Console.error] goes to stderr.
class Console {
  Console._();

  /// Writes a user-facing message to stdout, followed by a newline.
  static void message(String text) => stdout.writeln(text);

  /// Writes a user-facing error to stderr, followed by a newline.
  static void error(String text) => stderr.writeln(text);
}
