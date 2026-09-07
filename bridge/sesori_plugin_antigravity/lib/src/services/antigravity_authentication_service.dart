import "../foundation/antigravity_authentication_budget.dart";
import "../models/antigravity_authentication.dart";
import "../models/antigravity_runtime_pair.dart";
import "../repositories/antigravity_authentication_repository.dart";

/// Provider security policy. Operation identity, one-shot dispatch and challenge
/// lifetime belong to the composing operation, not to this per-attempt service.
class AntigravityAuthenticationService({required final AntigravityAuthenticationRepository _repository}) {
  Stream<AntigravityAuthorization> get authorizations =>
      _repository.authorizations.map((uri) => validateAuthorization(authorizationUri: uri));

  Future<void> authenticate({
    required AntigravityRuntimePair pair,
    required Map<String, String> environment,
    required AntigravityAuthenticationBudget budget,
  }) => _repository.authenticate(pair: pair, environment: environment, budget: budget);

  AntigravityAuthorization validateAuthorization({required Uri authorizationUri}) {
    try {
      final query = authorizationUri.queryParametersAll;
      final state = _single(values: query["state"]);
      final redirect = _single(values: query["redirect_uri"]);
      if (authorizationUri.toString().length > 16384 ||
          authorizationUri.scheme != "https" ||
          authorizationUri.host != "accounts.google.com" ||
          authorizationUri.port != 443 ||
          authorizationUri.path != "/o/oauth2/v2/auth" ||
          authorizationUri.userInfo.isNotEmpty ||
          authorizationUri.hasFragment ||
          _single(values: query["response_type"]) != "code" ||
          state == null ||
          state.isEmpty ||
          state.length > 512 ||
          RegExp(r"\s").hasMatch(state) ||
          redirect == null ||
          !RegExp(r"^http://127\.0\.0\.1:[1-9][0-9]{0,4}/$").hasMatch(redirect)) {
        throw const AntigravityAuthenticationException(message: "Invalid Google authorization challenge", cause: null);
      }
      final callback = Uri.parse(redirect);
      if (callback.port < 1024 || callback.port > 65535) {
        throw const AntigravityAuthenticationException(message: "Invalid callback port", cause: null);
      }
      return AntigravityAuthorization(authorizationUri: authorizationUri, callbackUri: callback, state: state);
    } on AntigravityAuthenticationException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AntigravityAuthenticationException(message: "Invalid Google authorization challenge", cause: error),
        stackTrace,
      );
    }
  }

  Future<void> submitRedirect({
    required AntigravityAuthorization authorization,
    required Uri redirectUri,
    required AntigravityAuthenticationBudget budget,
  }) async {
    budget.remaining;
    try {
      final query = redirectUri.queryParametersAll;
      final code = _single(values: query["code"]);
      final issuers = query["iss"];
      if (redirectUri.toString().length > 4096 ||
          redirectUri.scheme != authorization.callbackUri.scheme ||
          redirectUri.host != authorization.callbackUri.host ||
          redirectUri.port != authorization.callbackUri.port ||
          redirectUri.path != authorization.callbackUri.path ||
          redirectUri.userInfo.isNotEmpty ||
          redirectUri.hasFragment ||
          _single(values: query["state"]) != authorization.state ||
          code == null ||
          code.isEmpty ||
          RegExp(r"\s").hasMatch(code) ||
          query.containsKey("error") ||
          (issuers != null && _single(values: issuers) != "https://accounts.google.com")) {
        throw const AntigravityAuthenticationException(message: "Invalid sign-in callback", cause: null);
      }
    } on AntigravityAuthenticationException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AntigravityAuthenticationException(message: "Invalid sign-in callback", cause: error),
        stackTrace,
      );
    }
    final result = await _repository.forward(callbackUri: redirectUri, budget: budget);
    budget.remaining;
    if (result case AntigravityCallbackRejected(:final statusCode)) {
      throw AntigravityAuthenticationException(message: "Callback rejected (HTTP $statusCode)", cause: null);
    }
  }

  Future<void> dispose() => _repository.dispose();

  static String? _single({required List<String>? values}) => switch (values) {
    [final value] => value,
    _ => null,
  };
}
