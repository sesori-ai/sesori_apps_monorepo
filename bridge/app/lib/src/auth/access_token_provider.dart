/// Provides read access to the current OAuth access token.
abstract class AccessTokenProvider {
  String get accessToken;
}

/// Provides write access to update the OAuth access token.
abstract class AccessTokenUpdater {
  String get accessToken;

  set accessToken(String token);
}
