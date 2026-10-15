/// Native authorization data stays within the live operation, never diagnostics.
final class const CodexMcpLoginChallenge({
  required final Uri authorizationUri,
  required final Uri callbackUri,
  required final String state,
}) {
  factory parse({required String value}) {
    final authorization = value.length > 16384 ? null : Uri.tryParse(value);
    final callbackValue = authorization?.queryParameters["redirect_uri"];
    final callback = callbackValue == null ? null : Uri.tryParse(callbackValue);
    final state = authorization?.queryParameters["state"];
    if (authorization == null ||
        authorization.host.isEmpty ||
        (authorization.scheme != "https" && !(authorization.scheme == "http" && _loopback(uri: authorization))) ||
        authorization.userInfo.isNotEmpty ||
        authorization.hasFragment ||
        authorization.queryParametersAll["state"]?.length != 1 ||
        authorization.queryParametersAll["redirect_uri"]?.length != 1 ||
        state == null ||
        state.isEmpty ||
        callback == null ||
        callback.scheme != "http" ||
        !_loopback(uri: callback) ||
        callback.userInfo.isNotEmpty ||
        callback.hasFragment) {
      throw const FormatException("Codex MCP authorization has an invalid native callback");
    }
    return CodexMcpLoginChallenge(authorizationUri: authorization, callbackUri: callback, state: state);
  }

  void validateCallback({required Uri callback}) {
    final hasCode = callback.queryParameters["code"]?.isNotEmpty ?? false;
    final hasError = callback.queryParameters["error"]?.isNotEmpty ?? false;
    if (callback.toString().length > 16384 ||
        !callback.hasAuthority ||
        callback.userInfo.isNotEmpty ||
        callback.hasFragment ||
        callback.scheme != callbackUri.scheme ||
        callback.origin != callbackUri.origin ||
        callback.path != callbackUri.path ||
        callback.queryParametersAll["state"]?.length != 1 ||
        callback.queryParameters["state"] != state ||
        (callback.queryParametersAll["code"]?.length ?? 0) > 1 ||
        (callback.queryParametersAll["error"]?.length ?? 0) > 1 ||
        hasCode == hasError) {
      throw const FormatException("Callback does not match this Codex MCP login");
    }
  }

  @override
  String toString() => "Codex MCP login challenge";
}

bool _loopback({required Uri uri}) => const {"localhost", "127.0.0.1", "::1"}.contains(uri.host);
