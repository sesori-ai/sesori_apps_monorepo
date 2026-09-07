import "dart:convert";

/// Selective raw-line policy for the pinned agent's OAuth diagnostics. Shared
/// ACP supplies bounded, complete lines before any diagnostic logger sees them.
class const AntigravityStderrMapper() {
  static final _oauthUrl = RegExp(
    r"accounts\.google\.com|oauth2\.googleapis\.com|"
    r"https?://(?:127\.0\.0\.1|localhost|\[::1\])(?::\d+)?/\S*\?",
    caseSensitive: false,
  );
  static final _credentialField = RegExp(
    r'''\b(?:token|access_token|refresh_token|id_token|code_verifier|code_challenge|client_secret|authorization_response)'''
    r'''\b["'\s]*(?:=|:|%3d)|\b(?:state|code)\b["'\s]*(?:=|%3d)|["'](?:state|code)["']\s*:|'''
    r'''\bauthorization\s*["']?\s*[:=]|\bbearer\s+\S+''',
    caseSensitive: false,
  );

  bool consumeLine({required List<int> line}) {
    final text = utf8.decode(line, allowMalformed: true);
    return _oauthUrl.hasMatch(text) ||
        _credentialField.hasMatch(text) ||
        text.contains("Open the following link to authenticate the ACP server: ");
  }
}
