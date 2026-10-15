import "package:collection/collection.dart";

/// Authorization data lives only in this operation, never in presentation logs.
final class const OpenCodeMcpLoginChallenge({
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
      throw const FormatException("OpenCode MCP authorization has an invalid native callback");
    }
    return OpenCodeMcpLoginChallenge(authorizationUri: authorization, callbackUri: callback, state: state);
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
        (callback.queryParameters.containsKey("code") && callback.queryParameters.containsKey("error")) ||
        hasCode == hasError ||
        callbackUri.queryParametersAll.entries.any(
          (entry) => !const ListEquality<String>().equals(callback.queryParametersAll[entry.key], entry.value),
        )) {
      throw const FormatException("Callback does not match this OpenCode MCP login");
    }
  }

  @override
  String toString() => "OpenCode MCP login challenge";
}

bool _loopback({required Uri uri}) => const {"localhost", "127.0.0.1", "::1"}.contains(uri.host);

/// Retain native diagnostic context without recording OAuth query secrets.
String redactMcpOAuthQuerySecrets({required String message}) => message.replaceAllMapped(
  RegExp(r'''([?&](?:code|state|access_token|refresh_token|client_secret)=)[^&#\s"']*''', caseSensitive: false),
  (match) => "${match[1]}[redacted]",
);
