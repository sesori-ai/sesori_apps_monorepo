abstract interface class TokenRefresher() {
  Future<String> getAccessToken({bool forceRefresh = false});
}

/// The typed failure a [TokenRefresher] throws when it cannot supply any usable
/// access token and a relay reconnect must therefore be deferred. A null GUI
/// response invalidates the cached token. The retryable subtype covers temporary
/// control-channel or token-refresh failures without treating them as sign-out.
class const ControlTokenUnavailableException(final String reason) implements Exception {
  @override
  String toString() => "ControlTokenUnavailableException: $reason";
}

/// The GUI retains its auth session but cannot currently refresh its token.
class const ControlTokenRetryLaterException({required final Object? innerError})
    extends ControlTokenUnavailableException {
  this : super("The desktop app cannot currently supply an access token; retry later.");
}
