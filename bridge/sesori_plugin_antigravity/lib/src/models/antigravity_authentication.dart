/// Transient OAuth material. Default presentation intentionally includes no fields.
final class const AntigravityAuthorization({
  required final Uri authorizationUri,
  required final Uri callbackUri,
  required final String state,
});

sealed class const AntigravityCallbackResult();

final class const AntigravityCallbackAccepted() extends AntigravityCallbackResult;

final class const AntigravityCallbackRejected({required final int statusCode}) extends AntigravityCallbackResult;

class const AntigravityAuthenticationException({
  required final String message,
  // ignore: no_slop_linter/prefer_specific_type, retain boundary failures without exposing their OAuth payloads
  required final Object? cause,
}) implements Exception {
  @override
  String toString() => "Antigravity authentication: $message";
}
