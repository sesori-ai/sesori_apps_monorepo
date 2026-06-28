import "dart:async";
import "dart:convert";

/// Layer-1 data access that reads the per-spawn control-channel secret from an
/// inherited input stream (the supervised child's stdin pipe).
///
/// The secret is delivered off-argv (ADR A8): argv is world-readable on common
/// platforms and this secret authenticates the control channel that issues
/// bearer tokens, so it must never appear on the command line. The GUI writes
/// `<secret>\n` to the child's stdin at spawn; this reads the first line.
class ControlSecretApi {
  final Stream<List<int>> _input;

  ControlSecretApi({required Stream<List<int>> input}) : _input = input;

  /// Reads and returns the trimmed secret (the first line of the input stream).
  ///
  /// Throws [TimeoutException] if no line arrives within [timeout], or
  /// [StateError] if the stream ends with no line or the line is blank.
  Future<String> readSecret({Duration timeout = const Duration(seconds: 10)}) async {
    final firstLine = await _input
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(timeout);
    final secret = firstLine.trim();
    if (secret.isEmpty) {
      throw StateError("Control-channel secret was empty");
    }
    return secret;
  }
}
