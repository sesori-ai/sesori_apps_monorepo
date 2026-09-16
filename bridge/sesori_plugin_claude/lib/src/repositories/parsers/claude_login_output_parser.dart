import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

/// What one stdout line of `claude auth login` says about the sign-in URL.
sealed class const ClaudeLoginOutput();

/// The line has no HTTPS token.
final class const ClaudeLoginOutputNone() extends ClaudeLoginOutput;

final class const ClaudeLoginOutputUrl({required final Uri authorizationUri}) extends ClaudeLoginOutput;

/// The line has an HTTPS token that is too long or has no parsable host. Only
/// its length is kept, so logs never carry the token.
final class const ClaudeLoginOutputInvalidUrl({required final int length}) extends ClaudeLoginOutput;

/// Finds the sign-in URL in `claude auth login` output.
///
/// The CLI wraps the URL in an OSC 8 terminal hyperlink, so escape sequences
/// are removed before the first HTTPS token is read. Prose is ignored, so
/// wording changes across CLI versions do not matter.
final class const ClaudeLoginOutputParser() {
  static const int maxUrlLength = 16384;

  static final RegExp _httpsToken = RegExp(r"https://\S+");

  ClaudeLoginOutput parseLine({required String line}) {
    final token = _httpsToken.firstMatch(stripAnsi(value: line))?.group(0);
    if (token == null) return const ClaudeLoginOutputNone();
    final uri = token.length > maxUrlLength ? null : Uri.tryParse(token);
    if (uri == null || uri.host.isEmpty) {
      return ClaudeLoginOutputInvalidUrl(length: token.length);
    }
    return ClaudeLoginOutputUrl(authorizationUri: uri);
  }

  /// [line] without escape sequences or HTTPS tokens, for local logs.
  String redactLine({required String line}) => stripAnsi(value: line).replaceAll(_httpsToken, "<url>");
}
