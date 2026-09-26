/// The auth server reported that the user declined the pending browser sign-in.
final class const OAuthFlowDenied() implements Exception {
  @override
  String toString() => "OAuth authorization was denied";
}

/// The auth server reported that the pending browser sign-in expired.
final class const OAuthFlowExpired() implements Exception {
  @override
  String toString() => "OAuth authorization expired";
}
