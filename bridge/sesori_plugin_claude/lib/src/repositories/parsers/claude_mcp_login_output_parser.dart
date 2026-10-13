import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

enum ClaudeMcpOAuthFailure() {
  accessDenied,
  invalidRequest,
  unauthorizedClient,
  unsupportedResponseType,
  invalidScope,
  serverError,
  temporarilyUnavailable,
  unknown,
}

final class const ClaudeMcpProviderCallbackException({
  required final ClaudeMcpOAuthFailure reason,
  required final String nativeError,
}) implements Exception {
  @override
  String toString() => "MCP provider returned ${reason.name}";
}

/// A native OAuth challenge. Its presentation never exposes authorization data.
final class const ClaudeMcpLoginChallenge({
  required final Uri authorizationUri,
  required final Uri callbackUri,
  required final String state,
}) {
  @override
  String toString() => "Claude MCP login challenge";

  Uri validateCallback({required String value}) {
    final uri = value.length > 16384 || value.contains("\n") || value.contains("\r") ? null : Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != callbackUri.scheme ||
        !uri.hasAuthority ||
        uri.origin != callbackUri.origin ||
        uri.path != callbackUri.path ||
        uri.queryParametersAll["state"]?.length != 1 ||
        (uri.queryParametersAll["code"]?.length ?? 0) > 1 ||
        (uri.queryParametersAll["error"]?.length ?? 0) > 1 ||
        uri.queryParameters["state"] != state ||
        (uri.queryParameters["code"]?.isNotEmpty != true && uri.queryParameters["error"]?.isNotEmpty != true) ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException("Callback does not match this MCP login");
    }
    return uri;
  }

  ClaudeMcpProviderCallbackException? providerFailure({required Uri callback}) {
    final error = callback.queryParameters["error"];
    if (error == null || error.isEmpty) return null;
    final reason = switch (error) {
      "access_denied" => ClaudeMcpOAuthFailure.accessDenied,
      "invalid_request" => ClaudeMcpOAuthFailure.invalidRequest,
      "unauthorized_client" => ClaudeMcpOAuthFailure.unauthorizedClient,
      "unsupported_response_type" => ClaudeMcpOAuthFailure.unsupportedResponseType,
      "invalid_scope" => ClaudeMcpOAuthFailure.invalidScope,
      "server_error" => ClaudeMcpOAuthFailure.serverError,
      "temporarily_unavailable" => ClaudeMcpOAuthFailure.temporarilyUnavailable,
      _ => ClaudeMcpOAuthFailure.unknown,
    };
    return ClaudeMcpProviderCallbackException(reason: reason, nativeError: error);
  }
}

final class const ClaudeMcpLoginOutputParser() {
  static final RegExp _url = RegExp(r"https?://[^\s\x1b\x07]+");

  bool requiresNativeTrust({required String line}) => stripAnsi(value: line).contains("awaiting approval");

  ClaudeMcpLoginChallenge? parseLine({required String line}) {
    for (final match in _url.allMatches(stripAnsi(value: line))) {
      final value = match.group(0)!;
      if (value.length > 16384) throw const FormatException("MCP login URL exceeds the supported length");
      final uri = Uri.tryParse(value);
      if (uri == null || !uri.queryParameters.containsKey("redirect_uri")) continue;
      final state = uri.queryParameters["state"];
      final callback = Uri.tryParse(uri.queryParameters["redirect_uri"]!);
      if (uri.host.isEmpty ||
          (uri.scheme == "http" && !const {"localhost", "127.0.0.1", "::1"}.contains(uri.host)) ||
          uri.userInfo.isNotEmpty ||
          uri.queryParametersAll["state"]?.length != 1 ||
          uri.queryParametersAll["redirect_uri"]?.length != 1 ||
          state == null ||
          state.isEmpty ||
          callback == null ||
          callback.scheme != "http" ||
          !const {"localhost", "127.0.0.1", "::1"}.contains(callback.host) ||
          callback.userInfo.isNotEmpty) {
        throw const FormatException("MCP login URL has an invalid native callback");
      }
      return ClaudeMcpLoginChallenge(authorizationUri: uri, callbackUri: callback, state: state);
    }
    return null;
  }
}
